# Doorlock Sniper Windows 编码模拟器
# 复刻原 ROS2/GStreamer 编码端核心逻辑，用于本地测试 Flutter 自定义图传线。
#
# 输入：本地视频文件 / DirectShow 摄像头
# 输出：MQTT CustomByteBlock（300B H.264 Annex-B 包，50Hz）
#
# 依赖：Python 3.10+, opencv-python, av, paho-mqtt, protobuf

from __future__ import annotations

import argparse
import math
import queue
import sys
import threading
import time
from collections import deque
from dataclasses import dataclass
from pathlib import Path
from typing import Final, List, Optional

import cv2
import numpy as np

# Protobuf 生成文件在首次运行时由 protoc 生成（见 README）。
try:
    import robomaster_custom_client_pb2 as rm_pb
except ImportError as e:  # pragma: no cover
    print(
        "ERROR: robomaster_custom_client_pb2.py not found.\n"
        "Run: python -m grpc_tools.protoc "
        "--python_out=. --proto_dir=../../protos "
        "../../protos/robomaster_custom_client.proto",
        file=sys.stderr,
    )
    raise e

try:
    import paho.mqtt.client as mqtt
except ImportError as e:  # pragma: no cover
    print("ERROR: paho-mqtt not installed. Run: pip install paho-mqtt", file=sys.stderr)
    raise e


@dataclass
class EncoderConfig:
    """与 sniper.launch.py 一一对应的配置项。"""

    # 输入
    input_path: str = "0"  # "0" 表示默认摄像头，否则为文件路径
    input_fps: float = 60.0

    # 预处理
    crop_size: int = 800
    output_size: int = 400
    static_simplify: bool = True
    motion_threshold: int = 14
    motion_erode_px: int = 2
    motion_dilate_px: int = 6
    motion_trail_frames: int = 90
    trail_disable_motion_ratio: float = 0.30
    bg_update_alpha: float = 0.01
    bg_blur_sigma: float = 1.8
    center_clear_size: int = 150
    force_monochrome: bool = False

    # 编码
    target_bitrate_kbytes: float = 10.0
    target_bitrate_kbps: int = 80  # 10 kB/s * 8
    x264_preset: str = "veryslow"
    output_fps: int = 60
    key_int_frames: int = 480  # 默认低码率模式：8 秒 GOP
    low_bitrate_mode: bool = True
    bframes: int = 4

    # 发送
    packet_size: int = 300
    bandwidth_limit_kbytes: float = 14.0
    bandwidth_window_s: float = 2.0
    max_tx_delay_s: float = 1.0

    # MQTT
    mqtt_broker: str = "127.0.0.1"
    mqtt_port: int = 1883
    mqtt_topic: str = "CustomByteBlock"
    client_id: str = "doorlock_simulator"

    # 调试
    enable_display: bool = True
    debug_dump_enable: bool = False
    debug_dump_every_n_frames: int = 1
    debug_dump_dir: Path = Path("sniper_debug_imgs") / "encoder"
    debug_dump_save_raw: bool = False
    debug_dump_save_roi: bool = True
    debug_dump_save_static: bool = False
    debug_dump_save_final: bool = True


def _resolve_x264_preset(preset: str) -> str:
    """只接受 x264 标准 preset；非法值回退到 veryslow。"""
    valid = {
        "ultrafast",
        "superfast",
        "veryfast",
        "faster",
        "fast",
        "medium",
        "slow",
        "slower",
        "veryslow",
        "placebo",
    }
    if preset.lower() in valid:
        return preset.lower()
    print(f"WARNING: unknown x264_preset '{preset}', fallback to veryslow", file=sys.stderr)
    return "veryslow"


class VideoReader:
    """统一封装文件与摄像头输入，按固定帧率抽帧。"""

    def __init__(self, path: str, target_fps: float, *, loop: bool = False) -> None:
        self._cap = cv2.VideoCapture(int(path) if path.isdigit() else path)
        if not self._cap.isOpened():
            raise RuntimeError(f"Cannot open video input: {path}")
        self._target_fps = target_fps
        self._target_interval = 1.0 / target_fps
        self._last_time: Optional[float] = None
        self._loop = loop

    @property
    def width(self) -> int:
        return int(self._cap.get(cv2.CAP_PROP_FRAME_WIDTH))

    @property
    def height(self) -> int:
        return int(self._cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

    def read(self) -> Optional[np.ndarray]:
        now = time.monotonic()
        if self._last_time is not None and (now - self._last_time) < self._target_interval:
            return None
        ok, frame = self._cap.read()
        if not ok:
            # 文件循环：回到首帧重读（摄像头不会走到这里）。
            if self._loop:
                self._cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                ok, frame = self._cap.read()
            if not ok:
                return None
        self._last_time = now
        return frame

    def release(self) -> None:
        self._cap.release()


class ImagePreprocessor:
    """复刻原 video_encoder_node.cpp 的 preprocess_image。"""

    def __init__(self, cfg: EncoderConfig) -> None:
        self._cfg = cfg
        self._bg: Optional[np.ndarray] = None
        self._motion_erode_kernel: Optional[np.ndarray] = None
        self._motion_dilate_kernel: Optional[np.ndarray] = None
        self._motion_mask_history: deque[np.ndarray] = deque()
        self._trail_frame_history: deque[np.ndarray] = deque()

    def process(self, input_frame: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
        h, w = input_frame.shape[:2]
        crop = self._cfg.crop_size
        x = max(0, (w - crop) // 2)
        y = max(0, (h - crop) // 2)
        cw = min(crop, w - x)
        ch = min(crop, h - y)
        cropped = input_frame[y : y + ch, x : x + cw]
        roi = cv2.resize(cropped, (self._cfg.output_size, self._cfg.output_size), interpolation=cv2.INTER_LINEAR)

        working = roi.copy()
        if self._cfg.force_monochrome:
            working = self._to_gray_bgr(working)

        if not self._cfg.static_simplify:
            return roi, roi, working

        static_removed = self._static_simplify(working)
        return roi, static_removed, static_removed

    def _to_gray_bgr(self, img: np.ndarray) -> np.ndarray:
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        return cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)

    def _static_simplify(self, working: np.ndarray) -> np.ndarray:
        gray = cv2.cvtColor(working, cv2.COLOR_BGR2GRAY)
        if self._bg is None:
            self._bg = gray.astype(np.float32)
            return working

        bg_u8 = cv2.convertScaleAbs(self._bg)
        diff = cv2.absdiff(gray, bg_u8)
        _, motion_mask = cv2.threshold(diff, self._cfg.motion_threshold, 255, cv2.THRESH_BINARY)

        if self._cfg.motion_erode_px > 0:
            motion_mask = cv2.erode(motion_mask, self._erode_kernel(), iterations=1)
        if self._cfg.motion_dilate_px > 0:
            motion_mask = cv2.dilate(motion_mask, self._dilate_kernel(), iterations=1)

        motion_ratio = cv2.countNonZero(motion_mask) / motion_mask.size
        suppress_trail = motion_ratio >= self._cfg.trail_disable_motion_ratio

        self._apply_center_clear(motion_mask)

        static_base = working.copy()
        if not self._cfg.force_monochrome and self._cfg.target_bitrate_kbytes <= 10.0:
            static_base = self._to_gray_bgr(static_base)
        blurred = cv2.GaussianBlur(static_base, (0, 0), self._cfg.bg_blur_sigma)

        # cv2 (Python) 没有 Mat.copyTo(dst, mask)：用布尔掩码做就地拷贝。
        focused = blurred.copy()
        mask_bool = motion_mask > 0
        focused[mask_bool] = working[mask_bool]

        if self._cfg.motion_trail_frames > 0:
            focused = self._apply_trail(
                working, motion_mask, focused, suppress_trail
            )

        cv2.accumulateWeighted(gray, self._bg, self._cfg.bg_update_alpha)
        return focused

    def _erode_kernel(self) -> np.ndarray:
        if self._motion_erode_kernel is None:
            k = 2 * self._cfg.motion_erode_px + 1
            self._motion_erode_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k))
        return self._motion_erode_kernel

    def _dilate_kernel(self) -> np.ndarray:
        if self._motion_dilate_kernel is None:
            k = 2 * self._cfg.motion_dilate_px + 1
            self._motion_dilate_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k))
        return self._motion_dilate_kernel

    def _apply_center_clear(self, mask: np.ndarray) -> None:
        if self._cfg.center_clear_size <= 0:
            return
        h, w = mask.shape
        clear_size = min(self._cfg.center_clear_size, w, h)
        x0 = max(0, w // 2 - clear_size // 2)
        y0 = max(0, h // 2 - clear_size // 2)
        cw = min(clear_size, w - x0)
        ch = min(clear_size, h - y0)
        cv2.rectangle(mask, (x0, y0), (x0 + cw, y0 + ch), 255, cv2.FILLED)

    def _apply_trail(
        self,
        working: np.ndarray,
        motion_mask: np.ndarray,
        focused: np.ndarray,
        suppress_trail: bool,
    ) -> np.ndarray:
        self._motion_mask_history.append(motion_mask.copy())
        self._trail_frame_history.append(working.copy())
        max_history = self._cfg.motion_trail_frames + 1
        while len(self._motion_mask_history) > max_history:
            self._motion_mask_history.popleft()
        while len(self._trail_frame_history) > max_history:
            self._trail_frame_history.popleft()

        history_size = len(self._motion_mask_history)
        if suppress_trail or history_size <= 1:
            return focused

        trail_mask = motion_mask.copy()
        trail_img = working.copy()
        for i in range(history_size - 1):
            trail_mask = cv2.bitwise_or(trail_mask, self._motion_mask_history[i])
            trail_img = cv2.max(trail_img, self._trail_frame_history[i])
        trail_bool = trail_mask > 0
        focused[trail_bool] = trail_img[trail_bool]
        return focused


class H264Encoder:
    """PyAV H.264 Annex-B 编码器。"""

    def __init__(self, cfg: EncoderConfig) -> None:
        self._cfg = cfg
        self._codec: Optional[object] = None
        self._stream: Optional[object] = None
        self._frame_count = 0
        self._setup()

    def _setup(self) -> None:
        import av
        from fractions import Fraction

        self._codec = av.CodecContext.create("h264", "w")
        self._codec.width = self._cfg.output_size
        self._codec.height = self._cfg.output_size
        self._codec.pix_fmt = "yuv420p"
        self._codec.time_base = Fraction(1, self._cfg.output_fps)
        self._codec.framerate = Fraction(self._cfg.output_fps, 1)
        self._codec.bit_rate = self._cfg.target_bitrate_kbps * 1000
        self._codec.gop_size = self._cfg.key_int_frames
        self._codec.max_b_frames = self._cfg.bframes

        preset = _resolve_x264_preset(self._cfg.x264_preset)
        options: dict[str, str] = {
            "preset": preset,
            "x264opts": "repeat-headers=1:scenecut=0:force-cfr=1:annexb=1",
        }
        if not self._cfg.low_bitrate_mode:
            options["tune"] = "zerolatency"
        if self._cfg.low_bitrate_mode:
            options["profile"] = "baseline"
        self._codec.options = options

    def encode(self, bgr_frame: np.ndarray) -> list[bytes]:
        import av

        if self._codec is None:
            return []
        rgb = cv2.cvtColor(bgr_frame, cv2.COLOR_BGR2RGB)
        frame = av.VideoFrame.from_ndarray(rgb, format="rgb24")
        frame.pts = self._frame_count
        self._frame_count += 1

        packets = self._codec.encode(frame)
        return [bytes(p) for p in packets]

    def flush(self) -> list[bytes]:
        if self._codec is None:
            return []
        import av

        packets = self._codec.encode()
        return [bytes(p) for p in packets]


class MqttPacketizer:
    """H.264 字节流 → 300B 包 → MQTT CustomByteBlock，带带宽限速。"""

    def __init__(self, cfg: EncoderConfig) -> None:
        self._cfg = cfg
        self._stream_buffer = bytearray()
        self._sent_window: deque[tuple[float, int]] = deque()
        self._sent_window_bytes = 0
        self._dropped_bytes = 0
        self._dropped_events = 0
        self._last_telemetry = 0.0
        self._seq = 0

        self._mqtt = mqtt.Client(
            callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
            client_id=cfg.client_id,
        )
        self._mqtt.connect(cfg.mqtt_broker, cfg.mqtt_port, keepalive=60)
        self._mqtt.loop_start()

    def feed_packets(self, packets: list[bytes]) -> None:
        for p in packets:
            self._stream_buffer.extend(p)
        self._packetize()

    def _packetize(self) -> None:
        packet_size = self._cfg.packet_size
        window_ns = self._cfg.bandwidth_window_s
        window_limit = int(self._cfg.bandwidth_limit_kbytes * 1000 * self._cfg.bandwidth_window_s)
        max_backlog = int(self._cfg.bandwidth_limit_kbytes * 1000 * self._cfg.max_tx_delay_s)

        while len(self._stream_buffer) >= packet_size:
            now = time.monotonic()
            while self._sent_window and (now - self._sent_window[0][0]) > window_ns:
                self._sent_window_bytes -= self._sent_window.popleft()[1]

            if self._sent_window_bytes + packet_size > window_limit:
                break

            chunk = bytes(self._stream_buffer[:packet_size])
            self._publish(chunk)
            self._stream_buffer[:packet_size] = b""
            self._sent_window.append((now, packet_size))
            self._sent_window_bytes += packet_size

        if len(self._stream_buffer) > max_backlog:
            self._clip_backlog(max_backlog)

        self._maybe_telemetry()

    def _publish(self, chunk: bytes) -> None:
        block = rm_pb.CustomByteBlock()
        block.data = chunk
        self._mqtt.publish(self._cfg.mqtt_topic, block.SerializeToString())
        self._seq += 1

    def _clip_backlog(self, max_backlog: int) -> None:
        target_drop = len(self._stream_buffer) - max_backlog
        drop_bytes = target_drop
        for i in range(target_drop, len(self._stream_buffer) - 4):
            if (
                self._stream_buffer[i] == 0
                and self._stream_buffer[i + 1] == 0
                and self._stream_buffer[i + 2] == 1
            ) or (
                self._stream_buffer[i] == 0
                and self._stream_buffer[i + 1] == 0
                and self._stream_buffer[i + 2] == 0
                and self._stream_buffer[i + 3] == 1
            ):
                drop_bytes = i
                break

        self._stream_buffer[:drop_bytes] = b""
        self._dropped_bytes += drop_bytes
        self._dropped_events += 1
        if self._dropped_events % 20 == 1:
            print(
                f"TX backlog clipped: dropped={drop_bytes}B "
                f"backlog={len(self._stream_buffer)}B total_dropped={self._dropped_bytes}B "
                f"events={self._dropped_events}"
            )

    def _maybe_telemetry(self) -> None:
        now = time.monotonic()
        if now - self._last_telemetry < 1.0:
            return
        self._last_telemetry = now
        avg = self._sent_window_bytes / max(self._cfg.bandwidth_window_s, 0.001)
        print(
            f"TX stats: window={self._sent_window_bytes / 1000:.2f}/"
            f"{self._cfg.bandwidth_limit_kbytes * self._cfg.bandwidth_window_s:.2f}kB "
            f"avg={avg / 1000:.2f}kB/s backlog={len(self._stream_buffer)}B "
            f"dropped={self._dropped_bytes}B"
        )

    def close(self) -> None:
        self._mqtt.loop_stop()
        self._mqtt.disconnect()


class DisplayLoop:
    """编码端 OpenCV 调试显示与 PNG dump。"""

    def __init__(self, cfg: EncoderConfig) -> None:
        self._cfg = cfg
        self._queue: queue.Queue[tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]] = queue.Queue(maxsize=2)
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._running = False
        self._frame_counter = 0
        if cfg.enable_display or cfg.debug_dump_enable:
            self._running = True
            self._thread.start()

    def push(
        self,
        raw: np.ndarray,
        roi: np.ndarray,
        static_removed: np.ndarray,
        final: np.ndarray,
    ) -> None:
        if not self._running:
            return
        try:
            self._queue.put_nowait((raw, roi, static_removed, final))
        except queue.Full:
            pass

    def _run(self) -> None:
        windows = ["Raw", "ROI", "Static", "Final"]
        for w in windows:
            cv2.namedWindow(f"Doorlock Sniper {w}", cv2.WINDOW_NORMAL)

        while self._running:
            try:
                raw, roi, static_removed, final = self._queue.get(timeout=0.05)
            except queue.Empty:
                if cv2.waitKey(1) & 0xFF == ord("q"):
                    break
                continue

            self._frame_counter += 1
            self._maybe_show("Doorlock Sniper Raw", raw)
            self._maybe_show("Doorlock Sniper ROI", roi)
            self._maybe_show("Doorlock Sniper Static", static_removed)
            self._maybe_show("Doorlock Sniper Final", final)
            self._maybe_dump(raw, roi, static_removed, final)

            if cv2.waitKey(1) & 0xFF == ord("q"):
                break

        cv2.destroyAllWindows()

    def _maybe_show(self, name: str, img: np.ndarray) -> None:
        if self._cfg.enable_display and img.size > 0:
            cv2.imshow(name, img)

    def _maybe_dump(
        self,
        raw: np.ndarray,
        roi: np.ndarray,
        static_removed: np.ndarray,
        final: np.ndarray,
    ) -> None:
        if not self._cfg.debug_dump_enable:
            return
        if self._frame_counter % self._cfg.debug_dump_every_n_frames != 0:
            return
        self._cfg.debug_dump_dir.mkdir(parents=True, exist_ok=True)
        fid = f"{self._frame_counter:08d}"
        pairs = [
            (self._cfg.debug_dump_save_raw, "raw", raw),
            (self._cfg.debug_dump_save_roi, "roi", roi),
            (self._cfg.debug_dump_save_static, "static", static_removed),
            (self._cfg.debug_dump_save_final, "final", final),
        ]
        for enabled, prefix, img in pairs:
            if enabled and img.size > 0:
                cv2.imwrite(str(self._cfg.debug_dump_dir / f"{prefix}_{fid}.png"), img)

    def close(self) -> None:
        self._running = False
        if self._thread.is_alive():
            self._thread.join(timeout=1.0)


def _build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Doorlock Sniper Windows encoder simulator")
    p.add_argument("--input", default="0", help='Video file path or "0" for default camera')
    p.add_argument("--crop-size", type=int, default=800)
    p.add_argument("--output-size", type=int, default=400)
    p.add_argument("--output-fps", type=int, default=60)
    p.add_argument("--target-bitrate-kbytes", type=float, default=10.0)
    p.add_argument("--x264-preset", default="veryslow")
    p.add_argument("--packet-size", type=int, default=300)
    p.add_argument("--broker", default="127.0.0.1", help="MQTT broker IP")
    p.add_argument("--port", type=int, default=1883, help="MQTT broker port")
    p.add_argument("--topic", default="CustomByteBlock", help="MQTT topic")
    p.add_argument("--client-id", default="doorlock_simulator")
    p.add_argument("--no-display", action="store_true", help="Disable OpenCV windows")
    p.add_argument("--debug-dump", action="store_true", help="Save debug PNGs")
    p.add_argument("--debug-dump-dir", default="sniper_debug_imgs/encoder")
    return p


def _config_from_args(args: argparse.Namespace) -> EncoderConfig:
    return EncoderConfig(
        input_path=args.input,
        crop_size=args.crop_size,
        output_size=args.output_size,
        output_fps=args.output_fps,
        target_bitrate_kbytes=args.target_bitrate_kbytes,
        target_bitrate_kbps=int(args.target_bitrate_kbytes * 8),
        x264_preset=args.x264_preset,
        packet_size=args.packet_size,
        mqtt_broker=args.broker,
        mqtt_port=args.port,
        mqtt_topic=args.topic,
        client_id=args.client_id,
        enable_display=not args.no_display,
        debug_dump_enable=args.debug_dump,
        debug_dump_dir=Path(args.debug_dump_dir),
    )


def _run_loop(
    cfg: EncoderConfig,
    reader: VideoReader,
    preprocessor: ImagePreprocessor,
    encoder: H264Encoder,
    packetizer: MqttPacketizer,
    display: DisplayLoop,
) -> None:
    while True:
        raw = reader.read()
        if raw is None:
            print("Input ended")
            break

        roi, static_removed, final = preprocessor.process(raw)
        raw_preview = cv2.resize(
            raw,
            (raw.shape[1] // 2, raw.shape[0] // 2),
            interpolation=cv2.INTER_AREA,
        )
        display.push(raw_preview, roi, static_removed, final)

        packetizer.feed_packets(encoder.encode(final))

        # 按 50Hz 节流（20ms 间隔），与原 0x0310 频率一致
        time.sleep(1.0 / 50.0)


def main() -> int:
    cfg = _config_from_args(_build_arg_parser().parse_args())

    reader = VideoReader(cfg.input_path, cfg.output_fps)
    preprocessor = ImagePreprocessor(cfg)
    encoder = H264Encoder(cfg)
    packetizer = MqttPacketizer(cfg)
    display = DisplayLoop(cfg)

    print(
        f"Encoder simulator started: {reader.width}x{reader.height} input -> "
        f"{cfg.output_size}x{cfg.output_size} @ {cfg.output_fps}fps"
    )
    print(
        f"MQTT: {cfg.mqtt_broker}:{cfg.mqtt_port} "
        f"topic={cfg.mqtt_topic} packet_size={cfg.packet_size}"
    )

    try:
        _run_loop(cfg, reader, preprocessor, encoder, packetizer, display)
    except KeyboardInterrupt:
        print("Interrupted by user")
    finally:
        packetizer.close()
        display.close()
        reader.release()

    return 0


if __name__ == "__main__":
    sys.exit(main())

"""极简 MQTT 3.1.1 broker，零外部依赖（仅标准库）。

用途：本地联调自定义图传线，监听一个端口（默认 3333），转发 PUBLISH。
支持：CONNECT/CONNACK、PUBLISH(QoS0/1) + PUBACK、SUBSCRIBE/SUBACK、
      UNSUBSCRIBE/UNSUBACK、PINGREQ/PINGRESP、DISCONNECT。
不支持：TLS、QoS2、retain 持久化、会话恢复（够本地测试即可）。

用法：
    python mini_mqtt_broker.py --port 3333
"""

from __future__ import annotations

import argparse
import socket
import struct
import threading
from typing import List, Optional, Set, Tuple

# MQTT 控制报文类型（高 4 位）。
_CONNECT = 1
_CONNACK = 2
_PUBLISH = 3
_PUBACK = 4
_SUBSCRIBE = 8
_SUBACK = 9
_UNSUBSCRIBE = 10
_UNSUBACK = 11
_PINGREQ = 12
_PINGRESP = 13
_DISCONNECT = 14


def _encode_remaining_length(length: int) -> bytes:
    """MQTT 可变长度编码。"""
    out = bytearray()
    while True:
        byte = length % 128
        length //= 128
        if length > 0:
            byte |= 0x80
        out.append(byte)
        if length == 0:
            break
    return bytes(out)


class _Client:
    """一个已连接客户端的状态。"""

    def __init__(self, sock: socket.socket, addr: Tuple[str, int]) -> None:
        self.sock = sock
        self.addr = addr
        self.subscriptions: Set[str] = set()
        self.lock = threading.Lock()

    def send(self, data: bytes) -> None:
        with self.lock:
            try:
                self.sock.sendall(data)
            except OSError:
                pass


class MiniMqttBroker:
    """单进程多线程极简 broker。"""

    def __init__(self, host: str, port: int) -> None:
        self._host = host
        self._port = port
        self._clients: List[_Client] = []
        self._clients_lock = threading.Lock()
        self._server: Optional[socket.socket] = None

    def serve_forever(self) -> None:
        self._server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self._server.bind((self._host, self._port))
        self._server.listen(16)
        print(f"Mini MQTT broker listening on {self._host}:{self._port}")
        try:
            while True:
                sock, addr = self._server.accept()
                threading.Thread(
                    target=self._handle_client, args=(sock, addr), daemon=True
                ).start()
        except KeyboardInterrupt:
            print("\nBroker shutting down")
        finally:
            self._server.close()

    def _handle_client(self, sock: socket.socket, addr: Tuple[str, int]) -> None:
        client = _Client(sock, addr)
        with self._clients_lock:
            self._clients.append(client)
        try:
            self._client_loop(client)
        finally:
            with self._clients_lock:
                if client in self._clients:
                    self._clients.remove(client)
            sock.close()

    def _client_loop(self, client: _Client) -> None:
        while True:
            header = self._recv_exact(client.sock, 1)
            if not header:
                return
            packet_type = (header[0] >> 4) & 0x0F
            remaining = self._read_remaining_length(client.sock)
            if remaining is None:
                return
            payload = self._recv_exact(client.sock, remaining) if remaining else b""
            if payload is None:
                return
            if not self._dispatch(client, packet_type, header[0], payload):
                return

    def _dispatch(
        self, client: _Client, packet_type: int, first_byte: int, payload: bytes
    ) -> bool:
        if packet_type == _CONNECT:
            client.send(bytes([_CONNACK << 4, 0x02, 0x00, 0x00]))
        elif packet_type == _PUBLISH:
            self._handle_publish(client, first_byte, payload)
        elif packet_type == _SUBSCRIBE:
            self._handle_subscribe(client, payload)
        elif packet_type == _UNSUBSCRIBE:
            self._handle_unsubscribe(client, payload)
        elif packet_type == _PINGREQ:
            client.send(bytes([_PINGRESP << 4, 0x00]))
        elif packet_type == _DISCONNECT:
            return False
        return True

    def _handle_publish(
        self, client: _Client, first_byte: int, payload: bytes
    ) -> None:
        qos = (first_byte >> 1) & 0x03
        topic_len = struct.unpack("!H", payload[0:2])[0]
        topic = payload[2 : 2 + topic_len].decode("utf-8", "replace")
        offset = 2 + topic_len
        packet_id: Optional[int] = None
        if qos > 0:
            packet_id = struct.unpack("!H", payload[offset : offset + 2])[0]
            offset += 2
        message = payload[offset:]

        if qos == 1 and packet_id is not None:
            client.send(bytes([_PUBACK << 4, 0x02]) + struct.pack("!H", packet_id))

        self._forward(topic, message)

    def _forward(self, topic: str, message: bytes) -> None:
        # QoS0 转发给所有订阅了该主题的客户端。
        topic_bytes = topic.encode("utf-8")
        var_header = struct.pack("!H", len(topic_bytes)) + topic_bytes
        body = var_header + message
        packet = bytes([_PUBLISH << 4]) + _encode_remaining_length(len(body)) + body

        with self._clients_lock:
            targets = [c for c in self._clients if self._matches(c, topic)]
        for c in targets:
            c.send(packet)

    @staticmethod
    def _matches(client: _Client, topic: str) -> bool:
        for sub in client.subscriptions:
            if sub == topic or sub == "#":
                return True
            if sub.endswith("/#") and topic.startswith(sub[:-2]):
                return True
        return False

    def _handle_subscribe(self, client: _Client, payload: bytes) -> None:
        packet_id = struct.unpack("!H", payload[0:2])[0]
        offset = 2
        return_codes = bytearray()
        while offset < len(payload):
            topic_len = struct.unpack("!H", payload[offset : offset + 2])[0]
            offset += 2
            topic = payload[offset : offset + topic_len].decode("utf-8", "replace")
            offset += topic_len
            offset += 1  # 跳过请求的 QoS 字节
            client.subscriptions.add(topic)
            return_codes.append(0x00)  # 授予 QoS0
            print(f"SUBSCRIBE {client.addr} -> {topic}")

        body = struct.pack("!H", packet_id) + bytes(return_codes)
        client.send(
            bytes([_SUBACK << 4]) + _encode_remaining_length(len(body)) + body
        )

    def _handle_unsubscribe(self, client: _Client, payload: bytes) -> None:
        packet_id = struct.unpack("!H", payload[0:2])[0]
        offset = 2
        while offset < len(payload):
            topic_len = struct.unpack("!H", payload[offset : offset + 2])[0]
            offset += 2
            offset += topic_len
        client.send(bytes([_UNSUBACK << 4, 0x02]) + struct.pack("!H", packet_id))

    def _read_remaining_length(self, sock: socket.socket) -> Optional[int]:
        multiplier = 1
        value = 0
        while True:
            byte = self._recv_exact(sock, 1)
            if not byte:
                return None
            value += (byte[0] & 0x7F) * multiplier
            if (byte[0] & 0x80) == 0:
                break
            multiplier *= 128
            if multiplier > 128 * 128 * 128:
                return None
        return value

    @staticmethod
    def _recv_exact(sock: socket.socket, n: int) -> Optional[bytes]:
        buf = bytearray()
        while len(buf) < n:
            try:
                chunk = sock.recv(n - len(buf))
            except OSError:
                return None
            if not chunk:
                return None
            buf.extend(chunk)
        return bytes(buf)


def main() -> int:
    parser = argparse.ArgumentParser(description="Minimal MQTT 3.1.1 broker")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=3333)
    args = parser.parse_args()

    MiniMqttBroker(args.host, args.port).serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

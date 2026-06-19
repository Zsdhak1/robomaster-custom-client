# Windows 自定义图传编码模拟器

完整复刻原 `doorlock_sniper` 编码端逻辑，用于在 Windows 开发机上本地测试 Flutter 自定义图传线（0x0310 / `CustomByteBlock`）。

## 环境要求

- Windows 10/11
- Python 3.10+
- 已安装并启动 MQTT Broker（推荐 [Eclipse Mosquitto](https://mosquitto.org/download/)）

## 安装依赖

```powershell
cd tool/custom_byte_block_simulator
pip install -r requirements.txt
```

## 生成 Protobuf Python 文件

模拟器需要把 `CustomByteBlock` 序列化为 Protobuf 后通过 MQTT 发送。项目里已有 `.proto` 定义，首次运行前需生成 Python 绑定：

```powershell
# 从本目录执行
python -m grpc_tools.protoc `
  --python_out=. `
  --proto_path=..\..\protos `
  ..\..\protos\robomaster_custom_client.proto
```

或直接用系统已安装的 `protoc`：

```powershell
protoc --python_out=. --proto_path=..\..\protos ..\..\protos\robomaster_custom_client.proto
```

执行后会在当前目录生成 `robomaster_custom_client_pb2.py`。

> 如果提示缺少 `grpc_tools`，安装：`pip install grpcio-tools`

## 启动 Mosquitto（本地测试）

```powershell
# 如果 mosquitto 已加入 PATH
mosquitto -p 1883
```

或在另一个 PowerShell 窗口用 Docker：

```powershell
docker run -it -p 1883:1883 eclipse-mosquitto
```

### 没有 Mosquitto / Docker？用内置极简 broker

仓库自带一个零依赖（仅 Python 标准库）的极简 MQTT broker，适合本地联调，
尤其当目标端口是裁判系统的 `3333` 时：

```powershell
python mini_mqtt_broker.py --port 3333
```

它支持 CONNECT / PUBLISH(QoS0,1) / SUBSCRIBE / PINGREQ / DISCONNECT，
足够「模拟器发布 → Flutter 订阅」的转发。不支持 TLS / QoS2 / 持久化，
仅用于测试，**不要用于生产**。

## 运行模拟器

### 用默认摄像头

```powershell
python encoder_simulator.py
```

### 用本地视频文件

```powershell
python encoder_simulator.py --input path\to\video.mp4
```

### 发送到另一台机器的 Broker

```powershell
python encoder_simulator.py --broker 192.168.12.1 --port 3333
```

> 注意：正式比赛环境的 MQTT Broker 运行在 `192.168.12.1:3333`（裁判系统）。本地测试建议先用 `127.0.0.1:1883`，或用内置极简 broker 监听 `3333`。

### 发送到本地 3333（内置 broker，已验证）

```powershell
# 终端 1：启动极简 broker
python mini_mqtt_broker.py --port 3333

# 终端 2：发送（用本地视频文件或摄像头）
python encoder_simulator.py --input path\to\video.mp4 --broker 127.0.0.1 --port 3333
```

> 已端到端验证：模拟器发出的 300B `CustomByteBlock` 经 broker 正确转发给订阅者，
> 首包即含 H.264 SPS（`00 00 00 01 67 42 ...`），字节流格式正确。

## 常用参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--input` | `0` | 输入：文件路径或 `0`（默认摄像头） |
| `--crop-size` | `800` | 中心裁剪 ROI 大小 |
| `--output-size` | `400` | 输出分辨率 |
| `--output-fps` | `60` | 输出帧率 |
| `--target-bitrate-kbytes` | `10.0` | 目标码率（kB/s），对应 80 kbps |
| `--x264-preset` | `veryslow` | x264 preset |
| `--packet-size` | `300` | 每包字节数，匹配 0x0310 上限 |
| `--broker` | `127.0.0.1` | MQTT broker IP |
| `--port` | `1883` | MQTT broker 端口 |
| `--topic` | `CustomByteBlock` | MQTT topic |
| `--no-display` | — | 关闭 OpenCV 调试窗口 |
| `--debug-dump` | — | 保存调试 PNG |
| `--debug-dump-dir` | `sniper_debug_imgs/encoder` | 调试 PNG 保存目录 |

## 复刻的原编码端特性

- ✅ 中心裁剪 + resize 到 400×400
- ✅ 静态区域简化（背景模型 + 运动检测 + 高斯模糊）
- ✅ 运动拖影（时域 max，历史 N 帧）
- ✅ 中心保护区
- ✅ 强制灰度模式
- ✅ PyAV x264 H.264 Annex-B 编码
- ✅ 300B 固定分包
- ✅ 2 秒滑动窗口带宽限速
- ✅ backlog 裁剪到下一个 Annex-B start code
- ✅ 50Hz 发送频率
- ✅ OpenCV 调试显示：Raw / ROI / Static / Final
- ✅ 调试 PNG dump

## 与原仓库的差异

- 输入：Windows 摄像头 / 本地文件，替代海康相机 + ROS2
- 输出：MQTT `CustomByteBlock`，替代 ROS2 `/video_stream`
- 包内无 `sequence_id`（真实 0x0310 也没有）
- 使用 PyAV 替代 GStreamer，但编码参数尽量对齐

## 端到端验证流程

1. 启动 Mosquitto：`mosquitto -p 1883`
2. 启动模拟器：`python encoder_simulator.py --input your_video.mp4`
3. 启动 Flutter 客户端
4. 在客户端连接 MQTT（默认 `127.0.0.1:1883`）
5. 打开「自定义图传」页面，点击「开始接收」
6. 等待关键帧（最长 8 秒，取决于 GOP），应出图并显示准星

## 常见问题

**Q: 提示找不到 `robomaster_custom_client_pb2.py`**
A: 按上文运行 `protoc` 生成。

**Q: OpenCV 找不到摄像头**
A: Windows 摄像头索引可能不是 0，用 `--input 1` 尝试，或用本地视频文件。

**Q: 模拟器发送了但 Flutter 不出图**
A: 检查：
- Flutter 客户端 MQTT 是否连上同一 broker
- `CustomByteBlock` topic 是否一致
- 是否点击了「开始接收」按钮
- 是否等待了足够的关键帧时间（低码率 GOP 8 秒）

**Q: 画面有延迟**
A: media_kit/fvp 播放器本身有缓冲。Flutter 端可尝试调小 `cache-secs`/`demuxer-readahead-secs`。

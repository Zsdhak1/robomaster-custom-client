/// RoboMaster 自定义客户端 MQTT 3333 服务封装。
///
/// 处理连接、订阅和 Protobuf 消息发布，
/// 支持指数退避自动重连和心跳。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:protobuf/protobuf.dart';
import 'package:typed_data/typed_data.dart' as typed;

import '../core/constants/protocol_constants.dart';

/// MQTT 服务连接状态。
enum MqttConnectionState {
  /// 未连接。
  disconnected,

  /// 正在连接。
  connecting,

  /// 已连接且可用。
  connected,

  /// 连接失败。
  error,
}

/// MQTT 接收边界产生的消息，保留原始接收时刻和所属连接代次。
typedef MqttInboundMessage = ({
  String topic,
  Uint8List payload,
  DateTime receivedAt,
  int connectionGeneration,
});

/// 连接状态变化回调。
typedef ConnectionStateCallback = void Function(MqttConnectionState state);

/// 封装 MQTT 客户端操作的服务。
class MqttService {
  /// 创建 [MqttService]。
  ///
  /// [brokerIp] 默认为 [defaultMqttBrokerIp]。
  /// [port] 默认为 [defaultMqttPort]。
  /// [clientId] 用于向代理服务器标识当前客户端。
  MqttService({required this.clientId, String? brokerIp, int? port})
    : _brokerIp = brokerIp ?? defaultMqttBrokerIp,
      _port = port ?? defaultMqttPort;

  String _brokerIp;
  int _port;

  /// MQTT 代理服务器使用的客户端标识符。
  String clientId;

  /// 底层 MQTT 客户端实例。
  MqttServerClient? _client;

  /// 当前连接状态。
  MqttConnectionState _state = MqttConnectionState.disconnected;

  /// 当前连接状态。
  MqttConnectionState get state => _state;

  /// 当前底层 MQTT 客户端所属的连接代次。
  int get connectionGeneration => _clientGeneration;

  /// 连接状态变化流控制器。
  final _stateController = StreamController<MqttConnectionState>.broadcast();

  /// 连接状态变化流。
  ///
  /// 新订阅者会先收到当前状态，然后继续接收后续变化。
  Stream<MqttConnectionState> get stateStream async* {
    yield _state;
    yield* _stateController.stream;
  }

  /// 传入 Protobuf 消息的流控制器。
  final _messageController = StreamController<MqttInboundMessage>.broadcast();

  /// 最近消息缓存，保留接收时刻和连接代次并补发给后订阅者（最多 50 条）。
  final List<MqttInboundMessage> _messageCache = [];

  static const int _maxMessageCache = 50;

  /// 已接收的 MQTT 消息流，包含载荷、原始接收时刻和连接代次。
  ///
  /// 新订阅者会先收到缓存消息，然后继续接收实时消息。
  Stream<MqttInboundMessage> get messageStream async* {
    for (final msg in _messageCache) {
      yield msg;
    }
    yield* _messageController.stream;
  }

  /// 是否启用自动重连。
  bool _autoReconnect = true;

  /// 当前重连延迟。
  Duration _currentReconnectDelay = mqttReconnectDelay;

  /// 调度重连尝试的定时器。
  Timer? _reconnectTimer;

  /// 底层 MQTT 更新流订阅。
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updatesSub;

  /// 当前底层客户端代次，用于忽略旧客户端迟到回调。
  int _clientGeneration = 0;

  /// 已订阅主题集合。
  final Set<String> _subscribedTopics = {};

  void _setState(MqttConnectionState newState) {
    if (_state == newState) return;
    _state = newState;
    _stateController.add(newState);
  }

  /// 建立到 MQTT 代理服务器的连接。
  ///
  /// [brokerIp] 和 [port] 覆盖构造函数默认值
  /// 用于本次连接尝试。
  Future<void> connect({String? brokerIp, int? port}) async {
    if (_state == MqttConnectionState.connecting ||
        _state == MqttConnectionState.connected) {
      return;
    }

    _autoReconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _cancelUpdatesSubscription();

    if (brokerIp != null) _brokerIp = brokerIp;
    if (port != null) _port = port;

    _setState(MqttConnectionState.connecting);

    try {
      _client?.disconnect();
      final generation = ++_clientGeneration;
      final client = MqttServerClient(_brokerIp, clientId)
        ..port = _port
        ..keepAlivePeriod = mqttKeepAliveInterval.inSeconds
        ..autoReconnect = false; // 本类手动处理重连。
      // ignore: cascade_invocations
      client.onConnected = () => _onConnected(generation);
      // ignore: cascade_invocations
      client.onDisconnected = () => _onDisconnected(generation);
      // ignore: cascade_invocations
      client.onSubscribed = _onSubscribed;
      // ignore: cascade_invocations
      client.onSubscribeFail = _onSubscribeFail;
      // ignore: cascade_invocations
      client.pongCallback = _onPong;
      _client = client;

      _client!.connectionMessage = MqttConnectMessage()
        ..withClientIdentifier(clientId)
        ..startClean();

      await _client!.connect().timeout(mqttConnectionTimeout);

      _updatesSub = _client!.updates!.listen(
        (messages) => _onMessage(messages, generation),
      );
      _setState(MqttConnectionState.connected);
      _currentReconnectDelay = mqttReconnectDelay;

      // 连接恢复后重新订阅之前保存的主题。
      for (final topic in _subscribedTopics) {
        _subscribe(topic);
      }
    } on Exception catch (e) {
      _setState(MqttConnectionState.error);
      _scheduleReconnect();
      throw MqttConnectionException('Failed to connect: $e');
    }
  }

  /// 断开 MQTT 代理服务器连接。
  void disconnect() {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    unawaited(_cancelUpdatesSubscription());
    _clientGeneration++;
    _client?.disconnect();
    _client = null;
    _setState(MqttConnectionState.disconnected);
  }

  /// 以 QoS 1 订阅主题。
  void subscribe(String topic) {
    _subscribedTopics.add(topic);
    if (_state == MqttConnectionState.connected) {
      _subscribe(topic);
    }
  }

  void _subscribe(String topic) {
    _client?.subscribe(topic, MqttQos.atLeastOnce);
  }

  /// 取消订阅主题。
  void unsubscribe(String topic) {
    _subscribedTopics.remove(topic);
    _client?.unsubscribe(topic);
  }

  /// 向 [topic] 发布 Protobuf 消息。
  void publish(String topic, GeneratedMessage message) {
    if (_state != MqttConnectionState.connected) {
      throw StateError('Cannot publish: not connected');
    }

    final buffer = typed.Uint8Buffer()..addAll(message.writeToBuffer());
    final builder = MqttClientPayloadBuilder()..addBuffer(buffer);

    _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void _onConnected(int generation) {
    if (generation != _clientGeneration) return;
    _setState(MqttConnectionState.connected);
  }

  void _onDisconnected(int generation) {
    if (generation != _clientGeneration) return;
    if (_state == MqttConnectionState.connecting) return;
    _setState(MqttConnectionState.disconnected);
    if (_autoReconnect) {
      _scheduleReconnect();
    }
  }

  void _onSubscribed(String topic) {
    // 代理服务器已确认订阅。
  }

  void _onSubscribeFail(String topic) {
    // 订阅失败；下次重连后会重试。
  }

  void _onPong() {
    // 代理服务器已响应 PINGREQ。
  }

  void _onMessage(
    List<MqttReceivedMessage<MqttMessage>>? messages,
    int generation,
  ) {
    if (messages == null || generation != _clientGeneration) return;

    for (final msg in messages) {
      final payload = msg.payload as MqttPublishMessage;
      // 按逻辑长度复制：payload.message 是 Uint8Buffer，
      // 其底层 ByteBuffer 可能因扩容大于真实消息长度。
      // 直接用 Uint8List.view(buffer) 会带上尾部填充，
      // 导致 Protobuf 解析器把填充的 0 字节读成非法字段标签。
      final data = Uint8List.fromList(payload.payload.message);
      final tuple = (
        topic: msg.topic,
        payload: data,
        receivedAt: DateTime.now(),
        connectionGeneration: generation,
      );
      _messageCache.add(tuple);
      if (_messageCache.length > _maxMessageCache) {
        _messageCache.removeAt(0);
      }
      _messageController.add(tuple);
    }
  }

  void _scheduleReconnect() {
    if (!_autoReconnect) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_currentReconnectDelay, () async {
      if (_state == MqttConnectionState.connected) return;

      _currentReconnectDelay = Duration(
        milliseconds: (_currentReconnectDelay.inMilliseconds * 1.5)
            .clamp(
              mqttReconnectDelay.inMilliseconds,
              mqttMaxReconnectDelay.inMilliseconds,
            )
            .toInt(),
      );

      try {
        await connect();
      } on Exception {
        // 重连失败；下次按更长延迟继续重试。
      }
    });
  }

  Future<void> _cancelUpdatesSubscription() async {
    final sub = _updatesSub;
    _updatesSub = null;
    await sub?.cancel();
  }

  /// 释放所有资源。
  void dispose() {
    disconnect();
    _stateController.close();
    _messageController.close();
  }
}

/// MQTT 连接失败时抛出的异常。
class MqttConnectionException implements Exception {
  /// 使用 [message] 创建 [MqttConnectionException]。
  MqttConnectionException(this.message);

  /// 错误描述。
  final String message;

  @override
  String toString() => 'MqttConnectionException: $message';
}

/// MQTT 3333 service wrapper for RoboMaster custom client protocol.
///
/// Handles connection, subscription, Protobuf message publishing,
/// auto-reconnect with exponential backoff, and heartbeat.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:protobuf/protobuf.dart';
import 'package:typed_data/typed_data.dart' as typed;

import '../core/constants/protocol_constants.dart';

/// Connection state of the MQTT service.
enum MqttConnectionState {
  /// Not connected.
  disconnected,

  /// Connection in progress.
  connecting,

  /// Connected and operational.
  connected,

  /// Connection failed.
  error,
}

/// Callback type for connection state changes.
typedef ConnectionStateCallback = void Function(MqttConnectionState state);

/// Service encapsulating MQTT client operations.
class MqttService {
  /// Creates an [MqttService].
  ///
  /// [brokerIp] defaults to [defaultMqttBrokerIp].
  /// [port] defaults to [defaultMqttPort].
  /// [clientId] identifies this client to the broker.
  MqttService({
    required this.clientId,
    String? brokerIp,
    int? port,
  })  : _brokerIp = brokerIp ?? defaultMqttBrokerIp,
        _port = port ?? defaultMqttPort;

  final String _brokerIp;
  final int _port;

  /// Client identifier for MQTT broker.
  String clientId;

  /// Underlying MQTT client instance.
  MqttServerClient? _client;

  /// Current connection state.
  MqttConnectionState _state = MqttConnectionState.disconnected;

  /// Public getter for connection state.
  MqttConnectionState get state => _state;

  /// Stream controller for connection state changes.
  final _stateController =
      StreamController<MqttConnectionState>.broadcast();

  /// Stream of connection state changes.
  ///
  /// New subscribers immediately receive the current state,
  /// then all subsequent changes.
  Stream<MqttConnectionState> get stateStream async* {
    yield _state;
    yield* _stateController.stream;
  }

  /// Stream controller for incoming Protobuf messages.
  final _messageController =
      StreamController<({String topic, Uint8List payload})>.broadcast();

  /// Recent messages cached for late subscribers (max 50).
  final List<({String topic, Uint8List payload})> _messageCache = [];

  static const int _maxMessageCache = 50;

  /// Stream of received (topic, payload) tuples.
  ///
  /// New subscribers receive cached messages first, then live updates.
  Stream<({String topic, Uint8List payload})> get messageStream async* {
    for (final msg in _messageCache) {
      yield msg;
    }
    yield* _messageController.stream;
  }

  /// Whether auto-reconnect is enabled.
  bool _autoReconnect = true;

  /// Current reconnect delay.
  Duration _currentReconnectDelay = mqttReconnectDelay;

  /// Timer for scheduled reconnection attempts.
  Timer? _reconnectTimer;

  /// Set of subscribed topics.
  final Set<String> _subscribedTopics = {};

  void _setState(MqttConnectionState newState) {
    if (_state == newState) return;
    _state = newState;
    _stateController.add(newState);
  }

  /// Establishes connection to the MQTT broker.
  ///
  /// [brokerIp] and [port] override the constructor defaults
  /// for this connection attempt.
  Future<void> connect({String? brokerIp, int? port}) async {
    if (_state == MqttConnectionState.connecting ||
        _state == MqttConnectionState.connected) {
      return;
    }

    final targetIp = brokerIp ?? _brokerIp;
    final targetPort = port ?? _port;

    _setState(MqttConnectionState.connecting);

    try {
      _client?.disconnect();
      _client = MqttServerClient(targetIp, clientId)
        ..port = targetPort
        ..keepAlivePeriod = mqttKeepAliveInterval.inSeconds
        ..autoReconnect = false // We handle reconnection manually.
        ..onConnected = _onConnected
        ..onDisconnected = _onDisconnected
        ..onSubscribed = _onSubscribed
        ..onSubscribeFail = _onSubscribeFail
        ..pongCallback = _onPong;

      _client!.connectionMessage = MqttConnectMessage()
        ..withClientIdentifier(clientId)
        ..startClean();

      await _client!.connect().timeout(mqttConnectionTimeout);

      _client!.updates!.listen(_onMessage);
      _setState(MqttConnectionState.connected);
      _currentReconnectDelay = mqttReconnectDelay;

      // Re-subscribe to previously subscribed topics.
      for (final topic in _subscribedTopics) {
        _subscribe(topic);
      }
    } on Exception catch (e) {
      _setState(MqttConnectionState.error);
      _scheduleReconnect();
      throw MqttConnectionException('Failed to connect: $e');
    }
  }

  /// Disconnects from the MQTT broker.
  void disconnect() {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _client?.disconnect();
  }

  /// Subscribes to a topic with QoS 1.
  void subscribe(String topic) {
    _subscribedTopics.add(topic);
    if (_state == MqttConnectionState.connected) {
      _subscribe(topic);
    }
  }

  void _subscribe(String topic) {
    _client?.subscribe(topic, MqttQos.atLeastOnce);
  }

  /// Unsubscribes from a topic.
  void unsubscribe(String topic) {
    _subscribedTopics.remove(topic);
    _client?.unsubscribe(topic);
  }

  /// Publishes a Protobuf message to [topic].
  void publish(String topic, GeneratedMessage message) {
    if (_state != MqttConnectionState.connected) {
      throw StateError('Cannot publish: not connected');
    }

    final buffer = typed.Uint8Buffer()
      ..addAll(message.writeToBuffer());
    final builder = MqttClientPayloadBuilder()
      ..addBuffer(buffer);

    _client!.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  void _onConnected() {
    _setState(MqttConnectionState.connected);
  }

  void _onDisconnected() {
    _setState(MqttConnectionState.disconnected);
    if (_autoReconnect) {
      _scheduleReconnect();
    }
  }

  void _onSubscribed(String topic) {
    // Subscription confirmed by broker.
  }

  void _onSubscribeFail(String topic) {
    // Subscription failed; will retry on reconnect.
  }

  void _onPong() {
    // Broker responded to PINGREQ.
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>>? messages) {
    if (messages == null) return;

    for (final msg in messages) {
      final payload = msg.payload as MqttPublishMessage;
      // Copy by logical length: payload.message is a Uint8Buffer whose
      // backing ByteBuffer may be larger than the actual message due to
      // capacity-doubling growth. Uint8List.view(buffer) would include
      // that trailing padding, which corrupts Protobuf deserialization
      // (the parser reads padding zero-bytes as invalid field tags).
      final data = Uint8List.fromList(payload.payload.message);
      final tuple = (topic: msg.topic, payload: data);
      _messageCache.add(tuple);
      if (_messageCache.length > _maxMessageCache) {
        _messageCache.removeAt(0);
      }
      _messageController.add(tuple);
    }
  }

  void _scheduleReconnect() {
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
        // Reconnection failed; will retry with increased delay.
      }
    });
  }

  /// Releases all resources.
  void dispose() {
    disconnect();
    _stateController.close();
    _messageController.close();
  }
}

/// Exception thrown when MQTT connection fails.
class MqttConnectionException implements Exception {
  /// Creates an [MqttConnectionException] with [message].
  MqttConnectionException(this.message);

  /// Error description.
  final String message;

  @override
  String toString() => 'MqttConnectionException: $message';
}

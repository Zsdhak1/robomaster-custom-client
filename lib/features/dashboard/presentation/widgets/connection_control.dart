/// Connection control action for the dashboard top app bar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/mqtt_service.dart';
import '../../../connection/presentation/connection_screen.dart';
import '../../logic/stream_providers.dart';

/// Compact connect/disconnect action for the dashboard top app bar.
///
/// Shows a link icon to (re)connect when disconnected and a link-off icon to
/// disconnect when connected.
class ConnectionAppBarAction extends ConsumerWidget {
  /// Creates a [ConnectionAppBarAction].
  const ConnectionAppBarAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mqttConnectionStateSyncProvider);
    final isConnected = state == MqttConnectionState.connected;

    return IconButton(
      icon: Icon(
        isConnected ? Icons.link_off : Icons.link,
        color: Colors.white,
      ),
      tooltip: isConnected ? '断开' : '重新连接',
      onPressed: isConnected
          ? () => _disconnect(ref)
          : () => _goToConnection(context),
    );
  }

  void _goToConnection(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const ConnectionScreen(),
      ),
    );
  }

  void _disconnect(WidgetRef ref) {
    ref.read(mqttServiceProvider).disconnect();
  }
}

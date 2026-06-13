/// MQTT connection screen with a two-column login + robot selector layout.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/protocol_constants.dart';
import '../../../core/feedback/feedback_messenger.dart';
import '../../../core/navigation/app_shell.dart';
import '../../../core/state/session_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/dashboard/logic/stream_providers.dart';
import '../../../features/settings/logic/record_config_provider.dart';
import '../../../services/mqtt_service.dart';
import '../domain/robot_identity.dart';

/// Screen for connecting to the MQTT broker.
class ConnectionScreen extends ConsumerStatefulWidget {
  /// Creates a [ConnectionScreen].
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  late final TextEditingController _ipController;
  late final TextEditingController _portController;
  bool _isRobotSelectorExpanded = false;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: defaultMqttBrokerIp);
    _portController = TextEditingController(text: defaultMqttPort.toString());
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? defaultMqttPort;
    final clientId = ref.read(selectedRobotIdProvider).toString();

    final service = ref.read(mqttServiceProvider)
      // Update client ID before connecting so the MQTT broker
      // sees the correct robot identity.
      ..clientId = clientId;

    try {
      await service.connect(brokerIp: ip, port: port);
      _subscribeConfiguredTopics(service, ref.read(recordConfigProvider));

      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const AppShell(),
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        context.showErrorSnack('连接失败: $e');
      }
    }
  }

  void _disconnect() {
    ref.read(mqttServiceProvider).disconnect();
  }

  /// Enters the app shell without connecting to a broker.
  ///
  /// Offline mode is for pure replay / record browsing: the dashboard already
  /// degrades gracefully when [GameState.isConnected] is false, so no live
  /// data link is required.
  void _goOffline() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const AppShell(),
      ),
    );
  }

  void _useLocalhost() {
    _ipController.text = '127.0.0.1';
  }

  void _selectRobot(RobotIdentity robot) {
    ref.read(selectedRobotIdProvider.notifier).state = robot.id;
    setState(() => _isRobotSelectorExpanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(mqttConnectionStateSyncProvider);
    final selectedId = ref.watch(selectedRobotIdProvider);
    final accent = teamAccentColor(selectedId);

    // The global MaterialApp theme already follows the selected team
    // (see MainApp), so no local AnimatedTheme is needed here.
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: _LoginPanel(
              accent: accent,
              selectedId: selectedId,
              ipController: _ipController,
              portController: _portController,
              connectionState: connectionState,
              isSelectorExpanded: _isRobotSelectorExpanded,
              onToggleSelector: () => setState(
                () => _isRobotSelectorExpanded = !_isRobotSelectorExpanded,
              ),
              onConnect: _connect,
              onDisconnect: _disconnect,
              onUseLocalhost: _useLocalhost,
              onGoOffline: _goOffline,
            ),
          ),
          Expanded(
            flex: 2,
            child: _RobotSelectorPanel(
              isExpanded: _isRobotSelectorExpanded,
              selectedId: selectedId,
              onSelect: _selectRobot,
            ),
          ),
        ],
      ),
    );
  }
}

/// Left column: brand header, server fields, client-id field, actions.
class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.accent,
    required this.selectedId,
    required this.ipController,
    required this.portController,
    required this.connectionState,
    required this.isSelectorExpanded,
    required this.onToggleSelector,
    required this.onConnect,
    required this.onDisconnect,
    required this.onUseLocalhost,
    required this.onGoOffline,
  });

  final Color accent;
  final int selectedId;
  final TextEditingController ipController;
  final TextEditingController portController;
  final MqttConnectionState connectionState;
  final bool isSelectorExpanded;
  final VoidCallback onToggleSelector;
  final Future<void> Function() onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onUseLocalhost;
  final VoidCallback onGoOffline;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // True top accent strip marking the selected team.
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4,
            color: accent,
          ),
          Expanded(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 36),
                        _buildServerFields(),
                        const SizedBox(height: 12),
                        _ClientIdField(
                          selectedId: selectedId,
                          isExpanded: isSelectorExpanded,
                          onTap: onToggleSelector,
                        ),
                        const SizedBox(height: 24),
                        _ConnectionStatus(state: connectionState),
                        const SizedBox(height: 16),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Image.asset(
      'assets/LoginLogo.png',
      height: 72,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Icon(Icons.memory, size: 56, color: accent),
    );
  }

  Widget _buildServerFields() {
    return Column(
      children: [
        TextField(
          controller: ipController,
          decoration: const InputDecoration(
            labelText: '服务器地址',
            prefixIcon: Icon(Icons.computer),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: portController,
          decoration: const InputDecoration(
            labelText: '端口',
            prefixIcon: Icon(Icons.settings_ethernet),
          ),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final connected = connectionState == MqttConnectionState.connected;
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: connected ? null : onConnect,
          icon: const Icon(Icons.link),
          label: const Text('连接'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: connected ? onDisconnect : null,
          icon: const Icon(Icons.link_off),
          label: const Text('断开'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: connected ? null : onGoOffline,
          icon: const Icon(Icons.cloud_off),
          label: const Text('离线模式（仅浏览/回放）'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onUseLocalhost,
          icon: const Icon(Icons.local_fire_department),
          label: const Text('使用本地测试服务器 (127.0.0.1)'),
        ),
      ],
    );
  }
}

/// The clickable client-id field showing the selected robot identity.
class _ClientIdField extends StatelessWidget {
  const _ClientIdField({
    required this.selectedId,
    required this.isExpanded,
    required this.onTap,
  });

  final int selectedId;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected =
        allRobotIdentities.where((r) => r.id == selectedId).firstOrNull;
    final label = selected?.displayName ?? '点击选择机器人身份';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(rmCardRadius),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '客户端ID',
          prefixIcon: Icon(Icons.badge, color: selected?.sideColor),
          suffixIcon: AnimatedRotation(
            turns: isExpanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.expand_more),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected?.sideColor ?? Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Right column: expands to a two-team robot grid when the id field is tapped.
class _RobotSelectorPanel extends StatelessWidget {
  const _RobotSelectorPanel({
    required this.isExpanded,
    required this.selectedId,
    required this.onSelect,
  });

  final bool isExpanded;
  final int selectedId;
  final void Function(RobotIdentity) onSelect;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: isExpanded ? _buildGrid() : _buildCollapsed(),
    );
  }

  Widget _buildCollapsed() {
    return Builder(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return ColoredBox(
          key: const ValueKey('collapsed'),
          color: scheme.surfaceContainerHighest,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app,
                    size: 64, color: scheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text(
                  '点击左侧「客户端ID」选择登录身份',
                  style:
                      TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid() {
    return Row(
      key: const ValueKey('grid'),
      children: [
        Expanded(
          child: _TeamColumn(
            title: '蓝方',
            background: rmBlueTeamColor,
            robots: blueRobotIdentities,
            selectedId: selectedId,
            onSelect: onSelect,
          ),
        ),
        Expanded(
          child: _TeamColumn(
            title: '红方',
            background: rmRedTeamColor,
            robots: redRobotIdentities,
            selectedId: selectedId,
            onSelect: onSelect,
          ),
        ),
      ],
    );
  }
}

/// A single-team column of robot cards over a solid team background.
class _TeamColumn extends StatelessWidget {
  const _TeamColumn({
    required this.title,
    required this.background,
    required this.robots,
    required this.selectedId,
    required this.onSelect,
  });

  final String title;
  final Color background;
  final List<RobotIdentity> robots;
  final int selectedId;
  final void Function(RobotIdentity) onSelect;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            for (final robot in robots)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RobotCard(
                  robot: robot,
                  isSelected: robot.id == selectedId,
                  onTap: () => onSelect(robot),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A robot card: circular avatar + name, highlighted when selected.
class _RobotCard extends StatelessWidget {
  const _RobotCard({
    required this.robot,
    required this.isSelected,
    required this.onTap,
  });

  final RobotIdentity robot;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: isSelected ? 0.95 : 0.75),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 3,
            ),
          ),
          child: Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  robot.displayName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: robot.sideColor,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: robot.sideColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return ClipOval(
      child: Image.asset(
        robot.iconAsset,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => CircleAvatar(
          radius: 24,
          backgroundColor: robot.sideColor.withValues(alpha: 0.2),
          child: Icon(Icons.smart_toy, color: robot.sideColor),
        ),
      ),
    );
  }
}

/// Displays a colored dot and text describing the connection state.
class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.state});

  final MqttConnectionState state;

  (Color, String) _resolve() => switch (state) {
        MqttConnectionState.disconnected => (Colors.grey, '未连接'),
        MqttConnectionState.connecting => (Colors.orange, '连接中...'),
        MqttConnectionState.connected => (Colors.green, '已连接'),
        MqttConnectionState.error => (Colors.red, '连接错误'),
      };

  @override
  Widget build(BuildContext context) {
    final (color, label) = _resolve();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: rmStatusDotSize,
          height: rmStatusDotSize,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

/// Subscribes to the server→client topics enabled in the record [config].
///
/// The enabled set comes from the data-record configuration (see
/// `recordConfigProvider`), so the operator controls exactly which telemetry
/// topics are received and recorded. Defaults to all recordable topics.
void _subscribeConfiguredTopics(MqttService service, RecordConfig config) {
  for (final topic in config.enabledTopics) {
    service.subscribe(topic);
  }
}

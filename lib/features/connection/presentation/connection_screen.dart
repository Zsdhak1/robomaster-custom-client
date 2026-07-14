/// MQTT 连接页面，采用登录表单 + 机器人选择器的双栏布局。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/protocol_constants.dart';
import '../../../core/feedback/feedback_messenger.dart';
import '../../../core/navigation/app_shell.dart';
import '../../../core/responsive/responsive_ext.dart';
import '../../../core/state/session_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/dashboard/logic/stream_providers.dart';
import '../../../features/settings/logic/record_config_provider.dart';
import '../../../services/mqtt_service.dart';
import '../domain/robot_identity.dart';

/// 用于连接 MQTT 代理服务器的页面。
class ConnectionScreen extends ConsumerStatefulWidget {
  /// 创建 [ConnectionScreen]。
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
      // 连接前更新客户端 ID，使 MQTT 代理服务器识别正确的机器人身份。
      ..clientId = clientId;

    try {
      await service.connect(brokerIp: ip, port: port);
      _subscribeConfiguredTopics(service, ref.read(recordConfigProvider));

      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const AppShell()),
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

  /// 不连接代理服务器，直接进入应用外壳。
  ///
  /// 离线模式用于纯回放或记录浏览。仪表盘在 [GameState.isConnected] 为 false 时会
  /// 优雅降级，因此不需要实时数据链路。
  void _goOffline() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const AppShell()),
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

    // 全局 MaterialApp 主题已经跟随所选队伍（见 MainApp），这里不需要本地 AnimatedTheme。
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

/// 左侧列：品牌头部、服务器字段、客户端 ID 字段和操作按钮。
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
          // 顶部强调色条标记当前选择的队伍。
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: context.sp(4),
            color: accent,
          ),
          Expanded(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: context.insetSym(h: 32, v: 32),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: context.sp(360)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(context),
                        context.sizedBox(h: 36),
                        _buildServerFields(context),
                        context.sizedBox(h: 12),
                        _ClientIdField(
                          selectedId: selectedId,
                          isExpanded: isSelectorExpanded,
                          accent: accent,
                          onTap: onToggleSelector,
                        ),
                        context.sizedBox(h: 24),
                        _ConnectionStatus(state: connectionState),
                        context.sizedBox(h: 16),
                        _buildActionButtons(context),
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

  Widget _buildHeader(BuildContext context) {
    return Image.asset(
      'assets/LoginLogo.png',
      height: context.sp(72),
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          Icon(Icons.memory, size: context.iconSize(56), color: accent),
    );
  }

  Widget _buildServerFields(BuildContext context) {
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
        context.sizedBox(h: 12),
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

  Widget _buildActionButtons(BuildContext context) {
    final connected = connectionState == MqttConnectionState.connected;
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: connected ? null : onConnect,
          icon: const Icon(Icons.link),
          label: const Text('连接'),
        ),
        context.sizedBox(h: 8),
        OutlinedButton.icon(
          onPressed: connected ? onDisconnect : null,
          icon: const Icon(Icons.link_off),
          label: const Text('断开'),
        ),
        context.sizedBox(h: 8),
        OutlinedButton.icon(
          onPressed: connected ? null : onGoOffline,
          icon: const Icon(Icons.cloud_off),
          label: const Text('离线模式（仅浏览/回放）'),
        ),
        context.sizedBox(h: 8),
        TextButton.icon(
          onPressed: onUseLocalhost,
          icon: const Icon(Icons.local_fire_department),
          label: const Text('使用本地测试服务器 (127.0.0.1)'),
        ),
      ],
    );
  }
}

/// 可点击的客户端 ID 字段，显示当前选择的机器人身份。
class _ClientIdField extends StatelessWidget {
  const _ClientIdField({
    required this.selectedId,
    required this.isExpanded,
    required this.accent,
    required this.onTap,
  });

  final int selectedId;
  final bool isExpanded;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = allRobotIdentities
        .where((r) => r.id == selectedId)
        .firstOrNull;
    final label = selected?.displayName ?? '点击选择机器人身份';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.rmCardRadius),
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

/// 右侧列：点击客户端 ID 字段后展开为双方机器人网格。
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
      child: isExpanded ? _buildGrid() : _buildCollapsed(context),
    );
  }

  Widget _buildCollapsed(BuildContext context) {
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
                Icon(
                  Icons.touch_app,
                  size: context.iconSize(64),
                  color: scheme.onSurfaceVariant,
                ),
                context.sizedBox(h: 16),
                Text(
                  '点击左侧「客户端ID」选择登录身份',
                  style: context.textTheme.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
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

/// 单个队伍的机器人卡片列，使用实心队伍背景色。
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
          padding: context.insetAll(20),
          children: [
            Text(
              title,
              style: context.textTheme.headlineSmall!.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            context.sizedBox(h: 12),
            for (final robot in robots)
              Padding(
                padding: context.insetOnly(b: 12),
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

/// 机器人卡片：圆形头像和名称，选中时高亮。
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
      borderRadius: BorderRadius.circular(context.sp(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.sp(16)),
        child: Container(
          padding: context.insetAll(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.sp(16)),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: context.sp(3),
            ),
          ),
          child: Row(
            children: [
              _buildAvatar(context),
              context.sizedBox(w: 16),
              Expanded(
                child: Text(
                  robot.displayName,
                  style: context.textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: robot.sideColor,
                  ),
                ),
              ),
              if (isSelected) Icon(Icons.check_circle, color: robot.sideColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        robot.iconAsset,
        width: context.rmRobotIconSize,
        height: context.rmRobotIconSize,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => CircleAvatar(
          radius: context.sp(24),
          backgroundColor: robot.sideColor.withValues(alpha: 0.2),
          child: Icon(Icons.smart_toy, color: robot.sideColor),
        ),
      ),
    );
  }
}

/// 显示彩色圆点和文本来描述连接状态。
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
          width: context.rmStatusDotSize,
          height: context.rmStatusDotSize,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        context.sizedBox(w: 8),
        Text(label),
      ],
    );
  }
}

/// 订阅记录 [config] 中启用的服务器到客户端主题。
///
/// 启用集合来自数据记录配置（见 `recordConfigProvider`），操作者可精确控制接收并记录
/// 哪些遥测主题。默认启用所有可记录主题。
void _subscribeConfiguredTopics(MqttService service, RecordConfig config) {
  final topics = {...config.enabledTopics, ...notificationRequiredTopics};
  for (final topic in topics) {
    service.subscribe(topic);
  }
}

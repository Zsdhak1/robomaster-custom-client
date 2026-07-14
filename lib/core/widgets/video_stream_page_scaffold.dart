/// 两个视频流页面共用的 Scaffold 外壳。
///
/// 在每个页面保留各自流控制器和操作的同时，让 AppBar、MQTT 徽标位置和流 FAB 行为
/// 在视觉上保持一致。
library;

import 'package:flutter/material.dart';

import '../responsive/responsive_ext.dart';
import 'mqtt_login_badge.dart';
import 'stream_connection_fab.dart';

/// UDP 和自定义图传流共用的页面外壳。
class VideoStreamPageScaffold extends StatelessWidget {
  /// 创建共享视频流页面 scaffold。
  const VideoStreamPageScaffold({
    required this.title,
    required this.body,
    required this.isRunning,
    required this.onToggle,
    this.appBarActions = const [],
    this.secondaryActions = const [],
    super.key,
  });

  /// AppBar 标题。
  final String title;

  /// 全屏页面主体，通常是视频双栏布局。
  final Widget body;

  /// 背后的视频流当前是否正在运行。
  final bool isRunning;

  /// 启动或停止背后的视频流。
  final Future<void> Function() onToggle;

  /// AppBar 中的可选紧凑控件。
  final List<Widget> appBarActions;

  /// 可选的次级 FAB 操作。
  final List<StreamFabAction> secondaryActions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: appBarActions),
      body: Stack(
        children: [
          Positioned.fill(child: body),
          Positioned(
            top: context.sp(12),
            right: context.sp(12),
            child: const MqttLoginBadge(),
          ),
        ],
      ),
      floatingActionButton: StreamConnectionFab(
        isRunning: isRunning,
        onToggle: onToggle,
        secondaryActions: secondaryActions,
      ),
    );
  }
}

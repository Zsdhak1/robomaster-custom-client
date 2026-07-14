/// 视频流页面共用的双栏布局。
///
/// 宽窗口使用左侧视频、右侧状态面板的标准拆分；紧凑窗口则把状态面板堆叠在视频下方，
/// 避免视频区域被过度压缩。
library;

import 'package:flutter/material.dart';

import '../responsive/responsive_ext.dart';

/// 视频播放器和侧边面板使用的响应式布局。
class VideoTwoPaneLayout extends StatelessWidget {
  /// 创建共享视频双栏布局。
  const VideoTwoPaneLayout({
    required this.player,
    required this.sidePanel,
    this.compactBreakpoint = 900,
    super.key,
  });

  /// 主视频/播放器区域。
  final Widget player;

  /// 状态、调试和血量侧边面板。
  final Widget sidePanel;

  /// 低于该宽度时，两块面板垂直堆叠。
  final double compactBreakpoint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: context.insetAll(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < compactBreakpoint) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: player),
                context.sizedBox(h: 12),
                Expanded(flex: 2, child: sidePanel),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: player),
              context.sizedBox(w: 12),
              Expanded(child: sidePanel),
            ],
          );
        },
      ),
    );
  }
}

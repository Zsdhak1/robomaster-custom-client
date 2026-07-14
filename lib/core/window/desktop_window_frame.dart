import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../responsive/design_constants.dart';
import 'desktop_window_controller.dart';

/// 在 Windows 页面上叠加窗口拖动区域与窗口控制按钮。
class DesktopWindowFrame extends StatefulWidget {
  /// 创建桌面窗口框架。
  const DesktopWindowFrame({required this.child, super.key});

  /// 占满窗口的应用内容。
  final Widget child;

  @override
  State<DesktopWindowFrame> createState() => _DesktopWindowFrameState();
}

class _DesktopWindowFrameState extends State<DesktopWindowFrame> {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshMaximizedState());
  }

  @override
  Widget build(BuildContext context) {
    if (!DesktopWindowController.isSupported) return widget.child;
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        Positioned(
          top: 0,
          left: 56,
          right: _windowControlsWidth,
          child: _buildDragRegion(),
        ),
        Positioned(top: 0, right: 0, child: _buildWindowControls(context)),
      ],
    );
  }

  Widget _buildWindowControls(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.78),
      elevation: 2,
      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: desktopTitleBarHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _WindowButton(
              tooltip: minimizeWindowLabel,
              icon: Icons.remove,
              onPressed: DesktopWindowController.minimize,
            ),
            _WindowButton(
              tooltip: _isMaximized ? restoreWindowLabel : maximizeWindowLabel,
              icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
              onPressed: _toggleMaximize,
            ),
            _WindowButton(
              tooltip: closeWindowLabel,
              icon: Icons.close,
              foregroundColor: scheme.onSurface,
              hoverColor: scheme.error,
              hoverForegroundColor: scheme.onError,
              onPressed: DesktopWindowController.close,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragRegion() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => unawaited(DesktopWindowController.startDrag()),
      onDoubleTap: _toggleMaximize,
      child: const SizedBox(height: desktopTitleBarHeight),
    );
  }

  static const double _windowControlsWidth = 144;

  Future<void> _toggleMaximize() async {
    final isMaximized = await DesktopWindowController.toggleMaximize();
    if (!mounted) return;
    setState(() => _isMaximized = isMaximized);
  }

  Future<void> _refreshMaximizedState() async {
    final isMaximized = await DesktopWindowController.isMaximized();
    if (!mounted) return;
    setState(() => _isMaximized = isMaximized);
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.foregroundColor,
    this.hoverColor,
    this.hoverForegroundColor,
  });

  final String tooltip;
  final IconData icon;
  final Future<void> Function() onPressed;
  final Color? foregroundColor;
  final Color? hoverColor;
  final Color? hoverForegroundColor;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final foreground = _hovered
        ? widget.hoverForegroundColor ?? widget.foregroundColor
        : widget.foregroundColor;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: IconButton(
          onPressed: () => unawaited(widget.onPressed()),
          style: IconButton.styleFrom(
            minimumSize: const Size(48, desktopTitleBarHeight),
            shape: const RoundedRectangleBorder(),
            foregroundColor: foreground,
            backgroundColor: _hovered ? widget.hoverColor : null,
          ),
          icon: Icon(widget.icon, size: 18),
        ),
      ),
    );
  }
}

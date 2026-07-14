/// 高显著性仪表盘通知使用的实验性覆盖层样式。
library;

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../../core/responsive/responsive_ext.dart';
import '../../../../core/theme/app_theme.dart';
import '../../logic/dashboard_notification_models.dart';

/// 使用当前选中的样式渲染仪表盘通知。
class DashboardNotificationOverlay extends StatefulWidget {
  /// 创建 [DashboardNotificationOverlay]。
  const DashboardNotificationOverlay({
    required this.items,
    required this.style,
    required this.onDismiss,
    super.key,
  });

  /// 当前可见的通知，最新在前。
  final List<DashboardNotificationItem> items;

  /// 当前选中的视觉样式。
  final DashboardNotificationStyle style;

  /// 用户关闭通知时调用。
  final ValueChanged<String> onDismiss;

  @override
  State<DashboardNotificationOverlay> createState() =>
      _DashboardNotificationOverlayState();
}

class _DashboardNotificationOverlayState
    extends State<DashboardNotificationOverlay> {
  late List<_RenderedNotification> _renderedItems;

  @override
  void initState() {
    super.initState();
    _renderedItems = widget.items
        .map(_RenderedNotification.visible)
        .toList(growable: true);
  }

  @override
  void didUpdateWidget(covariant DashboardNotificationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRenderedItems();
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.style) {
      DashboardNotificationStyle.topBanner => Positioned(
          top: context.rmTopBarHeight + context.sp(10),
          left: context.sp(96),
          right: context.sp(96),
          child: Align(
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _buildTopBannerChildren(context),
            ),
          ),
        ),
      DashboardNotificationStyle.rightCorner => Positioned(
          top: context.rmTopBarHeight + context.sp(12),
          right: context.sp(12),
          width: context.sp(320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _buildStackChildren(context),
          ),
        ),
      DashboardNotificationStyle.sideBeacon => Positioned(
          top: context.rmTopBarHeight + context.sp(18),
          left: context.sp(12),
          width: context.sp(300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildStackChildren(context),
          ),
        ),
    };
  }

  List<Widget> _buildTopBannerChildren(BuildContext context) {
    return _buildNotificationChildren(
      context,
      spacing: context.sp(10),
      wrap: (entry) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.sp(960)),
          child: entry,
        ),
      ),
    );
  }

  List<Widget> _buildStackChildren(BuildContext context) {
    return _buildNotificationChildren(
      context,
      spacing: context.sp(12),
      wrap: (entry) => entry,
    );
  }

  List<Widget> _buildNotificationChildren(
    BuildContext context, {
    required double spacing,
    required Widget Function(Widget entry) wrap,
  }) {
    return [
      for (var index = 0; index < _renderedItems.length; index++)
        Padding(
          key: ValueKey<String>(
            'stack-item-${widget.style.name}-${_renderedItems[index].item.id}',
          ),
          padding: EdgeInsets.only(top: index == 0 ? 0 : spacing),
          child: wrap(_buildAnimatedItem(_renderedItems[index])),
        ),
    ];
  }

  Widget _buildAnimatedItem(_RenderedNotification rendered) {
    return _AnimatedNotification(
      key: ValueKey<String>('${widget.style.name}-${rendered.item.id}'),
      item: rendered.item,
      style: widget.style,
      isExiting: rendered.isExiting,
      onExitComplete: () => _handleExitComplete(rendered.item.id),
      child: _buildNotificationCard(rendered.item),
    );
  }

  Widget _buildNotificationCard(DashboardNotificationItem item) {
    return switch (widget.style) {
      DashboardNotificationStyle.topBanner => _TopBannerNotification(
          item: item,
          onDismiss: () => widget.onDismiss(item.id),
        ),
      DashboardNotificationStyle.rightCorner => _RightCornerNotification(
          item: item,
          onDismiss: () => widget.onDismiss(item.id),
        ),
      DashboardNotificationStyle.sideBeacon => _SideBeaconNotification(
          item: item,
          onDismiss: () => widget.onDismiss(item.id),
        ),
    };
  }

  void _syncRenderedItems() {
    final nextById = {
      for (final item in widget.items) item.id: item,
    };
    final nextIds = nextById.keys.toSet();
    final additions = widget.items
        .where((item) => !_renderedItems.any((entry) => entry.item.id == item.id))
        .toList(growable: false);
    final updated = _renderedItems
        .map(
          (entry) => entry.copyWith(
            item: nextById[entry.item.id] ?? entry.item,
            isExiting: !nextIds.contains(entry.item.id),
          ),
        )
        .toList(growable: true);
    for (final item in additions.reversed) {
      updated.insert(0, _RenderedNotification.visible(item));
    }
    if (!_sameRenderedItems(updated)) {
      setState(() => _renderedItems = updated);
    }
  }

  bool _sameRenderedItems(List<_RenderedNotification> next) {
    if (_renderedItems.length != next.length) {
      return false;
    }
    for (var index = 0; index < next.length; index++) {
      final current = _renderedItems[index];
      final candidate = next[index];
      if (current.item.id != candidate.item.id ||
          current.isExiting != candidate.isExiting) {
        return false;
      }
    }
    return true;
  }

  void _handleExitComplete(String id) {
    if (!mounted || widget.items.any((item) => item.id == id)) {
      return;
    }
    setState(() {
      _renderedItems = _renderedItems
          .where((entry) => entry.item.id != id)
          .toList(growable: true);
    });
  }
}

class _RenderedNotification {
  const _RenderedNotification({
    required this.item,
    required this.isExiting,
  });

  const _RenderedNotification.visible(DashboardNotificationItem item)
      : this(item: item, isExiting: false);

  final DashboardNotificationItem item;
  final bool isExiting;

  _RenderedNotification copyWith({
    DashboardNotificationItem? item,
    bool? isExiting,
  }) {
    return _RenderedNotification(
      item: item ?? this.item,
      isExiting: isExiting ?? this.isExiting,
    );
  }
}

class _AnimatedNotification extends StatefulWidget {
  const _AnimatedNotification({
    required this.item,
    required this.style,
    required this.isExiting,
    required this.onExitComplete,
    required this.child,
    super.key,
  });

  final DashboardNotificationItem item;
  final DashboardNotificationStyle style;
  final bool isExiting;
  final VoidCallback onExitComplete;
  final Widget child;

  @override
  State<_AnimatedNotification> createState() => _AnimatedNotificationState();
}

class _AnimatedNotificationState extends State<_AnimatedNotification>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _haloController;
  var _didNotifyExit = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
      reverseDuration: const Duration(milliseconds: 340),
    )..addStatusListener(_handleAnimationStatus);
    _haloController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _playEntry();
  }

  @override
  void didUpdateWidget(covariant _AnimatedNotification oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isExiting != widget.isExiting) {
      widget.isExiting ? _playExit() : _playEntry();
      return;
    }
    if (oldWidget.item.id != widget.item.id || oldWidget.style != widget.style) {
      _playEntry();
    }
  }

  @override
  void dispose() {
    _entryController
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();
    _haloController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.isExiting ? _buildExitChild() : _buildVisibleChild();
  }

  void _playEntry() {
    _didNotifyExit = false;
    _haloController.repeat(reverse: true);
    _entryController.forward(from: 0);
  }

  void _playExit() {
    _haloController.stop();
    if (_entryController.isDismissed) {
      _notifyExitComplete();
      return;
    }
    _entryController.reverse();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && widget.isExiting) {
      _notifyExitComplete();
    }
  }

  void _notifyExitComplete() {
    if (_didNotifyExit) {
      return;
    }
    _didNotifyExit = true;
    widget.onExitComplete();
  }

  Widget _buildEnteredChild() {
    final fade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0, 0.55, curve: Curves.easeOut),
    );
    final glow = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0, 0.72, curve: Curves.easeOutCubic),
    );
    final scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.9,
          end: 1.055,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 62,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.055,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 38,
      ),
    ]).animate(_entryController);
    final slide = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: _entryOffsetFor(widget.style),
          end: _settleOffsetFor(widget.style),
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 72,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: _settleOffsetFor(widget.style),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 28,
      ),
    ]).animate(_entryController);

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: ScaleTransition(
          scale: scale,
          child: AnimatedBuilder(
            animation: glow,
            child: widget.child,
            builder: (context, child) => DecoratedBox(
              decoration: _buildEntryDecoration(glow.value),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisibleChild() {
    final enteredChild = _buildEnteredChild();
    return AnimatedBuilder(
      animation: _haloController,
      child: enteredChild,
      builder: (context, child) => DecoratedBox(
        decoration: _buildHaloDecoration(),
        child: child,
      ),
    );
  }

  Widget _buildExitChild() {
    final exitProgress = CurvedAnimation(
      parent: ReverseAnimation(_entryController),
      curve: Curves.easeInOutCubic,
    );
    final fade = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(
      CurvedAnimation(
        parent: exitProgress,
        curve: const Interval(0.12, 1, curve: Curves.easeInCubic),
      ),
    );
    final scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0.9,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 48,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.9,
          end: 0.7,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 52,
      ),
    ]).animate(exitProgress);
    final slide = Tween<Offset>(
      begin: Offset.zero,
      end: _exitOffsetFor(widget.style),
    ).animate(
      CurvedAnimation(
        parent: exitProgress,
        curve: Curves.easeInOutCubic,
      ),
    );
    final sizeFactor = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(1),
        weight: 68,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 32,
      ),
    ]).animate(exitProgress);

    return SizeTransition(
      sizeFactor: sizeFactor,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: slide,
          child: ScaleTransition(
            scale: scale,
            child: AnimatedBuilder(
              animation: exitProgress,
              child: widget.child,
              builder: (context, child) => DecoratedBox(
                decoration: _buildExitDecoration(exitProgress.value),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildEntryDecoration(double glowValue) {
    return BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: widget.item.accentColor.withValues(
            alpha: (1 - glowValue) * 0.34,
          ),
          blurRadius: lerpDouble(72, 16, glowValue) ?? 28,
          spreadRadius: lerpDouble(10, 0, glowValue) ?? 0,
        ),
      ],
    );
  }

  BoxDecoration _buildExitDecoration(double progress) {
    return BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: widget.item.accentColor.withValues(
            alpha: 0.14 * (1 - progress),
          ),
          blurRadius: lerpDouble(22, 6, progress) ?? 8,
          spreadRadius: lerpDouble(1, -2, progress) ?? 0,
          offset: Offset(0, lerpDouble(8, 2, progress) ?? 2),
        ),
      ],
    );
  }

  BoxDecoration _buildHaloDecoration() {
    final pulse = Curves.easeInOut.transform(_haloController.value);
    return BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: widget.item.accentColor.withValues(
            alpha: 0.2 + pulse * 0.22,
          ),
          blurRadius: 18 + pulse * 28,
          spreadRadius: 2 + pulse * 5,
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.05 + pulse * 0.06),
          blurRadius: 10 + pulse * 12,
          spreadRadius: 1 + pulse,
        ),
      ],
    );
  }

  Offset _entryOffsetFor(DashboardNotificationStyle style) => switch (style) {
        DashboardNotificationStyle.topBanner => const Offset(0, -0.58),
        DashboardNotificationStyle.rightCorner => const Offset(0.32, -0.18),
        DashboardNotificationStyle.sideBeacon => const Offset(-0.3, -0.06),
      };

  Offset _settleOffsetFor(DashboardNotificationStyle style) => switch (style) {
        DashboardNotificationStyle.topBanner => const Offset(0, 0.05),
        DashboardNotificationStyle.rightCorner => const Offset(-0.024, 0.016),
        DashboardNotificationStyle.sideBeacon => const Offset(0.024, 0.012),
      };

  Offset _exitOffsetFor(DashboardNotificationStyle style) => switch (style) {
        DashboardNotificationStyle.topBanner => const Offset(0, -0.035),
        DashboardNotificationStyle.rightCorner => const Offset(0.03, -0.03),
        DashboardNotificationStyle.sideBeacon => const Offset(-0.03, -0.02),
      };
}

class _TopBannerNotification extends StatelessWidget {
  const _TopBannerNotification({
    required this.item,
    required this.onDismiss,
  });

  final DashboardNotificationItem item;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return _NotificationShell(
      item: item,
      onDismiss: onDismiss,
      padding: context.insetSym(h: 18, v: 14),
      gradient: [
        item.accentColor.withValues(alpha: 0.96),
        item.accentColor.withValues(alpha: 0.72),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LeadingIcon(item: item, size: 26),
          context.sizedBox(w: 14),
          Expanded(
            flex: 7,
            child: _TopBannerKeyBlock(
              item: item,
            ),
          ),
          context.sizedBox(w: 14),
          Expanded(
            flex: 4,
            child: _TopBannerDetailBlock(
              item: item,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBannerKeyBlock extends StatelessWidget {
  const _TopBannerKeyBlock({required this.item});

  final DashboardNotificationItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BadgeChip(label: item.badge),
            context.sizedBox(w: 8),
            Text(
              '关键事件',
              style: context.textTheme.labelMedium!.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
                fontWeight: FontWeight.w700,
                letterSpacing: context.sp(0.6),
              ),
            ),
          ],
        ),
        context.sizedBox(h: 6),
        Text(
          item.headline,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.displaySmall!.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            height: 0.95,
          ),
        ),
      ],
    );
  }
}

class _TopBannerDetailBlock extends StatelessWidget {
  const _TopBannerDetailBlock({required this.item});

  final DashboardNotificationItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '描述信息',
          style: context.textTheme.labelMedium!.copyWith(
            color: Colors.white.withValues(alpha: 0.88),
            fontWeight: FontWeight.w700,
            letterSpacing: context.sp(0.4),
          ),
        ),
        context.sizedBox(h: 4),
        Text(
          item.detail,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.titleLarge!.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _RightCornerNotification extends StatelessWidget {
  const _RightCornerNotification({
    required this.item,
    required this.onDismiss,
  });

  final DashboardNotificationItem item;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return _NotificationShell(
      item: item,
      onDismiss: onDismiss,
      padding: context.insetAll(14),
      gradient: [
        Theme.of(context).colorScheme.surface.withValues(alpha: 0.98),
        item.accentColor.withValues(alpha: 0.22),
      ],
      borderColor: item.accentColor.withValues(alpha: 0.72),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LeadingIcon(item: item, size: 22),
              context.sizedBox(w: 10),
              Expanded(
                child: Text(
                  item.headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleSmall!.copyWith(
                    color: rmTextPrimary(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              context.sizedBox(w: 8),
              _BadgeChip(
                label: item.badge,
                color: item.accentColor,
                filled: false,
              ),
            ],
          ),
          context.sizedBox(h: 8),
          Text(
            item.detail,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodyMedium!.copyWith(
              color: rmTextPrimary(context).withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SideBeaconNotification extends StatelessWidget {
  const _SideBeaconNotification({
    required this.item,
    required this.onDismiss,
  });

  final DashboardNotificationItem item;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return _NotificationShell(
      item: item,
      onDismiss: onDismiss,
      padding: context.insetAll(14),
      gradient: [
        item.accentColor.withValues(alpha: 0.22),
        Theme.of(context).colorScheme.surfaceContainerHigh.withValues(
              alpha: 0.98,
            ),
      ],
      borderColor: item.accentColor.withValues(alpha: 0.9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: context.sp(6),
            height: context.sp(82),
            decoration: BoxDecoration(
              color: item.accentColor,
              borderRadius: BorderRadius.circular(context.sp(6)),
              boxShadow: [
                BoxShadow(
                  color: item.accentColor.withValues(alpha: 0.45),
                  blurRadius: context.sp(18),
                  spreadRadius: context.sp(1),
                ),
              ],
            ),
          ),
          context.sizedBox(w: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _LeadingIcon(item: item, size: 22),
                    context.sizedBox(w: 8),
                    Expanded(
                      child: Text(
                        item.headline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.titleSmall!.copyWith(
                          color: rmTextPrimary(context),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                context.sizedBox(h: 8),
                _BadgeChip(
                  label: item.badge,
                  color: item.accentColor,
                  filled: false,
                ),
                context.sizedBox(h: 8),
                Text(
                  item.detail,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall!.copyWith(
                    color: rmTextPrimary(context).withValues(alpha: 0.86),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationShell extends StatelessWidget {
  const _NotificationShell({
    required this.item,
    required this.onDismiss,
    required this.padding,
    required this.gradient,
    required this.child,
    this.borderColor,
  });

  final DashboardNotificationItem item;
  final VoidCallback onDismiss;
  final EdgeInsets padding;
  final List<Color> gradient;
  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.sp(18)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          border: Border.all(
            color: borderColor ?? Colors.white.withValues(alpha: 0.22),
            width: context.sp(1.2),
          ),
          boxShadow: [
            BoxShadow(
              color: item.accentColor.withValues(alpha: 0.26),
              blurRadius: context.sp(28),
              offset: Offset(0, context.sp(12)),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              child: _DismissButton(onPressed: onDismiss),
            ),
            Padding(
              padding: context.insetOnly(r: 28),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _DismissButton extends StatelessWidget {
  const _DismissButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(context.sp(999)),
      child: Padding(
        padding: context.insetAll(2),
        child: Icon(
          Icons.close_rounded,
          size: context.iconSize(18),
          color: Colors.white.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.item, required this.size});

  final DashboardNotificationItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.sp(size + 16),
      height: context.sp(size + 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(item.icon, color: Colors.white, size: context.iconSize(size)),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
    required this.label,
    this.color,
    this.filled = true,
  });

  final String label;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Colors.white;
    final background = filled
        ? Colors.white.withValues(alpha: 0.16)
        : chipColor.withValues(alpha: 0.12);
    final foreground = filled ? Colors.white : chipColor;

    return Container(
      padding: context.insetSym(h: 8, v: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(context.sp(999)),
        border: Border.all(
          color: foreground.withValues(alpha: filled ? 0.32 : 0.42),
        ),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall!.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// 自定义 H.264 视频链路使用的准星覆盖层。
///
/// 复刻原始 Python `_draw_overlay`：
/// - 可移动的淡紫色准星，横竖线贯穿整帧。
/// - 准星中心的浅绿色圆点。
///
/// [aimCenter] 为 `null` 时，准星保持在画布中心，兼容旧行为。
/// 调用方可以把 [aimCenter] 设置为鼠标点击或触摸点的本地坐标来移动整套准星。
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// 原始 Python 解码器使用的 BGR 颜色，映射为 Flutter ARGB。
/// 原始:(230，190，235) -> 0xFFE6BEEA。
const Color _crosshairColor = rmCrosshairColor;

/// 中心圆点使用的 BGR 颜色。
/// 原始:(170，255，170) -> 0xFFAAFFAA。
const Color _centerColor = rmCrosshairCenterColor;

/// 圆半径，单位为逻辑像素；原始 400x400 画布中为 24。
const double _centerCircleRadius = 24.0;

/// 默认准星线宽。
const int _defaultLineWidth = 1;

/// 绘制 doorlock sniper 准星覆盖层。
class CrosshairPainter extends CustomPainter {
  /// 创建 [CrosshairPainter]。
  ///
  /// [aimCenter] 位于画布本地坐标系中；为 `null` 时准星绘制在画布中心。
  const CrosshairPainter({
    this.aimCenter,
    this.lineWidth = _defaultLineWidth,
  });

  /// 准星横竖线和中心圆应绘制到的像素位置，使用画布本地坐标。
///
  /// 为 `null`（默认）时使用画布中心，保持原始居中行为。
  final Offset? aimCenter;

  /// 准星线宽。
  final int lineWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 解析准星中心：优先使用调用方提供的点，否则回退到画布中心。
    final center = aimCenter ?? Offset(w / 2, h / 2);
    final cx = center.dx.clamp(0.0, w - 1);
    final cy = center.dy.clamp(0.0, h - 1);

    final crossPaint = Paint()
      ..color = _crosshairColor
      ..strokeWidth = lineWidth.toDouble()
      ..style = PaintingStyle.stroke;

    canvas
      ..drawLine(Offset(0, cy), Offset(w - 1, cy), crossPaint)
      ..drawLine(Offset(cx, 0), Offset(cx, h - 1), crossPaint)
      ..drawCircle(
        Offset(cx, cy),
        _centerCircleRadius,
        Paint()
          ..color = _centerColor
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
  }

  @override
  bool shouldRepaint(covariant CrosshairPainter old) {
    return old.aimCenter != aimCenter || old.lineWidth != lineWidth;
  }
}

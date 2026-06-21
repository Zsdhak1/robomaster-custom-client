/// Crosshair overlay for the custom H.264 video line.
///
/// Replicates the original Python `_draw_overlay`:
/// - A movable lavender crosshair spanning the full frame.
/// - A light-green circle dot at the crosshair center.
///
/// When [aimCenter] is `null` the crosshair stays at the canvas center
/// (backward-compatible default). Callers can set [aimCenter] to the local
/// coordinates of a mouse click / tap to move the entire sight there.
library;

import 'package:flutter/material.dart';

/// BGR color from the original Python decoder, mapped to Flutter ARGB.
/// Original: (230, 190, 235) -> 0xFFE6BEEA.
const Color _crosshairColor = Color(0xFFE6BEEA);

/// BGR color for the center dot.
/// Original: (170, 255, 170) -> 0xFFAAFFAA.
const Color _centerColor = Color(0xFFAAFFAA);

/// Circle radius in logical pixels (original: 24 at 400x400).
const double _centerCircleRadius = 24.0;

/// Default crosshair line width.
const int _defaultLineWidth = 1;

/// Paints the doorlock sniper crosshair overlay.
class CrosshairPainter extends CustomPainter {
  /// Creates a [CrosshairPainter].
  ///
  /// [aimCenter] is in the local coordinate space of the canvas. When `null`
  /// the crosshair is drawn at the canvas center.
  const CrosshairPainter({
    this.aimCenter,
    this.lineWidth = _defaultLineWidth,
  });

  /// The pixel position (in canvas-local coordinates) where both the
  /// crosshair lines and the circle should be drawn.
  ///
  /// When `null` (default) the canvas center is used, preserving the original
  /// always-centered behaviour.
  final Offset? aimCenter;

  /// Width of the crosshair lines.
  final int lineWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Resolve the crosshair centre: use the caller-provided point or fall
    // back to the canvas centre.
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

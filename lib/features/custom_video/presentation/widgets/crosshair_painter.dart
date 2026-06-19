/// Crosshair overlay for the custom H.264 video line.
///
/// Replicates the original Python `_draw_overlay`:
/// - A movable lavender crosshair spanning the full frame.
/// - A fixed light-green circle dot at the exact center.
library;

import 'package:flutter/material.dart';

/// BGR color from the original Python decoder, mapped to Flutter ARGB.
/// Original: (230, 190, 235) -> 0xFFE6BEEA.
const Color _crosshairColor = Color(0xFFE6BEEA);

/// BGR color for the fixed center dot.
/// Original: (170, 255, 170) -> 0xFFAAFFAA.
const Color _centerColor = Color(0xFFAAFFAA);

/// Fixed center circle radius in logical pixels (original: 24 at 400x400).
const double _centerCircleRadius = 24.0;

/// Default crosshair line width.
const int _defaultLineWidth = 1;

/// Paints the doorlock sniper crosshair overlay.
class CrosshairPainter extends CustomPainter {
  /// Creates a [CrosshairPainter].
  const CrosshairPainter({
    this.offsetX = 0,
    this.offsetY = 0,
    this.lineWidth = _defaultLineWidth,
  });

  /// Horizontal offset of the crosshair center relative to screen center.
  final int offsetX;

  /// Vertical offset of the crosshair center relative to screen center.
  final int offsetY;

  /// Width of the crosshair lines.
  final int lineWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final cx = (w / 2 + offsetX).clamp(0.0, w - 1);
    final cy = (h / 2 + offsetY).clamp(0.0, h - 1);

    final crossPaint = Paint()
      ..color = _crosshairColor
      ..strokeWidth = lineWidth.toDouble()
      ..style = PaintingStyle.stroke;

    canvas
      ..drawLine(Offset(0, cy), Offset(w - 1, cy), crossPaint)
      ..drawLine(Offset(cx, 0), Offset(cx, h - 1), crossPaint)
      ..drawCircle(
        Offset(w / 2, h / 2),
        _centerCircleRadius,
        Paint()
          ..color = _centerColor
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
  }

  @override
  bool shouldRepaint(covariant CrosshairPainter old) {
    return old.offsetX != offsetX ||
        old.offsetY != offsetY ||
        old.lineWidth != lineWidth;
  }
}

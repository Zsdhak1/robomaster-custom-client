/// Ready‑to‑use widgets that scale with the window size.
///
/// These are thin wrappers that read [ResponsiveContext.scale] internally
/// so callers do not need to repeat the scaling formula.
library;

import 'package:flutter/material.dart';

import 'responsive_ext.dart';

// ---------------------------------------------------------------------------
// ScaledSizedBox
// ---------------------------------------------------------------------------

/// A [SizedBox] whose [width] and [height] are multiplied by the current
/// [ResponsiveContext.scale].
class ScaledSizedBox extends StatelessWidget {
  /// Creates a [ScaledSizedBox].
  const ScaledSizedBox({super.key, this.width, this.height});

  /// Base width (will be scaled automatically).
  final double? width;

  /// Base height (will be scaled automatically).
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width != null ? context.sp(width!) : null,
      height: height != null ? context.sp(height!) : null,
    );
  }
}

// ---------------------------------------------------------------------------
// ScaledPadding
// ---------------------------------------------------------------------------

/// A [Padding] widget whose padding values are scaled.
class ScaledPadding extends StatelessWidget {
  /// Creates a [ScaledPadding] with scaled [EdgeInsets.all].
  const ScaledPadding.all({
    super.key,
    required double value,
    required this.child,
  }) : _insets = null,
       _all = value,
       _h = 0,
       _v = 0;

  /// Creates a [ScaledPadding] with scaled symmetric insets.
  const ScaledPadding.symmetric({
    super.key,
    double horizontal = 0,
    double vertical = 0,
    required this.child,
  }) : _insets = null,
       _all = null,
       _h = horizontal,
       _v = vertical;

  /// Creates a [ScaledPadding] with a pre‑computed scaled [EdgeInsets].
  ///
  /// Use this when callers have already computed the insets via
  /// [ResponsiveContext] helpers.
  const ScaledPadding.fromInsets({
    super.key,
    required EdgeInsets insets,
    required this.child,
  }) : _insets = insets,
       _all = null,
       _h = 0,
       _v = 0;

  final EdgeInsets? _insets;
  final double? _all;
  final double _h;
  final double _v;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (_insets != null) return Padding(padding: _insets, child: child);
    return Padding(
      padding: _all != null
          ? context.insetAll(_all)
          : context.insetSym(h: _h, v: _v),
      child: child,
    );
  }
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The chart's two axes in orange, and dashed guides from each size to the
/// top of its bar and from each bar's edge down to its quality.
class WhisperAxesPainter extends CustomPainter {
  const WhisperAxesPainter({
    required this.left,
    required this.top,
    required this.baseline,
    required this.right,
    required this.bars,
    required this.colors,
  });

  final double left;
  final double top;
  final double baseline;
  final double right;
  final List<Rect> bars;

  /// The roles the axes are drawn in. A painter stands outside the widget
  /// tree and has no context to read them off.
  final LoreDubColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final guide = Paint()
      ..color = colors.ink.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (final bar in bars) {
      // From the size on the axis to the top of its bar...
      _dash(canvas, Offset(left, bar.top), Offset(bar.left - 2, bar.top), guide);
      // ...and from the bar's edge down to its quality.
      _dash(canvas, Offset(bar.right, baseline), Offset(bar.right, baseline + 28), guide);
    }
    final axis = Paint()
      ..color = colors.accent
      ..strokeWidth = 2;
    canvas
      ..drawLine(Offset(left, top), Offset(left, baseline), axis)
      ..drawLine(Offset(left, baseline), Offset(right, baseline), axis);
  }

  static void _dash(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 5.0;
    const gap = 4.0;
    final length = (to - from).distance;
    if (length <= 0) return;
    final step = (to - from) / length;
    for (var travelled = 0.0; travelled < length; travelled += dash + gap) {
      final end = math.min(travelled + dash, length);
      canvas.drawLine(from + step * travelled, from + step * end, paint);
    }
  }

  @override
  bool shouldRepaint(WhisperAxesPainter oldDelegate) =>
      oldDelegate.colors != colors ||
      oldDelegate.left != left ||
      oldDelegate.top != top ||
      oldDelegate.baseline != baseline ||
      oldDelegate.right != right ||
      !_sameBars(oldDelegate.bars, bars);

  static bool _sameBars(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}

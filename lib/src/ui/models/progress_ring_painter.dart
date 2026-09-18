// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// A dashed track with the downloaded share laid over it as a solid arc.
class ProgressRingPainter extends CustomPainter {
  const ProgressRingPainter({
    required this.value,
    required this.paused,
    required this.stroke,
  });

  final double value;
  final bool paused;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final track = Paint()
      ..color = LoreDubPalette.orange.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, stroke * 0.45);
    const segments = 36;
    const sweep = 2 * math.pi / segments;
    for (var index = 0; index < segments; index++) {
      canvas.drawArc(rect, index * sweep, sweep * 0.55, false, track);
    }
    if (value <= 0) return;
    final arc = Paint()
      ..color = paused ? LoreDubPalette.orange.withValues(alpha: 0.55) : LoreDubPalette.orange
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value, false, arc);
  }

  @override
  bool shouldRepaint(ProgressRingPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.paused != paused || oldDelegate.stroke != stroke;
}

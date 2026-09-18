// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'progress_ring_painter.dart';

/// The share downloaded as a ring that fills clockwise from the top, with
/// the figure inside it. Orange reads on the light face of a model and on
/// its dark fill alike; a paused download dims its arc.
class ModelProgressDial extends StatelessWidget {
  const ModelProgressDial({
    super.key,
    required this.progress,
    required this.paused,
    required this.size,
  });

  final double progress;
  final bool paused;
  final double size;

  @override
  Widget build(BuildContext context) {
    final stroke = (size * 0.08).clamp(3.0, 7.0);
    return SizedBox.square(
      dimension: size,
      // Progress arrives in steps; the arc glides between them.
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        builder: (context, value, child) => CustomPaint(
          painter: ProgressRingPainter(value: value, paused: paused, stroke: stroke),
          child: child,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(stroke + size * 0.07),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  fontFamily: LoreDubFonts.mono,
                  fontSize: math.max(12, size * 0.27),
                  fontWeight: FontWeight.w600,
                  color: LoreDubPalette.orange,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

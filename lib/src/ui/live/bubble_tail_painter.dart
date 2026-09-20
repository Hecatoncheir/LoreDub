// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// The tail of a transcript bubble, pointing down at the latency badge.
///
/// A painter stands outside the widget tree and has no context to read a
/// role off, so the bubble hands it the colour it is drawn in and this
/// compares it: a theme that repaints the bubble repaints its tail.
class BubbleTailPainter extends CustomPainter {
  const BubbleTailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Asymmetric like the icon: the leading edge slopes away from the bubble
    // and the trailing edge drops almost straight down.
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * 0.82, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant BubbleTailPainter oldDelegate) => oldDelegate.color != color;
}

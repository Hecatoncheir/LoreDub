// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../theme.dart';

/// The tail of a transcript bubble, pointing down at the latency badge.
class BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Asymmetric like the icon: the leading edge slopes away from the bubble
    // and the trailing edge drops almost straight down.
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * 0.82, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = LoreDubPalette.graphite);
  }

  @override
  bool shouldRepaint(covariant BubbleTailPainter oldDelegate) => false;
}

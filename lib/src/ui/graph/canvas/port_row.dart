// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../node_paint.dart';
import 'node_metrics.dart';

/// A row of the card that a socket sits on, labelled towards its own edge.
class PortRow extends StatelessWidget {
  const PortRow({super.key, required this.paint, this.left, this.right});

  final NodePaint paint;
  final String? left;
  final String? right;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: NodeMetrics.rowHeight,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          if (left != null) Expanded(child: _label(left!, TextAlign.left)),
          if (left == null) const Spacer(),
          if (right != null) Expanded(child: _label(right!, TextAlign.right)),
        ],
      ),
    ),
  );

  Widget _label(String text, TextAlign align) => Text(
    text,
    textAlign: align,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontFamily: LoreDubFonts.mono,
      fontSize: 9,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: paint.port,
    ),
  );
}

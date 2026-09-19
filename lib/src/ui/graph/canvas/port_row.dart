// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../node_paint.dart';
import 'node_metrics.dart';
import 'port_label.dart';

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
          if (left case final text?)
            Expanded(
              child: PortLabel(text: text, align: TextAlign.left, color: paint.port),
            )
          else
            const Spacer(),
          if (right case final text?)
            Expanded(
              child: PortLabel(text: text, align: TextAlign.right, color: paint.port),
            ),
        ],
      ),
    ),
  );
}

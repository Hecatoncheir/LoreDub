// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../node_paint.dart';

/// The foot of a node card: what the node is set to, and under it in small
/// capitals where it runs -- with, on a card that has one, a control at the
/// end of the line.
class NodeCardSummary extends StatelessWidget {
  const NodeCardSummary({
    super.key,
    required this.paint,
    required this.headline,
    required this.note,
    this.trailing,
  });

  final NodePaint paint;
  final String headline;
  final String note;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: paint.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                note,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: LoreDubFonts.mono,
                  fontSize: 9,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                  color: paint.muted,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

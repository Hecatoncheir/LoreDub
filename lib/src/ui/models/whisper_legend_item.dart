// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../theme.dart';

/// One entry of the chart's legend: a small bar and what it means.
class WhisperLegendItem extends StatelessWidget {
  const WhisperLegendItem({super.key, required this.mark, required this.label});

  final Widget mark;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      mark,
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          fontFamily: LoreDubFonts.mono,
          fontSize: 11,
          color: context.colors.mutedInk,
        ),
      ),
    ],
  );
}

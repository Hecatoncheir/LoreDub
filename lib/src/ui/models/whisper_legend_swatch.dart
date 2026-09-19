// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../theme.dart';

/// A bar of the chart in miniature: its edge, and either the cloud it wears
/// or how far it is filled.
class WhisperLegendSwatch extends StatelessWidget {
  const WhisperLegendSwatch({
    super.key,
    required this.fill,
    required this.edge,
    this.filled = 1,
    this.icon,
  });

  final Color fill;
  final Color edge;
  final double filled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 16,
    height: 16,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: LoreDubPalette.panel,
      borderRadius: const BorderRadius.all(Radius.circular(4)),
      border: Border.all(color: edge, width: edge == LoreDubPalette.orange ? 2 : 1),
    ),
    child: switch (icon) {
      final mark? => Icon(mark, size: 11, color: fill),
      null => Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: filled,
          widthFactor: 1,
          child: ColoredBox(color: fill),
        ),
      ),
    },
  );
}

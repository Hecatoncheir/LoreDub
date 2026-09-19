// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../common/ease.dart';
import '../theme.dart';

/// The dark that rises from the foot of a tile, a bar or a cell while what
/// it stands for downloads -- the one measure of a download the model
/// screens and the device table share. Laid in a [Stack] behind the rest.
class DownloadFill extends StatelessWidget {
  const DownloadFill({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: AnimatedFractionallySizedBox(
      duration: ease(context, 300),
      heightFactor: progress.clamp(0.0, 1.0),
      widthFactor: 1,
      child: const ColoredBox(color: LoreDubPalette.graphite),
    ),
  );
}

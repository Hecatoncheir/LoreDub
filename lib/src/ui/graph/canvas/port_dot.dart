// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../common/ease.dart';

import 'package:flutter/material.dart';

import '../../../domain/pipeline_graph.dart';
import '../../theme.dart';
import 'node_metrics.dart';

/// A socket: hollow while nothing is attached, filled when something is,
/// ringed while the link being pulled could land on it.
class PortDot extends StatelessWidget {
  const PortDot({
    super.key,
    required this.signal,
    required this.filled,
    required this.offered,
    required this.caught,
  });

  final PipelineSignal signal;
  final bool filled;
  final bool offered;
  final bool caught;

  @override
  Widget build(BuildContext context) {
    final color = signal == PipelineSignal.voice ? LoreDubPalette.graphite : LoreDubPalette.orange;
    return Center(
      child: AnimatedContainer(
        duration: ease(context, 120),
        curve: Curves.easeOut,
        width: caught ? 22 : (offered ? 18 : NodeMetrics.dotRadius * 2),
        height: caught ? 22 : (offered ? 18 : NodeMetrics.dotRadius * 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color : LoreDubPalette.raised,
          border: Border.all(color: caught || offered ? LoreDubPalette.orange : color, width: 2),
        ),
      ),
    );
  }
}

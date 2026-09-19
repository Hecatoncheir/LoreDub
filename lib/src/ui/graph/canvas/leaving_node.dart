// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../domain/compute_device.dart';
import '../../../domain/pipeline_graph.dart';
import 'node_card.dart';
import 'node_metrics.dart';
import 'pipeline_facts.dart';

/// A card on its way off the canvas: where it was, fading, and deaf.
class LeavingNode extends StatelessWidget {
  const LeavingNode({
    super.key,
    required this.node,
    required this.facts,
    required this.availability,
    required this.opacity,
    required this.scale,
  });

  final PipelineNode node;
  final PipelineFacts facts;
  final ComputeAvailability availability;
  final Animation<double> opacity;
  final Animation<double> scale;

  @override
  Widget build(BuildContext context) {
    final size = NodeMetrics.sizeOf(node.kind);
    return Positioned(
      left: node.position.x,
      top: node.position.y,
      width: size.width,
      height: size.height,
      // Deaf to the pointer, and out of reach of the keyboard and a
      // reader as well: it is a picture of a card that is already gone.
      child: ExcludeSemantics(
        child: ExcludeFocus(
          child: IgnorePointer(
            child: FadeTransition(
              opacity: opacity,
              child: ScaleTransition(
                scale: scale,
                child: NodeCard(
                  node: node,
                  facts: facts,
                  availability: availability,
                  selected: false,
                  onTap: () {},
                  onGrab: (_) {},
                  onDrag: (_) {},
                  onDrop: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

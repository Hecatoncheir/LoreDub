// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../common/ease.dart';

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/compute_device.dart';
import '../../../domain/pipeline_graph.dart';
import '../../theme.dart';
import '../node_paint.dart';
import 'hover_region.dart';
import 'node_card_header.dart';
import 'node_card_summary.dart';
import 'node_labels.dart';
import 'node_port_rows.dart';
import 'pipeline_facts.dart';

/// One node, drawn as a card of the same family as the model tiles: a header
/// naming the stage, a row for each socket, and a line of what it is set to.
class NodeCard extends StatelessWidget {
  const NodeCard({
    super.key,
    required this.node,
    required this.facts,
    required this.availability,
    required this.selected,
    required this.onTap,
    required this.onGrab,
    required this.onDrag,
    required this.onDrop,
    this.onRemove,
  });

  final PipelineNode node;
  final PipelineFacts facts;
  final ComputeAvailability availability;
  final bool selected;
  final VoidCallback onTap;

  /// Where the pointer took hold, and where it has got to, both on the
  /// screen. Not the drag's own delta: that is reported in the card's own
  /// coordinates, and the card moves out from under the pointer as it is
  /// dragged, so every step would be measured against a card that had
  /// already answered the step before it.
  final void Function(Offset at) onGrab;
  final void Function(Offset at) onDrag;
  final VoidCallback onDrop;

  /// Takes the node off the canvas. Only a card has one: the stages of the
  /// pipeline are always drawn, bypassed or unrouted as they may be.
  final VoidCallback? onRemove;

  /// The card's face: the orange edge of a chosen card, and a shadow that
  /// lifts it when chosen or under the pointer.
  BoxDecoration _decoration(NodePaint paint, {required bool hovered}) => BoxDecoration(
    color: paint.body,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: selected ? paint.chosen : LoreDubPalette.outline,
      width: selected ? 2 : 1,
    ),
    boxShadow: selected || hovered
        ? [
            BoxShadow(
              color: const Color(0x22171717),
              blurRadius: selected ? 18 : 12,
              offset: Offset(0, selected ? 6 : 4),
            ),
          ]
        : null,
  );

  @override
  Widget build(BuildContext context) {
    final paint = NodePaint.of(node);
    final labels = NodeLabels.of(AppLocalizations.of(context), node, facts, availability);
    return GestureDetector(
      onTap: onTap,
      onPanStart: (details) => onGrab(details.globalPosition),
      onPanUpdate: (details) => onDrag(details.globalPosition),
      onPanEnd: (_) => onDrop(),
      child: HoverRegion(
        cursor: SystemMouseCursors.grab,
        // A card cut out of the mix, or standing under a route that has been
        // taken apart, goes dark rather than blinking dark: what the player
        // just did is worth following with the eye.
        builder: (context, hovered) => AnimatedOpacity(
          duration: ease(context),
          curve: Curves.easeOut,
          opacity: node.unrouted ? 0.55 : 1,
          child: AnimatedContainer(
            duration: ease(context),
            curve: Curves.easeOut,
            decoration: _decoration(paint, hovered: hovered),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NodeCardHeader(
                  node: node,
                  paint: paint,
                  title: labels.title,
                  onRemove: onRemove,
                ),
                NodePortRows(kind: node.kind, paint: paint),
                Expanded(
                  child: NodeCardSummary(
                    paint: paint,
                    headline: labels.headline,
                    note: labels.note,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

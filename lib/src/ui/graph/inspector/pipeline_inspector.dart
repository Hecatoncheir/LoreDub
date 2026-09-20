// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../node_faces.dart';
import '../../theme.dart';
import '../node_panel_theme.dart';

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/compute_device.dart';
import '../../../domain/pipeline_graph.dart';
import '../canvas/node_labels.dart';
import '../canvas/pipeline_facts.dart';
import 'inspector_note.dart';
import 'node_inspector_fields.dart';
import 'node_inspector_header.dart';

/// What the node the player clicked is set to, and the controls that change
/// it.
///
/// Nothing is configured here that is not configured elsewhere: the panel
/// writes into the same settings the Signal setup screen does, so a node is
/// a second way to the same switch rather than a second switch.
class PipelineInspector extends StatelessWidget {
  const PipelineInspector({
    super.key,
    required this.node,
    required this.facts,
    required this.availability,
    this.chained = const {},
  });

  static const double width = 320;

  final PipelineNode node;
  final PipelineFacts facts;
  final ComputeAvailability availability;

  /// The cards whose reader is read by a third, which the substitution does
  /// not follow. Taken from the graph, which worked it out for the canvas.
  final Set<String> chained;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The face the node itself carries: the panel that opens on the orange
    // output is orange, the one that opens on a card of the cast is dark,
    // and a card the mix hears gives the panel its orange head too.
    final paint = NodeFaces.of(context).forNode(node);
    // The whole height of the canvas, against its right edge: the panel is
    // a wall the scheme is worked against rather than a card lying on it.
    // Its own corners are square. It is drawn inside the card the scheme is
    // drawn in, which clips: that frame rounds the two corners that show and
    // cuts the panel off at the edge while it is still coming out from under
    // it, so the radius is written once, where the card's shape is.
    return Theme(
      data: buildLoreDubPanelTheme(paint),
      // Under the theme rather than beside it: what is written here reads
      // `Theme.of` for itself, and a Material of its own is what hands the
      // panel's own text colour to every line that does not ask.
      child: Builder(
        builder: (context) => SizedBox(
          width: width,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: paint.body,
              // No line down the left: the shadow it casts on the canvas is
              // the edge, and a rule as well read as a second one.
              boxShadow: [
                BoxShadow(
                  color: context.colors.shadow,
                  blurRadius: 24,
                  offset: const Offset(-8, 0),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NodeInspectorHeader(
                    node: node,
                    paint: paint,
                    title: NodeLabels.of(l10n, node, facts, availability).title,
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                      children: [
                        if (facts.running && node.kind != PipelineNodeKind.character)
                          InspectorNote(text: l10n.pipelineLockedNote),
                        NodeInspectorFields(
                          node: node,
                          facts: facts,
                          availability: availability,
                          chained: chained,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

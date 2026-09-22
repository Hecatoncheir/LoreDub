// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/compute_device.dart';
import '../../domain/pipeline_graph.dart';
import 'bloc/pipeline_facts_bloc.dart';
import 'bloc/pipeline_graph_bloc.dart';
import 'canvas/pipeline_canvas.dart';
import 'inspector/pipeline_inspector.dart';
import 'graph_toolbar.dart';
import 'inspector_slot.dart';
import 'canvas/pipeline_facts.dart';

/// The pipeline as a scheme: the stages as nodes, the route between them,
/// and the cards of the cast that take a voice from one another.
///
/// Nothing is configured here that is not configured elsewhere. The canvas
/// is drawn from the settings and the cast, and every link the player draws
/// is turned straight back into one of them, so the scheme and the screens
/// can never say different things.
class PipelinePanel extends StatelessWidget {
  const PipelinePanel({super.key});

  /// The scheme is listened to innermost, under the facts it is drawn
  /// from. A pan or a dragged node is a new graph state every frame, and
  /// with that listener on the outside each of those frames built fresh
  /// facts and handed the canvas cards it could tell apart from the ones
  /// it already had. Under them, the facts keep the instance they had
  /// between edits -- `PipelineFactsBloc` makes a new one only when one of
  /// the things the scheme is drawn from moves.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
    child: BlocBuilder<PipelineFactsBloc, PipelineFacts>(
      builder: (context, facts) => _build(context, availability: facts.availability, facts: facts),
    ),
  );

  /// Whether the toolbar would draw itself differently. It reads what can
  /// be undone, what a link came to, the schemes kept and which cards and
  /// packs are on the canvas: panning the scheme or dragging a node is none
  /// of those, and both of those are a new state on every frame.
  static bool _toolbarChanged(PipelineGraphState was, PipelineGraphState now) =>
      was.canUndo != now.canUndo ||
      was.canRedo != now.canRedo ||
      was.refusal != now.refusal ||
      !identical(was.schemes, now.schemes) ||
      !_sameDrawn(was.graph, now.graph);

  /// Whether the two graphs draw the same cards and the same packs, in the
  /// same order: what the toolbar counts beside each name.
  static bool _sameDrawn(PipelineGraph was, PipelineGraph now) {
    String drawn(PipelineNode node) => node.characterId ?? node.packId ?? '';
    final before = [
      for (final node in was.nodes)
        if (node.kind == PipelineNodeKind.character || node.kind == PipelineNodeKind.glossary)
          drawn(node),
    ];
    final after = [
      for (final node in now.nodes)
        if (node.kind == PipelineNodeKind.character || node.kind == PipelineNodeKind.glossary)
          drawn(node),
    ];
    if (before.length != after.length) return false;
    for (var index = 0; index < after.length; index++) {
      if (before[index] != after[index]) return false;
    }
    return true;
  }

  Widget _build(
    BuildContext context, {
    required PipelineFacts facts,
    required ComputeAvailability availability,
  }) {
    return Column(
      children: [
        // Two listeners rather than one over the pair: the canvas answers
        // every frame of a drag, and the toolbar has no business being
        // built again for it.
        BlocBuilder<PipelineGraphBloc, PipelineGraphState>(
          buildWhen: _toolbarChanged,
          builder: (context, graph) => GraphToolbar(state: graph, facts: facts),
        ),
        const SizedBox(height: 12),
        // The panel floats over the canvas rather than beside it: opening it
        // must not move the scheme out from under the pointer that opened it.
        Expanded(
          child: BlocBuilder<PipelineGraphBloc, PipelineGraphState>(
            builder: (context, graph) => _scheme(context, graph, facts, availability),
          ),
        ),
      ],
    );
  }

  Widget _scheme(
    BuildContext context,
    PipelineGraphState graph,
    PipelineFacts facts,
    ComputeAvailability availability,
  ) {
    final selected = graph.selectedNode;
    // One card holds the scheme and the panel over it, and it clips: the
    // panel comes out from under the frame the scheme is drawn in rather
    // than past it. Standing beside the card the panel slid in from
    // somewhere to the right of the editing area, which is a place the
    // screen has not got.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: PipelineCanvas(
              bloc: context.read<PipelineGraphBloc>(),
              state: graph,
              facts: facts,
              availability: availability,
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: InspectorSlot(
              panel: selected == null
                  ? null
                  : PipelineInspector(
                      key: ValueKey(selected.id),
                      node: selected,
                      facts: facts,
                      availability: availability,
                      chained: graph.graph.chained,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

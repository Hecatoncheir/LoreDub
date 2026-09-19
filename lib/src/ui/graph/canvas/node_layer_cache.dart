// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/widgets.dart';

import '../../../domain/pipeline_graph.dart';
import 'link_cut.dart';
import 'link_cut_badge.dart';
import 'link_geometry.dart';
import 'node_inputs.dart';
import 'node_layer.dart';
import 'node_layer_actions.dart';
import 'node_metrics.dart';

/// The layer each node was last drawn as. A dragged node hands the canvas a
/// whole new graph on every frame and a pan hands it a new state: without
/// this, thirty cards and ninety sockets were built again for one of them
/// moving, and for a pan that moved none of them at all. A layer is handed
/// back as the same widget while its inputs compare equal, which is what
/// lets Flutter pass it by.
class NodeLayerCache {
  var _kept = <String, NodeLayer>{};

  /// Throws everything away: what is kept was built against the language
  /// and the theme that were around it.
  void clear() => _kept = {};

  /// A layer for each of [inputs], in their order; only the nodes named
  /// there are remembered for the next frame.
  List<NodeLayer> layersFor(Iterable<NodeInputs> inputs, NodeLayerActions actions) {
    final next = <String, NodeLayer>{};
    for (final from in inputs) {
      final id = from.node.id;
      next[id] = switch (_kept[id]) {
        final kept? when kept.inputs == from => kept,
        _ => NodeLayer(
          // Keyed by the node, so a card taken off the canvas does not hand
          // its place -- and the entrance it has already played -- to the
          // one drawn after it.
          key: ValueKey(id),
          inputs: from,
          actions: actions,
        ),
      };
    }
    _kept = next;
    return [...next.values];
  }
}

/// The badge on each line and where it sat when it was made. A badge rides
/// the middle of its curve, so it is the same badge until one of the two
/// cards it runs between moves.
class BadgeCache {
  var _kept = <PipelineLink, LinkCutBadge>{};

  void clear() => _kept = {};

  /// The badges of [graph]'s lines that can be cut; which lines carry one is
  /// [LinkCut.of]'s to say. Built afresh rather than pruned: a badge whose
  /// line is gone is simply not carried over.
  List<LinkCutBadge> badgesFor(PipelineGraph graph, void Function(PipelineLink link) onCut) {
    final next = <PipelineLink, LinkCutBadge>{};
    for (final link in graph.links) {
      final cut = LinkCut.of(link);
      final middle = _middleOf(graph, link);
      if (cut == null || middle == null) continue;
      next[link] = switch (_kept[link]) {
        final kept? when kept.at == middle => kept,
        _ => LinkCutBadge(at: middle, cut: cut, onCut: () => onCut(link)),
      };
    }
    _kept = next;
    return [...next.values];
  }

  /// The middle of [link]'s curve, or null while an end of it is not drawn.
  static Offset? _middleOf(PipelineGraph graph, PipelineLink link) {
    final from = graph.node(link.from.nodeId);
    final to = graph.node(link.to.nodeId);
    if (from == null || to == null) return null;
    return LinkGeometry.middleOf(
      NodeMetrics.portAt(from, link.from.socket),
      NodeMetrics.portAt(to, link.to.socket),
    );
  }
}

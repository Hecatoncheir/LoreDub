// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../../domain/pipeline_graph.dart';

/// What one edit did to the scheme, for the canvas to play: the lines drawn
/// and cut, the cards taken off and put on.
class SchemeDiff {
  const SchemeDiff({
    required this.appearing,
    required this.fading,
    required this.leaving,
    required this.arriving,
  });

  /// What changed between [was] and [now].
  factory SchemeDiff.between(PipelineGraph was, PipelineGraph now) {
    final before = {for (final node in was.nodes) node.id};
    final after = {for (final node in now.nodes) node.id};
    return SchemeDiff(
      appearing: now.links.toSet().difference(was.links.toSet()),
      fading: was.links.toSet().difference(now.links.toSet()),
      leaving: [
        for (final node in was.nodes)
          if (!after.contains(node.id)) node,
      ],
      arriving: after.difference(before),
    );
  }

  /// The lines just drawn, which grow out of their socket.
  final Set<PipelineLink> appearing;

  /// The lines just cut, which fade where they lay.
  final Set<PipelineLink> fading;

  /// The cards taken off the canvas, kept until they have faded out.
  final List<PipelineNode> leaving;

  /// The ids of the cards just put on it.
  final Set<String> arriving;

  /// Whether the edit drew, cut or moved nothing on and off the canvas --
  /// a card dragged, a view panned -- and so has nothing to play.
  bool get isEmpty => appearing.isEmpty && fading.isEmpty && leaving.isEmpty;
}

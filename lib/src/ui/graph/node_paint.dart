// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../domain/pipeline_graph.dart';

/// What one node is drawn in: the colours of a single face.
///
/// Which face a node wears is `NodeFaces`, which the theme carries; only
/// what is written on a node changes with the face under it. The panel
/// that opens on a node is drawn from the same face, so it is plainly that
/// node's panel rather than a page the node opened.
class NodePaint {
  const NodePaint({
    required this.body,
    required this.header,
    required this.ink,
    required this.muted,
    required this.port,
    required this.rule,
    required this.chosen,
    required this.onChosen,
    required this.sunk,
    required this.dark,
  });

  final Color body;
  final Color header;
  final Color ink;
  final Color muted;

  /// What the socket labels and the line under the title are drawn in.
  final Color port;
  final Color rule;

  /// The border of a node the pointer has chosen, and what is written on
  /// that colour: on the orange ends the mark is the ink rather than more
  /// orange, so what stands on it has to be light again.
  final Color chosen;
  final Color onChosen;

  /// What a field sunk into this face is filled with -- a step further from
  /// the eye than the face itself, so a field is a place to write rather
  /// than an outline drawn on the card.
  final Color sunk;

  /// Whether the face is written on in light. Material reads this to decide
  /// what it draws of its own: a cursor, a scrollbar, an ink splash.
  final bool dark;

  /// This face on its way to [other], for a theme changing under it.
  NodePaint lerp(NodePaint other, double t) => NodePaint(
    body: Color.lerp(body, other.body, t)!,
    header: Color.lerp(header, other.header, t)!,
    ink: Color.lerp(ink, other.ink, t)!,
    muted: Color.lerp(muted, other.muted, t)!,
    port: Color.lerp(port, other.port, t)!,
    rule: Color.lerp(rule, other.rule, t)!,
    chosen: Color.lerp(chosen, other.chosen, t)!,
    onChosen: Color.lerp(onChosen, other.onChosen, t)!,
    sunk: Color.lerp(sunk, other.sunk, t)!,
    dark: t < 0.5 ? dark : other.dark,
  );
}

/// The icon a node of [kind] carries in its head, and in the head of the
/// panel that opens on it.
IconData nodeIcon(PipelineNodeKind kind) => switch (kind) {
  PipelineNodeKind.source => Icons.videogame_asset_rounded,
  PipelineNodeKind.recognition => Icons.graphic_eq_rounded,
  PipelineNodeKind.translation => Icons.translate_rounded,
  PipelineNodeKind.voice => Icons.record_voice_over_rounded,
  PipelineNodeKind.mix => Icons.multitrack_audio_rounded,
  PipelineNodeKind.output => Icons.volume_up_rounded,
  PipelineNodeKind.character => Icons.person_rounded,
  // The icon the glossary's own screen carries in the navigation.
  PipelineNodeKind.glossary => Icons.menu_book_rounded,
};

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../domain/pipeline_graph.dart';
import '../theme.dart';
import 'node_paint.dart';

/// The four faces a node of the canvas is drawn in, carried by the theme.
///
/// They are built from [LoreDubColors], so a second face of the
/// application -- a dark interface -- repaints the canvas with everything
/// else rather than keeping colours of its own. They live beside the
/// canvas rather than in `ui/theme/`: what a node looks like is the graph
/// screen's business, and the theme layer knows nothing of nodes.
@immutable
class NodeFaces extends ThemeExtension<NodeFaces> {
  const NodeFaces({
    required this.plain,
    required this.ends,
    required this.heard,
    required this.cast,
  });

  /// The faces as [colors] paints them.
  ///
  /// The two ends of the pipeline are the accent -- where the game's sound
  /// comes in and where the dubbing leaves -- so the eye finds them without
  /// reading them, and a card of the cast is dark, the way the open section
  /// is drawn in the navigation. Everything between them keeps the raised
  /// face the model tiles use.
  factory NodeFaces.from(LoreDubColors colors) => NodeFaces(
    plain: NodePaint(
      body: colors.raised,
      header: colors.panel,
      ink: colors.ink,
      muted: colors.mutedInk,
      port: colors.mutedInk,
      rule: colors.outline,
      chosen: colors.accent,
      onChosen: colors.onAccent,
      sunk: colors.panel,
      dark: false,
    ),
    ends: NodePaint(
      body: colors.accent,
      header: colors.accent,
      // Light on the accent, as on the graphite of a card: the process name
      // and the strap under it are what a glance at these two nodes is for,
      // and dark on orange left them sitting in the colour rather than on
      // it.
      ink: colors.onAccentLight,
      muted: colors.onAccentMuted,
      // The sockets are light, as the words are. The line under the title
      // is the accent itself: drawn in any other colour it reads as a crack
      // across the node rather than as the edge of its head.
      port: colors.onAccentLight,
      rule: colors.accent,
      // The accent on the accent would be no mark at all, so what is picked
      // out here is picked out in the ink.
      chosen: colors.ink,
      onChosen: colors.onAccentLight,
      sunk: colors.accentStrong,
      dark: true,
    ),
    // A card whose lines leave for the mix, which is the one the player
    // actually hears: its head is the accent of the path it ends in.
    heard: NodePaint(
      body: colors.deep,
      header: colors.accent,
      ink: colors.onDeep,
      muted: colors.onDeepMuted,
      port: colors.onDeepMuted,
      rule: colors.deep,
      chosen: colors.accent,
      onChosen: colors.onAccent,
      sunk: colors.ink,
      dark: true,
    ),
    cast: NodePaint(
      body: colors.deep,
      header: colors.deep,
      ink: colors.onDeep,
      muted: colors.onDeepMuted,
      port: colors.onDeepMuted,
      // The card's own colour: a line across it in any other reads as a
      // crack rather than as the edge of its head, the same as on the ends.
      rule: colors.deep,
      chosen: colors.accent,
      onChosen: colors.onAccent,
      sunk: colors.ink,
      dark: true,
    ),
  );

  /// The faces of the interface as it stands.
  static final light = NodeFaces.from(LoreDubColors.light);

  /// The faces this context is drawn with. A theme that carries none --
  /// a test pumping a bare `MaterialApp` -- is drawn in the light ones.
  static NodeFaces of(BuildContext context) => Theme.of(context).extension<NodeFaces>() ?? light;

  /// A stage of the pipeline.
  final NodePaint plain;

  /// The two ends: the game's sound coming in, the dubbing leaving.
  final NodePaint ends;

  /// A card of the cast the game itself speaks, and one that only lends its
  /// voice.
  final NodePaint heard;
  final NodePaint cast;

  /// The face [node] is drawn in.
  NodePaint forNode(PipelineNode node) => switch (node.kind) {
    PipelineNodeKind.source || PipelineNodeKind.output => ends,
    PipelineNodeKind.character => node.sendsToMix ? heard : cast,
    _ => plain,
  };

  @override
  NodeFaces copyWith({
    NodePaint? plain,
    NodePaint? ends,
    NodePaint? heard,
    NodePaint? cast,
  }) => NodeFaces(
    plain: plain ?? this.plain,
    ends: ends ?? this.ends,
    heard: heard ?? this.heard,
    cast: cast ?? this.cast,
  );

  @override
  NodeFaces lerp(NodeFaces? other, double t) {
    if (other == null) return this;
    return NodeFaces(
      plain: plain.lerp(other.plain, t),
      ends: ends.lerp(other.ends, t),
      heard: heard.lerp(other.heard, t),
      cast: cast.lerp(other.cast, t),
    );
  }
}

/// Puts the faces of the canvas on a theme built without them: the theme
/// layer knows nothing of nodes, and the application puts the two
/// together.
extension ThemeWithNodeFaces on ThemeData {
  ThemeData withNodeFaces([NodeFaces? faces]) =>
      copyWith(extensions: [...extensions.values, faces ?? NodeFaces.light]);
}

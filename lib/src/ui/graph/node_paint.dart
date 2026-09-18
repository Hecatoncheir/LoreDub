// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../domain/pipeline_graph.dart';
import '../theme.dart';

/// What one node is drawn in.
///
/// The two ends of the pipeline are orange -- where the game's sound comes
/// in and where the dubbing leaves -- so the eye finds them without reading
/// them, and a card of the cast is dark, the way the open section is drawn
/// in the navigation. Everything between them keeps the raised face the
/// model tiles use, and only what is written on a node changes with the
/// face under it.
///
/// The panel that opens on a node is drawn from the same face, so it is
/// plainly that node's panel rather than a page the node opened.
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

  /// The face [node] is drawn in.
  factory NodePaint.of(PipelineNode node) => switch (node.kind) {
    PipelineNodeKind.source || PipelineNodeKind.output => ends,
    PipelineNodeKind.character => node.sendsToMix ? heard : cast,
    _ => plain,
  };

  static const plain = NodePaint(
    body: LoreDubPalette.raised,
    header: LoreDubPalette.panel,
    ink: LoreDubPalette.ink,
    muted: LoreDubPalette.mutedInk,
    port: LoreDubPalette.mutedInk,
    rule: LoreDubPalette.outline,
    chosen: LoreDubPalette.orange,
    onChosen: LoreDubPalette.ink,
    sunk: LoreDubPalette.panel,
    dark: false,
  );

  static const ends = NodePaint(
    body: LoreDubPalette.orange,
    header: LoreDubPalette.orange,
    // Light on the orange, as on the graphite of a card: the process name
    // and the strap under it are what a glance at these two nodes is for,
    // and dark on orange left them sitting in the colour rather than on it.
    ink: LoreDubPalette.raised,
    muted: Color(0xCCF7F5F0),
    // The sockets are light, as the words are. The line under the title is
    // the orange itself: drawn in any other colour it reads as a crack
    // across the node rather than as the edge of its head.
    port: LoreDubPalette.raised,
    rule: LoreDubPalette.orange,
    // Orange on the orange would be no mark at all, so what is picked out
    // here is picked out in the ink.
    chosen: LoreDubPalette.ink,
    onChosen: LoreDubPalette.raised,
    sunk: LoreDubPalette.orangeDark,
    dark: true,
  );

  /// A card whose lines leave for the mix, which is the one the player
  /// actually hears: its head is the orange of the path it ends in.
  static const heard = NodePaint(
    body: LoreDubPalette.graphite,
    header: LoreDubPalette.orange,
    ink: LoreDubPalette.raised,
    muted: Color(0xAAF7F5F0),
    port: Color(0xAAF7F5F0),
    rule: LoreDubPalette.graphite,
    chosen: LoreDubPalette.orange,
    onChosen: LoreDubPalette.ink,
    sunk: LoreDubPalette.ink,
    dark: true,
  );

  static const cast = NodePaint(
    body: LoreDubPalette.graphite,
    header: LoreDubPalette.graphite,
    ink: LoreDubPalette.raised,
    muted: Color(0xAAF7F5F0),
    port: Color(0xAAF7F5F0),
    // The card's own colour: a line across it in any other reads as a
    // crack rather than as the edge of its head, the same as on the ends.
    rule: LoreDubPalette.graphite,
    chosen: LoreDubPalette.orange,
    onChosen: LoreDubPalette.ink,
    sunk: LoreDubPalette.ink,
    dark: true,
  );

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
};

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:ui';

import '../../../domain/pipeline_graph.dart';

/// How big every node is, and where its sockets sit on it.
///
/// The canvas paints the links, the ports and the cards from these numbers,
/// so a socket is in one place only: move a row here and the curve, the dot
/// and the label all follow.
abstract final class NodeMetrics {
  static const double width = 240;

  /// A node standing beside the line rather than in it -- a card of the
  /// cast, a pack of the glossary -- is drawn narrower than a stage.
  static const double characterWidth = 210;
  static const double headerHeight = 42;
  static const double rowHeight = 34;
  static const double summaryHeight = 54;

  /// The middle of the [index]th port row, from the top of the card.
  static double rowCentre(int index) => headerHeight + rowHeight / 2 + index * rowHeight;

  /// How many port rows a node of this kind has.
  static int rowsOf(PipelineNodeKind kind) => switch (kind) {
    PipelineNodeKind.voice || PipelineNodeKind.mix || PipelineNodeKind.character => 2,
    _ => 1,
  };

  static double widthOf(PipelineNodeKind kind) => switch (kind) {
    PipelineNodeKind.character || PipelineNodeKind.glossary => characterWidth,
    _ => width,
  };

  static Size sizeOf(PipelineNodeKind kind) =>
      Size(widthOf(kind), headerHeight + rowsOf(kind) * rowHeight + summaryHeight);

  /// Where a socket sits, measured from the top-left of its own node.
  static Offset anchorOf(PipelineSocket socket) => switch (socket) {
    PipelineSocket.gameAudio => Offset(width, rowCentre(0)),
    PipelineSocket.screenText => Offset(width, rowCentre(0)),
    PipelineSocket.detectionIn => Offset(0, rowCentre(0)),
    PipelineSocket.detectedSpeaker => Offset(width, rowCentre(0)),
    PipelineSocket.speechIn => Offset(0, rowCentre(0)),
    PipelineSocket.speechText => Offset(width, rowCentre(0)),
    PipelineSocket.translationIn => Offset(0, rowCentre(0)),
    PipelineSocket.translatedText => Offset(width, rowCentre(0)),
    PipelineSocket.voiceIn => Offset(0, rowCentre(0)),
    PipelineSocket.voiceAudio => Offset(width, rowCentre(0)),
    PipelineSocket.voiceCast => Offset(width, rowCentre(1)),
    PipelineSocket.voiceSpeaker => Offset(0, rowCentre(1)),
    PipelineSocket.mixIn => Offset(0, rowCentre(0)),
    PipelineSocket.mixOut => Offset(width, rowCentre(0)),
    PipelineSocket.mixCast => Offset(0, rowCentre(1)),
    PipelineSocket.streamIn => Offset(0, rowCentre(0)),
    PipelineSocket.characterIn => Offset(0, rowCentre(0)),
    PipelineSocket.readBy => Offset(0, rowCentre(1)),
    PipelineSocket.characterVoice => Offset(characterWidth, rowCentre(0)),
    PipelineSocket.glossaryIn => Offset(0, rowCentre(0)),
    PipelineSocket.glossaryOut => Offset(characterWidth, rowCentre(0)),
  };

  /// Where a socket sits on the canvas, node and all.
  static Offset portAt(PipelineNode node, PipelineSocket socket) =>
      Offset(node.position.x, node.position.y) + anchorOf(socket);

  /// The card itself on the canvas, which a link may be let go anywhere on.
  static Rect boundsOf(PipelineNode node) =>
      Offset(node.position.x, node.position.y) & sizeOf(node.kind);

  /// The rectangle every one of [nodes] fits inside, cards and all, or null
  /// when there are none.
  static Rect? boundsOfAll(Iterable<PipelineNode> nodes) {
    Rect? spread;
    for (final node in nodes) {
      final card = boundsOf(node);
      spread = spread?.expandToInclude(card) ?? card;
    }
    return spread;
  }

  /// How near the pointer has to be let go for a port to catch the link,
  /// and how near it has to be pressed to pick one up. Both are distances on
  /// the screen rather than on the canvas: the scheme shrinks to fit a small
  /// window, but the pointer stays the size it was, and a dot drawn six
  /// pixels across cannot be taken hold of.
  static const double catchRadius = 34;
  static const double grabReach = dotRadius + 9;

  static const double dotRadius = 7;
}

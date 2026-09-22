// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// What a link drawn or cut on the canvas would change, or why it is
/// refused.
library;

import 'character.dart';
import 'pipeline_graph_model.dart';

/// Why a link was not made.
enum ConnectionRefusal {
  /// The two ends carry different things — text into an audio input.
  signal,

  /// Two outputs, or two inputs.
  direction,

  /// Both ends on the same node.
  sameNode,

  /// A pair the engine has no route for, such as the game's sound straight
  /// into the translator.
  unsupported,

  /// Two cards reading each other.
  loop,

  /// The route cannot be changed while a session is running: the models are
  /// loaded for the one it started with. Whose voice reads whom still can.
  locked,

  /// The translator was drawn back into the line with no language to put it
  /// on: every pair the catalogue offers is still to be downloaded.
  translatorMissing,
}

/// What making a link would change. The canvas asks before it draws, and
/// applies the answer to the settings or to the cast.
sealed class GraphConnection {
  const GraphConnection();
}

/// The capture route, which is where the pipeline starts.
final class RouteConnection extends GraphConnection {
  const RouteConnection(this.routed);

  /// Whether the game's sound reaches the stages at all. Taken apart, every
  /// stage stands with nothing coming into it until a link is drawn back.
  final bool routed;
}

/// Whether the translator stands in the line.
///
/// Taken out, what whisper heard goes straight to the voice, and what whisper
/// hands over is English -- so cutting this link is choosing to dub into
/// English, and drawing it back is choosing a language to translate into.
final class TranslationConnection extends GraphConnection {
  const TranslationConnection(this.routed);

  final bool routed;
}

/// Whether one card's voice is wired into the mix. Taken out, the card
/// lends its voice to nobody and the character is read as themselves.
final class CastConnection extends GraphConnection {
  const CastConnection(this.characterId, this.nodeId, this.routed);

  final String characterId;

  /// The drawing the line was pulled from. Joined to the mix, that drawing
  /// is the one the game is expected to speak: a card sends a line on only
  /// when it has one, and this is where it would come from.
  final String nodeId;
  final bool routed;
}

/// Whether the game itself is expected to speak the card drawn at [nodeId].
///
/// This one changes nothing but the drawing: the worker matches every line
/// against the whole cast whatever the canvas says. It is the player's note
/// that this character can be met in the original, which is why it is kept
/// with the arrangement and not with the settings.
final class HeardConnection extends GraphConnection {
  const HeardConnection(this.nodeId, this.heard);

  final String nodeId;
  final bool heard;
}

/// Whose voice reads a card: [readerId], or the pipeline's own when null.
final class ReaderConnection extends GraphConnection {
  const ReaderConnection(this.characterId, this.readerId);

  final String characterId;
  final String? readerId;
}

/// The link is already there; nothing to do.
final class UnchangedConnection extends GraphConnection {
  const UnchangedConnection();
}

final class RefusedConnection extends GraphConnection {
  const RefusedConnection(this.reason);

  final ConnectionRefusal reason;
}

/// What joining [first] and [second] would mean.
///
/// The two are given in the order they were dragged, which may be from the
/// input backwards; the pair is sorted here so the canvas does not have to.
GraphConnection proposeConnection(
  PipelineGraph graph,
  PipelinePort first,
  PipelinePort second, {
  List<Character> characters = const [],
}) {
  if (first.nodeId == second.nodeId) return const RefusedConnection(ConnectionRefusal.sameNode);
  if (first.isInput == second.isInput) {
    return const RefusedConnection(ConnectionRefusal.direction);
  }
  final from = first.isOutput ? first : second;
  final to = first.isOutput ? second : first;
  if (from.socket.signal != to.socket.signal) {
    return const RefusedConnection(ConnectionRefusal.signal);
  }
  if (graph.links.contains(PipelineLink(from, to))) return const UnchangedConnection();
  return switch ((from.socket, to.socket)) {
    (PipelineSocket.gameAudio, PipelineSocket.speechIn) => const RouteConnection(true),
    // The translator back into the line, drawn at either end of it.
    (PipelineSocket.speechText, PipelineSocket.translationIn) ||
    (PipelineSocket.translatedText, PipelineSocket.voiceIn) => const TranslationConnection(true),
    // Recognition straight into the voice: the stage is stepped over, which
    // is what dubbing into English does.
    (PipelineSocket.speechText, PipelineSocket.voiceIn) => const TranslationConnection(false),
    // A card back into the mix: this one speaks again, and the rest stand
    // where they were left.
    (PipelineSocket.characterVoice, PipelineSocket.mixCast) => switch (PipelineNodeIds.characterOf(
      from.nodeId,
    )) {
      final character? => CastConnection(character, from.nodeId, true),
      _ => const RefusedConnection(ConnectionRefusal.unsupported),
    },
    // A card counted among the voices the game speaks.
    (PipelineSocket.voiceCast, PipelineSocket.characterIn) => HeardConnection(to.nodeId, true),
    // The line runs from the character whose part it is to the card that
    // will speak it: what travels the wire is the part, not the timbre.
    (PipelineSocket.characterVoice, PipelineSocket.readBy) => _readerConnection(
      character: PipelineNodeIds.characterOf(from.nodeId) ?? '',
      reader: PipelineNodeIds.characterOf(to.nodeId) ?? '',
      characters: characters,
    ),
    _ => const RefusedConnection(ConnectionRefusal.unsupported),
  };
}

GraphConnection _readerConnection({
  required String reader,
  required String character,
  required List<Character> characters,
}) {
  // Two drawings of one card: it already speaks for itself, and a line
  // between the copies would say nothing else.
  if (reader == character) return const RefusedConnection(ConnectionRefusal.loop);
  for (final known in characters) {
    if (known.id != character) continue;
    // The same rule the card's own panel offers its readers by: two cards
    // reading each other would leave neither a voice to start from.
    final allowed = readersFor(known, characters).any((other) => other.id == reader);
    if (!allowed) return const RefusedConnection(ConnectionRefusal.loop);
  }
  return ReaderConnection(character, reader);
}

/// What cutting [link] would mean.
GraphConnection proposeDisconnect(PipelineLink link) =>
    switch ((link.from.socket, link.to.socket)) {
      // The way into the pipeline comes apart: the stages stay where they
      // are with nothing reaching them, and the route is put back by drawing
      // it.
      (PipelineSocket.gameAudio, _) => const RouteConnection(false),
      // Either half of the translator's line takes the whole stage out: the
      // text goes past it, and the dubbing is the English whisper already
      // hands over.
      (_, PipelineSocket.translationIn) ||
      (PipelineSocket.translatedText, _) => const TranslationConnection(false),
      // The line that steps over the translator is the only text the voice
      // gets. Cutting it cannot leave the voice with nothing to read, so it
      // means the other thing it can mean: the stage goes back into the line.
      (PipelineSocket.speechText, PipelineSocket.voiceIn) => const TranslationConnection(true),
      // One card comes out of the mix: it stays where it was put with nobody
      // standing in for it, and the line drawn back wakes it again. The rest
      // of the cast is not touched -- a scheme is cut a card at a time.
      (_, PipelineSocket.mixCast) => switch (PipelineNodeIds.characterOf(link.from.nodeId)) {
        final character? => CastConnection(character, link.from.nodeId, false),
        _ => const RefusedConnection(ConnectionRefusal.unsupported),
      },
      // The card is no longer counted among the voices the game speaks.
      // Nothing of the pipeline changes with it: it is a note on the canvas.
      (_, PipelineSocket.characterIn) => HeardConnection(link.to.nodeId, false),
      // The card whose part it was takes it back and speaks for itself again.
      (PipelineSocket.characterVoice, PipelineSocket.readBy) => ReaderConnection(
        PipelineNodeIds.characterOf(link.from.nodeId) ?? '',
        null,
      ),
      _ => const RefusedConnection(ConnectionRefusal.unsupported),
    };

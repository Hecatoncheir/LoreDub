// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// What a link drawn or cut on the canvas would change, or why it is
/// refused.
library;

import 'character.dart';
import 'pipeline_glossary.dart';
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

  /// A line between two packs of the glossary, neither of which stands in
  /// the line of text: there is nowhere to put either of them.
  outOfLine,

  /// The voices behind the screen were to be told apart with no converter
  /// on disk, and it is the converter that hears who is speaking.
  converterMissing,
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

/// Whether the game's sound is listened to while the screen is read, so a
/// line is read in the voice of whoever was speaking as it appeared.
///
/// The way through the Screen page's character detection -- the game's
/// sound into it, who it says is speaking into the voice -- is drawn and cut
/// by either of its two lines, and by the switch on the node, all three being
/// the one setting. Nothing of that sound is recognized.
final class VoicesConnection extends GraphConnection {
  const VoicesConnection(this.heard);

  final bool heard;
}

/// Whether the translator stands in the line.
///
/// Taken out on Эфир, what whisper heard goes straight to the voice, and
/// what whisper hands over is English -- so cutting this link is choosing to
/// dub into English, and drawing it back is choosing a language to translate
/// into. On the Screen page, what the screen shows is read as it is: cutting
/// the link says the text is in the dubbing language, and drawing it back
/// that it is English to be translated.
final class TranslationConnection extends GraphConnection {
  const TranslationConnection(this.routed, {this.edits = const []});

  final bool routed;

  /// What the same line does to the packs of the glossary: one drawn into
  /// a translator standing aside is put in the line before it.
  final List<LineEdit> edits;
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

/// Packs of the glossary moved in the line of text, put into it or taken
/// out of it.
///
/// For a pack, standing in the line is being switched on: the dubbing reads
/// it, and the glossary screen says so. Not locked while a session runs --
/// the worker is told what its glossary puts right now, as it is when an
/// entry is written down.
final class GlossaryLineConnection extends GraphConnection {
  const GlossaryLineConnection(this.edits);

  final List<LineEdit> edits;
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
  // The text runs along one line, whisper -- or the screen -- to the voice,
  // and every line of it is worked out there.
  if (from.socket.signal == PipelineSignal.text) {
    return _textConnection(graph, from.nodeId, to.nodeId);
  }
  return switch ((from.socket, to.socket)) {
    (PipelineSocket.gameAudio, PipelineSocket.speechIn) => const RouteConnection(true),
    // Either half of the way through the detection puts the whole of it
    // back, as either half of the translator's line does.
    (PipelineSocket.gameAudio, PipelineSocket.detectionIn) ||
    (PipelineSocket.detectedSpeaker, PipelineSocket.voiceSpeaker) => const VoicesConnection(true),
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

/// What a line of text from [from] into [to] would change.
///
/// A line into or out of a pack of the glossary puts that pack in the line
/// of text right beside the other end -- after it, or before it -- out of
/// wherever it stood, the text running through a drawing once. Of two packs,
/// the one that does not stand in the line joins the one that does, and the
/// one after moves where both do. A line between two stages is the
/// translator's, as it always was.
GraphConnection _textConnection(PipelineGraph graph, String from, String to) {
  if (PipelineNodeIds.isGlossary(to) && _standsInLine(graph, from)) {
    return GlossaryLineConnection([LineMove(to, anchor: from, after: true)]);
  }
  if (PipelineNodeIds.isGlossary(from) && _standsInLine(graph, to)) {
    return _packBefore(graph, from, to);
  }
  if (PipelineNodeIds.isGlossary(from) || PipelineNodeIds.isGlossary(to)) {
    return const RefusedConnection(ConnectionRefusal.outOfLine);
  }
  return _stageConnection(graph, from, to);
}

/// Whether the node at [nodeId] has a place in the line of text a pack can
/// be put beside: a stage always has, a pack only while it stands there.
bool _standsInLine(PipelineGraph graph, String nodeId) =>
    !PipelineNodeIds.isGlossary(nodeId) || graph.node(nodeId)?.feed != null;

/// [pack] put in the line right before [to]. Drawn into a translator that
/// stands aside, the line brings the translator back with it.
GraphConnection _packBefore(PipelineGraph graph, String pack, String to) {
  final move = LineMove(pack, anchor: to, after: false);
  if (to == PipelineNodeIds.translation && !graph.translates) {
    return TranslationConnection(true, edits: [move]);
  }
  return GlossaryLineConnection([move]);
}

/// A line of text between two stages. Where it puts the translator back or
/// steps over it, it does that, as it always has; where the translator
/// already stands as the line would have it, the line can only mean the
/// packs it passes over, and they leave the line.
///
/// The line starts at whisper on Эфир and at the screen on the Screen page;
/// a scheme draws only one of the two, so either is where it starts.
GraphConnection _stageConnection(PipelineGraph graph, String from, String to) =>
    switch ((from, to)) {
      // The translator back into the line, drawn at either end of it.
      (PipelineNodeIds.recognition || PipelineNodeIds.screen, PipelineNodeIds.translation) ||
      (
        PipelineNodeIds.translation,
        PipelineNodeIds.voice,
      ) => graph.translates ? _passingOver(graph, from) : const TranslationConnection(true),
      // Where the line starts, straight into the voice: the stage is stepped
      // over, which is what dubbing into English does -- or, on the Screen
      // page, reading text that is in the dubbing language already.
      (PipelineNodeIds.recognition || PipelineNodeIds.screen, PipelineNodeIds.voice) =>
        graph.translates ? const TranslationConnection(false) : _passingOver(graph, from),
      _ => const RefusedConnection(ConnectionRefusal.unsupported),
    };

/// The packs a line out of [from] passes over taken out of the line: those
/// after the translator for a line out of it, and those before it for one
/// out of where the line starts.
GraphConnection _passingOver(PipelineGraph graph, String from) {
  final side = from == PipelineNodeIds.translation
      ? GlossaryFeed.translation
      : GlossaryFeed.recognition;
  final passed = {
    for (final node in graph.ofKind(PipelineNodeKind.glossary))
      if (node.feed == side) node.id,
  };
  return passed.isEmpty
      ? const UnchangedConnection()
      : GlossaryLineConnection([LineRemove(passed)]);
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
      // A pack of the glossary taken out of the line of text: the one the
      // line ran into, or else the one it came out of. The text runs past it
      // from what stood before it to what stood after, and the pack is
      // switched off with it. Asked before the translator's lines, which a
      // pack's shares a socket with.
      (_, PipelineSocket.glossaryIn) => GlossaryLineConnection([
        LineRemove({link.to.nodeId}),
      ]),
      (PipelineSocket.glossaryOut, _) => GlossaryLineConnection([
        LineRemove({link.from.nodeId}),
      ]),
      // Either half of the way through the Screen page's detection: the
      // game's sound is no longer listened to, and each line is read in the
      // one voice. Asked before the way into Эфир's pipeline, which leaves
      // the same socket.
      (PipelineSocket.gameAudio, PipelineSocket.detectionIn) ||
      (PipelineSocket.detectedSpeaker, _) => const VoicesConnection(false),
      // The way into the pipeline comes apart: the stages stay where they
      // are with nothing reaching them, and the route is put back by drawing
      // it.
      (PipelineSocket.gameAudio, _) => const RouteConnection(false),
      // Either half of the translator's line takes the whole stage out: the
      // text goes past it, and the dubbing is the English whisper already
      // hands over -- or, on the Screen page, the text read as it is.
      (_, PipelineSocket.translationIn) ||
      (PipelineSocket.translatedText, _) => const TranslationConnection(false),
      // The line that steps over the translator is the only text the voice
      // gets. Cutting it cannot leave the voice with nothing to read, so it
      // means the other thing it can mean: the stage goes back into the line.
      (
        PipelineSocket.speechText || PipelineSocket.screenText,
        PipelineSocket.voiceIn,
      ) =>
        const TranslationConnection(true),
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

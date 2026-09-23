// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// The pipeline as a graph: its world, its nodes and sockets, the links
/// between them and the graph they make.
library;

import 'pipeline_glossary.dart';
import 'pipeline_state.dart';

/// Which of the two schemes a graph draws: the dubbing of the game's sound,
/// the other half of Эфир, or the reading of its screen, the other half of
/// Экран.
///
/// The two share what their sessions share -- the translator, the voice,
/// the mix, the output, the cast and the glossary -- and differ in where the
/// line of text starts: whisper, hearing the game, or the screen, read by
/// Windows OCR. Each has its own arrangement and its own shelf of schemes,
/// and each speaks for the sessions that start from it.
enum PipelineScheme {
  /// Эфир's: the game's sound, recognized by whisper.
  live,

  /// Экран's: the text on the screen, with the game's sound listened to
  /// only to tell who is speaking.
  screen;

  /// The stages this scheme draws, in the order they are laid out.
  List<String> get stages => switch (this) {
    live => PipelineNodeIds.stages,
    screen => PipelineNodeIds.screenStages,
  };

  /// The stage the line of text starts at.
  String get lineHead => switch (this) {
    live => PipelineNodeIds.recognition,
    screen => PipelineNodeIds.screen,
  };

  /// The scheme [session] was started from: the Screen page's session reads
  /// the screen's, and every other the one Эфир draws -- the dubbing, and
  /// the sessions that place or record its voices.
  static PipelineScheme of(PipelineSession session) =>
      session == PipelineSession.screen ? screen : live;

  /// Whether [session] -- none while the engine rests -- started from this
  /// scheme, and so is told what changes on it while it runs.
  bool feeds(PipelineSession? session) => session != null && of(session) == this;
}

/// How far the scheme may spread from the corner it starts in.
///
/// The canvas lays a box this size under the nodes, because a widget drawn
/// outside its parent is painted but not hit: the nodes at the far end of
/// the pipeline could be seen and dragged and never clicked. Nodes are held
/// inside it for the same reason — one moved out of it would be lost to the
/// pointer.
abstract final class GraphWorld {
  static const width = 6000.0;
  static const height = 4000.0;

  /// [point] held inside the world, with room for the node that sits there.
  static GraphPoint hold(GraphPoint point) => GraphPoint(
    point.x.clamp(0.0, width - 400),
    point.y.clamp(0.0, height - 300),
  );
}

/// A place on the canvas. The domain keeps its own point so it owes nothing
/// to Flutter; the canvas converts at its edge.
class GraphPoint {
  const GraphPoint(this.x, this.y);

  static const zero = GraphPoint(0, 0);

  final double x;
  final double y;

  GraphPoint translate(double dx, double dy) => GraphPoint(x + dx, y + dy);

  Map<String, Object?> toJson() => {'x': x, 'y': y};

  static GraphPoint? fromJson(Object? json) => switch (json) {
    {'x': final num x, 'y': final num y} => GraphPoint(x.toDouble(), y.toDouble()),
    _ => null,
  };

  @override
  bool operator ==(Object other) => other is GraphPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'GraphPoint($x, $y)';
}

/// What travels along a link. Two sockets only join when they carry the
/// same thing: sound, text, a voice of the cast, or who is speaking as a
/// line of the screen appears.
enum PipelineSignal { audio, text, voice, speaker }

/// The kinds of node the canvas holds: the stages of the pipeline, a card
/// from the player's cast, and a pack of their glossary. The screen and the
/// character detection are the Screen page's own stages; whisper is only
/// Эфир's.
enum PipelineNodeKind {
  source,
  recognition,
  translation,
  voice,
  mix,
  output,
  character,
  glossary,
  screen,
  detection,
}

/// Where a link may be attached.
///
/// Every socket knows which node it belongs to, what it carries and which
/// way it faces, so the rules below are spelled out once rather than at
/// every place a link is drawn.
enum PipelineSocket {
  /// The game's sound, as the capture hears it.
  gameAudio(PipelineNodeKind.source, PipelineSignal.audio, false),

  /// The text on the screen, as Windows OCR reads it out of the subtitle
  /// frame or out of an area picked with the key.
  screenText(PipelineNodeKind.screen, PipelineSignal.text, false),

  /// The game's sound again, of which nothing is recognized here: the
  /// voices in it are only told apart.
  detectionIn(PipelineNodeKind.detection, PipelineSignal.audio, true),

  /// Who was speaking as a line of the screen appeared.
  detectedSpeaker(PipelineNodeKind.detection, PipelineSignal.speaker, false),

  speechIn(PipelineNodeKind.recognition, PipelineSignal.audio, true),
  speechText(PipelineNodeKind.recognition, PipelineSignal.text, false),
  translationIn(PipelineNodeKind.translation, PipelineSignal.text, true),
  translatedText(PipelineNodeKind.translation, PipelineSignal.text, false),
  voiceIn(PipelineNodeKind.voice, PipelineSignal.text, true),
  voiceAudio(PipelineNodeKind.voice, PipelineSignal.audio, false),

  /// The cast the dubbing reads: a dashed line to every card the game
  /// itself may speak.
  voiceCast(PipelineNodeKind.voice, PipelineSignal.voice, false),

  /// Who was speaking as the line appeared, so it is read in their voice.
  /// Only the Screen page's voice has it: on Эфир whisper and the voices
  /// behind it are heard in the same sound, and nothing is drawn between.
  voiceSpeaker(
    PipelineNodeKind.voice,
    PipelineSignal.speaker,
    true,
    only: PipelineScheme.screen,
  ),

  mixIn(PipelineNodeKind.mix, PipelineSignal.audio, true),

  /// Every voice the scheduler puts in order, the cast's included. It takes
  /// as many links as there are cards on the canvas.
  mixCast(PipelineNodeKind.mix, PipelineSignal.voice, true),
  mixOut(PipelineNodeKind.mix, PipelineSignal.audio, false),
  streamIn(PipelineNodeKind.output, PipelineSignal.audio, true),

  /// The card itself, as the dubbing hears it in the game. It is the one
  /// socket that says nothing about the route: a card whose character is
  /// never spoken by the game — one put on the canvas only to lend its
  /// voice — leaves it empty, and cutting the line changes no setting.
  characterIn(PipelineNodeKind.character, PipelineSignal.voice, true),

  /// The parts this card speaks besides its own: a line arriving here is
  /// another character whose lines this one takes over. Nothing has to
  /// arrive — a card that stands in for nobody speaks only itself — and
  /// several may, one voice being able to take more than one part.
  readBy(PipelineNodeKind.character, PipelineSignal.voice, true),

  /// Where this character's lines leave for: into the mix, spoken by this
  /// card itself, or into another card, which speaks them in its place.
  characterVoice(PipelineNodeKind.character, PipelineSignal.voice, false),

  /// The text a pack of the glossary puts right, from whatever stands
  /// before it in the line: whisper, the translator or another pack. Before
  /// the translator its phrases answer a whole line; after it, its names and
  /// words are put right.
  glossaryIn(PipelineNodeKind.glossary, PipelineSignal.text, true),

  /// The same text, put right, on to whatever stands after it: another
  /// pack, the translator or the voice.
  glossaryOut(PipelineNodeKind.glossary, PipelineSignal.text, false);

  const PipelineSocket(this.owner, this.signal, this.isInput, {this.only});

  final PipelineNodeKind owner;
  final PipelineSignal signal;
  final bool isInput;

  /// The one scheme a node carries this socket on, or null for both.
  final PipelineScheme? only;

  bool get isOutput => !isInput;

  /// Whether a node of [owner] carries this socket on [scheme].
  bool drawnOn(PipelineScheme scheme) => only == null || only == scheme;
}

/// The fixed node ids. A stage is one of a kind, so it is named rather than
/// numbered; a character node carries the id of the card it draws.
abstract final class PipelineNodeIds {
  static const source = 'source';
  static const recognition = 'recognition';
  static const translation = 'translation';
  static const voice = 'voice';
  static const mix = 'mix';
  static const output = 'output';

  /// The Screen page's own stages: where its text is read, and where the
  /// voice behind a line is told apart.
  static const screen = 'screen';
  static const detection = 'detection';

  static const characterPrefix = 'character:';

  /// What tells the second drawing of a card from the first.
  static const copyMark = '#';

  static String character(String characterId) => '$characterPrefix$characterId';

  /// The [copy]th drawing of a card. The first keeps the plain name, so an
  /// arrangement written before a card could be drawn twice still finds the
  /// node its positions are filed under.
  static String characterCopy(String characterId, int copy) =>
      copy <= 1 ? character(characterId) : '${character(characterId)}$copyMark$copy';

  /// The card [nodeId] draws, or null when it is a stage. Every drawing of
  /// a card answers with the same card: which copy it is matters to the
  /// canvas and to nothing else.
  static String? characterOf(String nodeId) {
    if (!nodeId.startsWith(characterPrefix)) return null;
    final name = nodeId.substring(characterPrefix.length);
    final mark = name.lastIndexOf(copyMark);
    if (mark < 0) return name;
    // Only a copy number is cut off: a card whose own id holds a # — one
    // imported from somebody else's file — keeps every letter of it.
    final copy = name.substring(mark + 1);
    return copy.isNotEmpty && int.tryParse(copy) != null ? name.substring(0, mark) : name;
  }

  /// The stages, in the order they are laid out.
  static const stages = [source, recognition, translation, voice, mix, output];

  /// The Screen page's stages: the game's sound and who it says is
  /// speaking, then the line of text from the screen to the output.
  static const screenStages = [source, detection, screen, translation, voice, mix, output];

  static const glossaryPrefix = 'glossary:';

  /// The [number]th drawing of a pack of the glossary. Numbered rather than
  /// named after the pack, which the node's panel may change: the node keeps
  /// its place and its lines while the pack it reads is swapped.
  static String glossary(int number) => '$glossaryPrefix$number';

  static bool isGlossary(String nodeId) => nodeId.startsWith(glossaryPrefix);
}

/// One socket of one node — the end of a link, and what the pointer grabs.
class PipelinePort {
  const PipelinePort(this.nodeId, this.socket);

  final String nodeId;
  final PipelineSocket socket;

  bool get isInput => socket.isInput;
  bool get isOutput => socket.isOutput;

  @override
  bool operator ==(Object other) =>
      other is PipelinePort && other.nodeId == nodeId && other.socket == socket;

  @override
  int get hashCode => Object.hash(nodeId, socket);

  @override
  String toString() => '$nodeId.${socket.name}';
}

/// A link, always drawn from the output it leaves to the input it enters.
class PipelineLink {
  const PipelineLink(this.from, this.to);

  final PipelinePort from;
  final PipelinePort to;

  /// What the link carries, which both ends agree on.
  PipelineSignal get signal => from.socket.signal;

  @override
  bool operator ==(Object other) => other is PipelineLink && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => '$from -> $to';
}

class PipelineNode {
  const PipelineNode({
    required this.id,
    required this.kind,
    required this.position,
    this.characterId,
    this.packId,
    this.feed,
    this.active = true,
    this.unrouted = false,
    this.sendsToMix = false,
    this.scheme = PipelineScheme.live,
  });

  final String id;
  final PipelineNodeKind kind;
  final GraphPoint position;

  /// The scheme the node is drawn on. A stage the two schemes share carries
  /// what its own session does -- the Screen page's voice takes who is
  /// speaking, and its mix reads a line at a time -- so the card and its
  /// panel say that rather than what Эфир's would.
  final PipelineScheme scheme;

  /// The sockets this node carries, in the order they are declared.
  Iterable<PipelineSocket> get sockets =>
      PipelineSocket.values.where((socket) => socket.owner == kind && socket.drawnOn(scheme));

  /// The card this node draws, for [PipelineNodeKind.character].
  final String? characterId;

  /// The pack of the glossary this node draws, for
  /// [PipelineNodeKind.glossary].
  final String? packId;

  /// Which side of the translator that pack stands in the line of text, or
  /// null while it stands out of the line.
  final GlossaryFeed? feed;

  /// Whether that pack is switched on. Switched off, the node stays where it
  /// stands in the line and the text passes through it as it came. For the
  /// character detection, whether the voices behind the screen are told
  /// apart at all.
  final bool active;

  /// Whether nothing reaches this node at all, the way into the pipeline
  /// having been taken apart. It is still drawn where it stood, and a link
  /// dragged back to the source puts the route together again.
  final bool unrouted;

  /// Whether this card's lines leave for the mix rather than for another
  /// card. Only a card that reaches the mix is heard as itself, so the
  /// canvas marks those and leaves the ones that hand their part on.
  final bool sendsToMix;

  /// Two nodes are the same node when everything drawn of them is: the
  /// canvas builds a fresh graph on every frame of a drag, and this is how
  /// it tells the one card that moved from the rest that did not.
  @override
  bool operator ==(Object other) =>
      other is PipelineNode &&
      other.id == id &&
      other.kind == kind &&
      other.position == position &&
      other.characterId == characterId &&
      other.packId == packId &&
      other.feed == feed &&
      other.active == active &&
      other.unrouted == unrouted &&
      other.sendsToMix == sendsToMix &&
      other.scheme == scheme;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    position,
    characterId,
    packId,
    feed,
    active,
    unrouted,
    sendsToMix,
    scheme,
  );
}

/// The whole scheme: the nodes and the links between them.
class PipelineGraph {
  const PipelineGraph({
    this.nodes = const [],
    this.links = const [],
    this.routed = true,
    this.translates = true,
    this.chained = const {},
    this.scheme = PipelineScheme.live,
  });

  final List<PipelineNode> nodes;
  final List<PipelineLink> links;

  /// Whether the way into the pipeline is drawn at all. Taken apart, every
  /// stage is unrouted and the session cannot start. The screen is always
  /// read, so the Screen page's scheme is always routed.
  final bool routed;

  /// Whether the translator stands in the line of text. Stepped over, it
  /// stands aside with the packs drawn after it, and the text runs from
  /// whisper -- or from the screen -- to the voice.
  final bool translates;

  /// Which of the two schemes this is.
  final PipelineScheme scheme;

  /// Cards read by a card that is itself read by a third. The substitution
  /// is followed one hop only, so these keep their reader's own voice and
  /// the canvas says so.
  final Set<String> chained;

  PipelineNode? node(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  /// The link entering [port], if one does. Only inputs are asked: an
  /// output may feed several nodes.
  PipelineLink? linkInto(PipelinePort port) {
    for (final link in links) {
      if (link.to == port) return link;
    }
    return null;
  }

  List<PipelineNode> ofKind(PipelineNodeKind kind) => [
    for (final node in nodes)
      if (node.kind == kind) node,
  ];
}

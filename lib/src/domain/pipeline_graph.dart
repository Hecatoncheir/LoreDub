// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// The pipeline drawn as nodes, and the rules for rewiring it.
///
/// The graph is not a second copy of the configuration: it is built from
/// [AppSettings] and the player's cast every time either changes, and every
/// edit is turned back into a change to one of them. What the engine can
/// actually run is therefore what can be drawn — a link the pipeline has no
/// answer for is refused with a reason rather than saved and ignored.
library;

import 'app_settings.dart';
import 'character.dart';

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
/// same thing.
enum PipelineSignal { audio, text, voice }

/// The kinds of node the canvas holds: the six stages of the pipeline, and
/// a card from the player's cast.
enum PipelineNodeKind { source, recognition, translation, voice, mix, output, character }

/// Where a link may be attached.
///
/// Every socket knows which node it belongs to, what it carries and which
/// way it faces, so the rules below are spelled out once rather than at
/// every place a link is drawn.
enum PipelineSocket {
  /// The game's sound, as the capture hears it.
  gameAudio(PipelineNodeKind.source, PipelineSignal.audio, false),

  /// The text on the screen, as Windows OCR reads it.
  screenText(PipelineNodeKind.source, PipelineSignal.text, false),
  speechIn(PipelineNodeKind.recognition, PipelineSignal.audio, true),
  speechText(PipelineNodeKind.recognition, PipelineSignal.text, false),
  translationIn(PipelineNodeKind.translation, PipelineSignal.text, true),
  translatedText(PipelineNodeKind.translation, PipelineSignal.text, false),
  voiceIn(PipelineNodeKind.voice, PipelineSignal.text, true),
  voiceAudio(PipelineNodeKind.voice, PipelineSignal.audio, false),

  /// The voice the pipeline reads a character in while nobody replaces them.
  voiceCast(PipelineNodeKind.voice, PipelineSignal.voice, false),
  mixIn(PipelineNodeKind.mix, PipelineSignal.audio, true),

  /// Every voice the scheduler puts in order, the cast's included. It takes
  /// as many links as there are cards on the canvas.
  mixCast(PipelineNodeKind.mix, PipelineSignal.voice, true),
  mixOut(PipelineNodeKind.mix, PipelineSignal.audio, false),
  streamIn(PipelineNodeKind.output, PipelineSignal.audio, true),

  /// Whose voice this character is read in. One link only: a card is read
  /// by the pipeline or by one other card, never by two.
  readBy(PipelineNodeKind.character, PipelineSignal.voice, true),
  characterVoice(PipelineNodeKind.character, PipelineSignal.voice, false);

  const PipelineSocket(this.owner, this.signal, this.isInput);

  final PipelineNodeKind owner;
  final PipelineSignal signal;
  final bool isInput;

  bool get isOutput => !isInput;
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

  static const characterPrefix = 'character:';

  static String character(String characterId) => '$characterPrefix$characterId';

  /// The card [nodeId] draws, or null when it is a stage.
  static String? characterOf(String nodeId) =>
      nodeId.startsWith(characterPrefix) ? nodeId.substring(characterPrefix.length) : null;

  /// The stages, in the order they are laid out.
  static const stages = [source, recognition, translation, voice, mix, output];
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
    this.bypassed = false,
    this.unrouted = false,
  });

  final String id;
  final PipelineNodeKind kind;
  final GraphPoint position;

  /// The card this node draws, for [PipelineNodeKind.character].
  final String? characterId;

  /// Whether the running pipeline goes past this node: recognition, while
  /// the subtitles are being read off the screen. It is still drawn, so the
  /// route can be put back by dragging one link.
  final bool bypassed;

  /// Whether nothing reaches this node at all, the way into the pipeline
  /// having been taken apart. A bypassed node is one the running route goes
  /// past; an unrouted one belongs to a pipeline that runs nothing. It is
  /// still drawn where it stood, and a link dragged back to the source puts
  /// the route together again.
  final bool unrouted;
}

/// The whole scheme: the nodes, the links between them, and the route the
/// engine will take through it.
class PipelineGraph {
  const PipelineGraph({
    this.nodes = const [],
    this.links = const [],
    this.route = CaptureMode.audio,
    this.routed = true,
    this.chained = const {},
  });

  final List<PipelineNode> nodes;
  final List<PipelineLink> links;

  /// Which of the two routes the links describe — the same value the engine
  /// is started with. Meaningless while [routed] is false: it is only what
  /// the route would be if it were drawn back.
  final CaptureMode route;

  /// Whether the way into the pipeline is drawn at all. Taken apart, every
  /// stage is unrouted and the session cannot start.
  final bool routed;

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

/// Where the nodes sit, which cards were put on the canvas, and where the
/// canvas itself is. This is all that is kept on disk: everything else is
/// derived from the settings and the cast.
class PipelineLayout {
  const PipelineLayout({
    this.positions = const {},
    this.characters = const [],
    this.view = const GraphView(),
  });

  /// What a canvas that was never arranged looks like.
  static const standard = PipelineLayout(positions: standardPositions);

  static const standardPositions = {
    PipelineNodeIds.source: GraphPoint(40, 220),
    PipelineNodeIds.recognition: GraphPoint(325, 40),
    PipelineNodeIds.translation: GraphPoint(610, 220),
    PipelineNodeIds.voice: GraphPoint(895, 220),
    PipelineNodeIds.mix: GraphPoint(1180, 220),
    PipelineNodeIds.output: GraphPoint(1465, 220),
  };

  /// Where the first character node is put, and how the rest follow: in a
  /// row under the pipeline and to the left of the mix they feed, so both
  /// the substitution between two cards and the voice each of them sends on
  /// run the way the signal does.
  static const castOrigin = GraphPoint(620, 520);
  static const castStep = 260.0;
  static const castRowStep = 170.0;

  /// How many cards a row holds before the next one starts.
  static const castRow = 3;

  /// Where the [index]th card goes when nobody has moved it.
  static GraphPoint castPlace(int index) => castOrigin.translate(
    (index % castRow) * castStep,
    (index ~/ castRow) * castRowStep,
  );

  final Map<String, GraphPoint> positions;

  /// The cards the player put on the canvas, in the order they were placed.
  /// A card that reads another, or is read by one, is drawn whether or not
  /// it is listed here: a substitution nobody can see is a trap.
  final List<String> characters;
  final GraphView view;

  PipelineLayout copyWith({
    Map<String, GraphPoint>? positions,
    List<String>? characters,
    GraphView? view,
  }) => PipelineLayout(
    positions: positions ?? this.positions,
    characters: characters ?? this.characters,
    view: view ?? this.view,
  );

  PipelineLayout withPosition(String nodeId, GraphPoint at) =>
      copyWith(positions: {...positions, nodeId: at});

  PipelineLayout withCharacter(String characterId) =>
      characters.contains(characterId) ? this : copyWith(characters: [...characters, characterId]);

  PipelineLayout withoutCharacter(String characterId) => copyWith(
    characters: [
      for (final id in characters)
        if (id != characterId) id,
    ],
    positions: {
      for (final entry in positions.entries)
        if (entry.key != PipelineNodeIds.character(characterId)) entry.key: entry.value,
    },
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'nodes': {for (final entry in positions.entries) entry.key: entry.value.toJson()},
    'characters': characters,
    'view': view.toJson(),
  };

  /// The layout in [json], or the standard arrangement when the file is
  /// missing, damaged, or written by a version that put other things in it.
  static PipelineLayout fromJson(Object? json) {
    if (json is! Map<String, Object?>) return standard;
    final nodes = json['nodes'];
    final positions = <String, GraphPoint>{};
    if (nodes is Map<String, Object?>) {
      for (final entry in nodes.entries) {
        if (GraphPoint.fromJson(entry.value) case final point?) positions[entry.key] = point;
      }
    }
    return PipelineLayout(
      positions: positions.isEmpty ? standardPositions : positions,
      characters: [
        for (final value in json['characters'] as List<Object?>? ?? const [])
          if (value is String) value,
      ],
      view: GraphView.fromJson(json['view']),
    );
  }
}

/// Where the canvas is looked at from.
class GraphView {
  const GraphView({this.x = 0, this.y = 0, this.zoom = 1, this.placed = false});

  /// How far in and out the wheel goes. Below the smaller value the labels
  /// stop being readable; above the larger one a node fills the screen.
  static const smallestZoom = 0.4;
  static const largestZoom = 1.6;

  final double x;
  final double y;
  final double zoom;

  /// Whether the scheme has been put in the window — by the canvas, which
  /// fits it there when it is first drawn, or by the player since. A canvas
  /// laid out again is unplaced, and is fitted afresh.
  final bool placed;

  GraphView panned(double dx, double dy) =>
      GraphView(x: x + dx, y: y + dy, zoom: zoom, placed: true);

  /// Zoomed to [value] around [focus], a point on the screen: whatever is
  /// under the pointer stays under it.
  GraphView zoomedAt(double value, GraphPoint focus) {
    final next = value.clamp(smallestZoom, largestZoom);
    final scale = next / zoom;
    return GraphView(
      x: focus.x - (focus.x - x) * scale,
      y: focus.y - (focus.y - y) * scale,
      zoom: next,
      placed: true,
    );
  }

  /// [point] on the screen, as a place on the canvas.
  GraphPoint toCanvas(GraphPoint point) => GraphPoint((point.x - x) / zoom, (point.y - y) / zoom);

  Map<String, Object?> toJson() => {'x': x, 'y': y, 'zoom': zoom, 'placed': placed};

  static GraphView fromJson(Object? json) => switch (json) {
    {'x': final num x, 'y': final num y, 'zoom': final num zoom} => GraphView(
      x: x.toDouble(),
      y: y.toDouble(),
      zoom: zoom.toDouble().clamp(smallestZoom, largestZoom),
      // A file from before the canvas fitted itself has been looked at, so
      // it is left where its author left it.
      placed: switch (json) {
        {'placed': final bool placed} => placed,
        _ => true,
      },
    ),
    _ => const GraphView(),
  };
}

/// The arrangements the canvas is offered as a starting point. Each one is a
/// route the engine runs, not a shape of its own.
enum PipelinePreset {
  /// Sound from the game, recognized, translated and read out.
  audioDub(CaptureMode.audio),

  /// Text read off the screen, translated and read out; whisper takes no
  /// part in it.
  subtitles(CaptureMode.ocr);

  const PipelinePreset(this.captureMode);

  final CaptureMode captureMode;

  /// The preset [mode] is running, so the canvas can show which one is on.
  static PipelinePreset of(CaptureMode mode) =>
      mode == CaptureMode.ocr ? PipelinePreset.subtitles : PipelinePreset.audioDub;
}

/// The graph [settings] and [characters] describe, arranged as [layout].
PipelineGraph buildPipelineGraph({
  required AppSettings settings,
  required List<Character> characters,
  PipelineLayout layout = PipelineLayout.standard,
}) {
  final byId = {for (final character in characters) character.id: character};
  final placed = _placedCharacters(layout.characters, byId);
  GraphPoint at(String nodeId, GraphPoint fallback) => layout.positions[nodeId] ?? fallback;

  final ocr = settings.captureMode == CaptureMode.ocr;
  final routed = settings.captureRouted;
  final nodes = <PipelineNode>[
    for (final id in PipelineNodeIds.stages)
      PipelineNode(
        id: id,
        kind: switch (id) {
          PipelineNodeIds.source => PipelineNodeKind.source,
          PipelineNodeIds.recognition => PipelineNodeKind.recognition,
          PipelineNodeIds.translation => PipelineNodeKind.translation,
          PipelineNodeIds.voice => PipelineNodeKind.voice,
          PipelineNodeIds.mix => PipelineNodeKind.mix,
          _ => PipelineNodeKind.output,
        },
        position: at(id, PipelineLayout.standardPositions[id] ?? GraphPoint.zero),
        bypassed: routed && ocr && id == PipelineNodeIds.recognition,
        unrouted: !routed,
      ),
    for (final (index, id) in placed.indexed)
      PipelineNode(
        id: PipelineNodeIds.character(id),
        kind: PipelineNodeKind.character,
        characterId: id,
        position: at(PipelineNodeIds.character(id), PipelineLayout.castPlace(index)),
      ),
  ];

  const translation = PipelinePort(PipelineNodeIds.translation, PipelineSocket.translationIn);
  final links = <PipelineLink>[
    // Nothing feeds the stages while the way in is taken apart. What runs
    // between them is the pipeline itself and stays drawn, faded with them.
    if (!routed)
      ...const <PipelineLink>[]
    else if (ocr)
      const PipelineLink(
        PipelinePort(PipelineNodeIds.source, PipelineSocket.screenText),
        translation,
      )
    else ...[
      const PipelineLink(
        PipelinePort(PipelineNodeIds.source, PipelineSocket.gameAudio),
        PipelinePort(PipelineNodeIds.recognition, PipelineSocket.speechIn),
      ),
      const PipelineLink(
        PipelinePort(PipelineNodeIds.recognition, PipelineSocket.speechText),
        translation,
      ),
    ],
    const PipelineLink(
      PipelinePort(PipelineNodeIds.translation, PipelineSocket.translatedText),
      PipelinePort(PipelineNodeIds.voice, PipelineSocket.voiceIn),
    ),
    const PipelineLink(
      PipelinePort(PipelineNodeIds.voice, PipelineSocket.voiceAudio),
      PipelinePort(PipelineNodeIds.mix, PipelineSocket.mixIn),
    ),
    const PipelineLink(
      PipelinePort(PipelineNodeIds.mix, PipelineSocket.mixOut),
      PipelinePort(PipelineNodeIds.output, PipelineSocket.streamIn),
    ),
    // Every card sends its lines on to be put in order with the rest, which
    // is why a character on the canvas is part of the path rather than an
    // island beside it.
    for (final id in placed)
      PipelineLink(
        PipelinePort(PipelineNodeIds.character(id), PipelineSocket.characterVoice),
        const PipelinePort(PipelineNodeIds.mix, PipelineSocket.mixCast),
      ),
    for (final id in placed)
      PipelineLink(
        switch (byId[id]?.voicedBy) {
          final reader? when placed.contains(reader) => PipelinePort(
            PipelineNodeIds.character(reader),
            PipelineSocket.characterVoice,
          ),
          _ => const PipelinePort(PipelineNodeIds.voice, PipelineSocket.voiceCast),
        },
        PipelinePort(PipelineNodeIds.character(id), PipelineSocket.readBy),
      ),
  ];

  return PipelineGraph(
    nodes: nodes,
    links: links,
    route: settings.captureMode,
    routed: routed,
    chained: {
      for (final id in placed)
        if (byId[byId[id]?.voicedBy]?.voicedBy != null) id,
    },
  );
}

/// The cards the canvas draws: the ones the player put there, plus everyone
/// a substitution names. A card given away with its reader out of sight
/// would read as a card nobody replaced.
List<String> _placedCharacters(List<String> placed, Map<String, Character> byId) {
  final drawn = [
    for (final id in placed)
      if (byId.containsKey(id)) id,
  ];
  for (final id in [...drawn]) {
    final reader = byId[id]?.voicedBy;
    if (reader != null && byId.containsKey(reader) && !drawn.contains(reader)) drawn.add(reader);
  }
  // A card is drawn after the voice that reads it, so the link between them
  // runs the way every other one does: out of the right edge, into the left.
  for (final id in [...drawn]) {
    final reader = byId[id]?.voicedBy;
    if (reader == null) continue;
    final at = drawn.indexOf(reader);
    if (at < 0 || at < drawn.indexOf(id)) continue;
    drawn.removeAt(at);
    drawn.insert(drawn.indexOf(id), reader);
  }
  return drawn;
}

/// Why a link was not made.
enum ConnectionRefusal {
  /// The two ends carry different things — text into an audio input.
  signal,

  /// Two outputs, or two inputs.
  direction,

  /// Both ends on the same node.
  sameNode,

  /// A pair the engine has no route for, such as the screen's text straight
  /// into the voice.
  unsupported,

  /// Two cards reading each other.
  loop,

  /// The route cannot be changed while a session is running: the models are
  /// loaded for the one it started with. Whose voice reads whom still can.
  locked,
}

/// What making a link would change. The canvas asks before it draws, and
/// applies the answer to the settings or to the cast.
sealed class GraphConnection {
  const GraphConnection();
}

/// The capture route, which is where the pipeline starts.
final class RouteConnection extends GraphConnection {
  const RouteConnection(this.mode);

  /// Which way the pipeline is fed, or null when the way in has been taken
  /// apart: the mode last used is remembered, and drawing a link back is
  /// what picks it up again.
  final CaptureMode? mode;
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
    (PipelineSocket.gameAudio, PipelineSocket.speechIn) => const RouteConnection(CaptureMode.audio),
    (PipelineSocket.screenText, PipelineSocket.translationIn) => const RouteConnection(
      CaptureMode.ocr,
    ),
    (PipelineSocket.voiceCast, PipelineSocket.readBy) => ReaderConnection(
      PipelineNodeIds.characterOf(to.nodeId) ?? '',
      null,
    ),
    (PipelineSocket.characterVoice, PipelineSocket.readBy) => _readerConnection(
      reader: PipelineNodeIds.characterOf(from.nodeId) ?? '',
      character: PipelineNodeIds.characterOf(to.nodeId) ?? '',
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
  for (final known in characters) {
    // Two cards reading each other would leave neither a voice to start from.
    if (known.id == reader && known.voicedBy == character) {
      return const RefusedConnection(ConnectionRefusal.loop);
    }
  }
  return ReaderConnection(character, reader);
}

/// What cutting [link] would mean. Only a substitution can be cut: the route
/// is always whole, and is changed by drawing the other one instead.
GraphConnection proposeDisconnect(PipelineLink link) {
  // The way into the pipeline comes apart: the stages stay where they are
  // with nothing reaching them, and the route is put back by drawing it.
  if (link.from.socket == PipelineSocket.gameAudio ||
      link.from.socket == PipelineSocket.screenText) {
    return const RouteConnection(null);
  }
  if (link.to.socket != PipelineSocket.readBy ||
      link.from.socket != PipelineSocket.characterVoice) {
    return const RefusedConnection(ConnectionRefusal.unsupported);
  }
  return ReaderConnection(PipelineNodeIds.characterOf(link.to.nodeId) ?? '', null);
}

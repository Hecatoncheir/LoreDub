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

  speechIn(PipelineNodeKind.recognition, PipelineSignal.audio, true),
  speechText(PipelineNodeKind.recognition, PipelineSignal.text, false),
  translationIn(PipelineNodeKind.translation, PipelineSignal.text, true),
  translatedText(PipelineNodeKind.translation, PipelineSignal.text, false),
  voiceIn(PipelineNodeKind.voice, PipelineSignal.text, true),
  voiceAudio(PipelineNodeKind.voice, PipelineSignal.audio, false),

  /// The cast the dubbing reads: a dashed line to every card the game
  /// itself may speak.
  voiceCast(PipelineNodeKind.voice, PipelineSignal.voice, false),

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
    this.unrouted = false,
    this.sendsToMix = false,
  });

  final String id;
  final PipelineNodeKind kind;
  final GraphPoint position;

  /// The card this node draws, for [PipelineNodeKind.character].
  final String? characterId;

  /// Whether nothing reaches this node at all, the way into the pipeline
  /// having been taken apart. It is still drawn where it stood, and a link
  /// dragged back to the source puts the route together again.
  final bool unrouted;

  /// Whether this card's lines leave for the mix rather than for another
  /// card. Only a card that reaches the mix is heard as itself, so the
  /// canvas marks those and leaves the ones that hand their part on.
  final bool sendsToMix;
}

/// The whole scheme: the nodes and the links between them.
class PipelineGraph {
  const PipelineGraph({
    this.nodes = const [],
    this.links = const [],
    this.routed = true,
    this.chained = const {},
  });

  final List<PipelineNode> nodes;
  final List<PipelineLink> links;

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

/// One drawing of a card on the canvas.
///
/// A card may be drawn more than once: once among the voices the game
/// speaks, again beside the character whose part it takes over, so the line
/// between them is a hand's breadth rather than the width of the scheme.
/// The copies are the same card — whose voice reads whom belongs to the
/// character and not to the drawing — so what a copy carries of its own is
/// only where it sits and whether the game is expected to speak it here.
class CastPlacement {
  const CastPlacement({required this.nodeId, required this.characterId, this.heard = true});

  /// The first drawing of [characterId], under the node name an arrangement
  /// from before copies already uses.
  factory CastPlacement.of(String characterId, {bool heard = true}) => CastPlacement(
    nodeId: PipelineNodeIds.character(characterId),
    characterId: characterId,
    heard: heard,
  );

  final String nodeId;
  final String characterId;

  /// Whether the game's own dialogue is expected to hold this character —
  /// the dashed line from the voice node. It says no more than that: the
  /// worker matches every line against the whole cast whatever the canvas
  /// shows. A card drawn only to lend its voice has none, and neither does
  /// a second copy, which is there to take a part rather than to speak one.
  final bool heard;

  CastPlacement copyWith({bool? heard}) =>
      CastPlacement(nodeId: nodeId, characterId: characterId, heard: heard ?? this.heard);

  Map<String, Object?> toJson() => {'node': nodeId, 'character': characterId, 'heard': heard};

  static CastPlacement? fromJson(Object? json) => switch (json) {
    {'node': final String node, 'character': final String character} => CastPlacement(
      nodeId: node,
      characterId: character,
      heard: switch (json) {
        {'heard': final bool heard} => heard,
        _ => true,
      },
    ),
    // A file from before a card could be drawn twice lists the cards by id.
    final String character => CastPlacement.of(character),
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is CastPlacement &&
      other.nodeId == nodeId &&
      other.characterId == characterId &&
      other.heard == heard;

  @override
  int get hashCode => Object.hash(nodeId, characterId, heard);

  @override
  String toString() => 'CastPlacement($nodeId${heard ? '' : ', unheard'})';
}

/// Where the nodes sit, which cards were put on the canvas, and where the
/// canvas itself is. This is all that is kept on disk: everything else is
/// derived from the settings and the cast.
class PipelineLayout {
  const PipelineLayout({
    this.positions = const {},
    this.cast = const [],
    this.view = const GraphView(),
    this.silent = const {},
  });

  /// The arrangement a list of cards describes, each drawn once.
  factory PipelineLayout.drawing(
    List<String> characters, {
    Map<String, GraphPoint> positions = const {},
    GraphView view = const GraphView(),
  }) => PipelineLayout(
    positions: positions,
    cast: [for (final id in characters) CastPlacement.of(id)],
    view: view,
  );

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

  /// The cards the player drew on the canvas, in the order they drew them.
  /// A card may appear more than once; a card that reads another, or is
  /// read by one, is still drawn only where it was put, and the face of it
  /// says who reads it, so no substitution goes unsaid.
  final List<CastPlacement> cast;
  final GraphView view;

  /// The cards on the canvas whose voice is cut out of the mix.
  ///
  /// Such a card is drawn where it was put and reads for nobody: it lends
  /// its voice to no character, nobody stands in for it, and a session is
  /// told to leave it as it is heard. It is held by character rather than by
  /// drawing, the mix being told a character once however many times it is
  /// drawn. A card that is not on the canvas at all is never in here: the
  /// cast the player left off the scheme reads the way it always did.
  final Set<String> silent;

  /// The cards on the canvas, one entry per drawing of one.
  List<String> get characters => [for (final placement in cast) placement.characterId];

  PipelineLayout copyWith({
    Map<String, GraphPoint>? positions,
    List<CastPlacement>? cast,
    GraphView? view,
    Set<String>? silent,
  }) => PipelineLayout(
    positions: positions ?? this.positions,
    cast: cast ?? this.cast,
    view: view ?? this.view,
    silent: silent ?? this.silent,
  );

  PipelineLayout withPosition(String nodeId, GraphPoint at) =>
      copyWith(positions: {...positions, nodeId: at});

  /// Another drawing of [characterId], under a node name none of its other
  /// drawings answers to.
  ///
  /// The first copy is one of the game's voices and carries the dashed line
  /// that says so; the ones after it are drawn to take a part over, so they
  /// start without it and the mix is not told the same character twice.
  PipelineLayout withCharacter(String characterId) {
    final taken = {for (final placement in cast) placement.nodeId};
    var copy = 1;
    while (taken.contains(PipelineNodeIds.characterCopy(characterId, copy))) {
      copy++;
    }
    return copyWith(
      cast: [
        ...cast,
        CastPlacement(
          nodeId: PipelineNodeIds.characterCopy(characterId, copy),
          characterId: characterId,
          heard: copy == 1,
        ),
      ],
    );
  }

  /// One drawing taken off the canvas. The card itself, and whoever reads
  /// it, are untouched: only this copy of it goes.
  ///
  /// A card that was cut out of the mix and is now off the canvas altogether
  /// is not cut any more: the cut is a line on the scheme, and a card the
  /// scheme does not draw reads the way it always did.
  PipelineLayout withoutNode(String nodeId) {
    final left = [
      for (final placement in cast)
        if (placement.nodeId != nodeId) placement,
    ];
    final drawn = {for (final placement in left) placement.characterId};
    return copyWith(
      cast: left,
      positions: {
        for (final entry in positions.entries)
          if (entry.key != nodeId) entry.key: entry.value,
      },
      silent: {
        for (final id in silent)
          if (drawn.contains(id)) id,
      },
    );
  }

  /// Whether the voice of [characterId] reaches the mix. Every drawing of
  /// the card answers together: the mix is told a character once.
  PipelineLayout withVoiced(String characterId, bool voiced) => copyWith(
    silent: {
      for (final id in silent)
        if (id != characterId) id,
      if (!voiced) characterId,
    },
  );

  /// Whether the game is expected to speak the card drawn at [nodeId].
  PipelineLayout withHeard(String nodeId, bool heard) => copyWith(
    cast: [
      for (final placement in cast)
        if (placement.nodeId == nodeId) placement.copyWith(heard: heard) else placement,
    ],
  );

  Map<String, Object?> toJson() => {
    'version': 3,
    'nodes': {for (final entry in positions.entries) entry.key: entry.value.toJson()},
    'cast': [for (final placement in cast) placement.toJson()],
    'view': view.toJson(),
    // Sorted so the file is the same file when nothing was changed.
    'silent': [...silent]..sort(),
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
    // Version 1 listed the cards by id under `characters`, each drawn once.
    final cast = json['cast'] ?? json['characters'];
    return PipelineLayout(
      positions: positions.isEmpty ? standardPositions : positions,
      cast: [
        for (final value in cast as List<Object?>? ?? const []) ?CastPlacement.fromJson(value),
      ],
      view: GraphView.fromJson(json['view']),
      // Version 2 and before had one switch for the whole cast, which lived
      // in the settings rather than here: a file from then names nobody.
      silent: {
        for (final value in json['silent'] as List<Object?>? ?? const [])
          if (value is String) value,
      },
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

/// The graph [settings] and [characters] describe, arranged as [layout].
PipelineGraph buildPipelineGraph({
  required AppSettings settings,
  required List<Character> characters,
  PipelineLayout layout = PipelineLayout.standard,
}) {
  final byId = {for (final character in characters) character.id: character};
  final placed = _placedCast(layout.cast, byId);
  GraphPoint at(String nodeId, GraphPoint fallback) => layout.positions[nodeId] ?? fallback;

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
        unrouted: !routed,
      ),
    for (final (index, placement) in placed.indexed)
      PipelineNode(
        id: placement.nodeId,
        kind: PipelineNodeKind.character,
        characterId: placement.characterId,
        position: at(placement.nodeId, PipelineLayout.castPlace(index)),
        unrouted: layout.silent.contains(placement.characterId),
      ),
  ];
  // A card cut out of the mix takes no part in the arrangement: it is drawn
  // where it stands and nothing runs through it, so the lines are worked out
  // over the rest. A card it used to read then speaks for itself, which is
  // what falls out of looking for its reader among these.
  final voiced = [
    for (final placement in placed)
      if (!layout.silent.contains(placement.characterId)) placement,
  ];
  final where = {for (final node in nodes) node.id: node.position};
  final sends = {
    for (final placement in voiced) placement.nodeId: _partOf(placement, byId, voiced, where),
  };
  final carrying = _carrying(voiced, byId, sends);
  // A card whose line ends at the mix is heard as itself; one that hands
  // its part to another card is not, and the canvas draws the two apart.
  for (var index = 0; index < nodes.length; index++) {
    final node = nodes[index];
    if (node.kind != PipelineNodeKind.character) continue;
    if (!carrying.contains(node.id)) continue;
    if (sends[node.id]?.nodeId != PipelineNodeIds.mix) continue;
    nodes[index] = PipelineNode(
      id: node.id,
      kind: node.kind,
      position: node.position,
      characterId: node.characterId,
      unrouted: node.unrouted,
      sendsToMix: true,
    );
  }

  const translation = PipelinePort(PipelineNodeIds.translation, PipelineSocket.translationIn);
  final links = <PipelineLink>[
    // Nothing feeds the stages while the way in is taken apart. What runs
    // between them is the pipeline itself and stays drawn, faded with them.
    if (routed) ...[
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
    // A note rather than a route: the dashed line says the game's own
    // dialogue may hold this character. A card drawn only to lend its
    // voice carries none, and the pipeline runs the same either way.
    for (final placement in voiced)
      if (placement.heard)
        PipelineLink(
          const PipelinePort(PipelineNodeIds.voice, PipelineSocket.voiceCast),
          PipelinePort(placement.nodeId, PipelineSocket.characterIn),
        ),
    // A card's lines leave it one way only: into the card that speaks for
    // it, which carries them on to the mix, or into the mix itself when it
    // speaks for itself.
    for (final placement in voiced)
      if (carrying.contains(placement.nodeId))
        PipelineLink(
          PipelinePort(placement.nodeId, PipelineSocket.characterVoice),
          sends[placement.nodeId]!,
        ),
  ];

  return PipelineGraph(
    nodes: nodes,
    links: links,
    routed: routed,
    chained: {
      for (final placement in placed)
        if (byId[byId[placement.characterId]?.voicedBy]?.voicedBy != null) placement.characterId,
    },
  );
}

/// Where the part drawn at [from] goes: into the nearest drawing of the card
/// that speaks for it, or into the mix when it speaks for itself.
///
/// The nearest one, because a card is drawn twice precisely so the line has
/// somewhere short to run — the copy the player put beside this one is the
/// copy they meant. A card standing in for another that is nowhere on the
/// canvas sends its part to the mix, and says whose voice reads it on its
/// own face.
PipelinePort _partOf(
  CastPlacement from,
  Map<String, Character> byId,
  List<CastPlacement> placed,
  Map<String, GraphPoint> where,
) {
  const mix = PipelinePort(PipelineNodeIds.mix, PipelineSocket.mixCast);
  final reader = byId[from.characterId]?.voicedBy;
  if (reader == null || reader == from.characterId) return mix;
  CastPlacement? nearest;
  var best = double.infinity;
  final here = where[from.nodeId] ?? GraphPoint.zero;
  for (final placement in placed) {
    if (placement.characterId != reader) continue;
    final there = where[placement.nodeId] ?? GraphPoint.zero;
    final span = (there.x - here.x) * (there.x - here.x) + (there.y - here.y) * (there.y - here.y);
    if (span >= best) continue;
    best = span;
    nearest = placement;
  }
  return nearest == null ? mix : PipelinePort(nearest.nodeId, PipelineSocket.readBy);
}

/// The drawings that have a line to send on.
///
/// A card the game speaks has its own part; a card another's part arrives at
/// carries it on to wherever its own would go; and a card whose character is
/// read by somebody sends its part even when the game never speaks it, since
/// a substitution nobody can see is a trap.
Set<String> _carrying(
  List<CastPlacement> placed,
  Map<String, Character> byId,
  Map<String, PipelinePort> sends,
) {
  final carrying = {
    for (final placement in placed)
      if (placement.heard || byId[placement.characterId]?.voicedBy != null) placement.nodeId,
  };
  // What a card takes over it also passes on, and so may the card after it.
  for (var pass = 0; pass < placed.length; pass++) {
    var grew = false;
    for (final placement in placed) {
      if (!carrying.contains(placement.nodeId)) continue;
      final to = sends[placement.nodeId];
      if (to == null || to.socket != PipelineSocket.readBy) continue;
      if (carrying.add(to.nodeId)) grew = true;
    }
    if (!grew) break;
  }
  return carrying;
}

/// The drawings the canvas keeps: the ones the player put there whose card
/// is still in the cast. A card is taken off the canvas when the player
/// asks, even while another card on it is read in their voice — that line
/// then comes to nothing until they are put back, which is what the empty
/// socket says.
List<CastPlacement> _placedCast(List<CastPlacement> placed, Map<String, Character> byId) {
  final drawn = [
    for (final placement in placed)
      if (byId.containsKey(placement.characterId)) placement,
  ];
  // The card that speaks for another is laid out after it, so a line
  // between two that were never moved runs the way every other one does:
  // out of the right edge of the part, into the left of whoever takes it
  // over.
  for (final placement in [...drawn]) {
    final reader = byId[placement.characterId]?.voicedBy;
    if (reader == null) continue;
    final at = drawn.indexWhere((other) => other.characterId == reader);
    if (at < 0 || at > drawn.indexOf(placement)) continue;
    final moved = drawn.removeAt(at);
    drawn.insert(drawn.indexOf(placement) + 1, moved);
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

  /// A pair the engine has no route for, such as the game's sound straight
  /// into the translator.
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
  const RouteConnection(this.routed);

  /// Whether the game's sound reaches the stages at all. Taken apart, every
  /// stage stands with nothing coming into it until a link is drawn back.
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
GraphConnection proposeDisconnect(PipelineLink link) {
  // The way into the pipeline comes apart: the stages stay where they are
  // with nothing reaching them, and the route is put back by drawing it.
  if (link.from.socket == PipelineSocket.gameAudio) return const RouteConnection(false);
  // One card comes out of the mix: it stays where it was put with nobody
  // standing in for it, and the line drawn back wakes it again. The rest of
  // the cast is not touched -- a scheme is cut a card at a time.
  if (link.to.socket == PipelineSocket.mixCast) {
    return switch (PipelineNodeIds.characterOf(link.from.nodeId)) {
      final character? => CastConnection(character, link.from.nodeId, false),
      _ => const RefusedConnection(ConnectionRefusal.unsupported),
    };
  }
  // The card is no longer counted among the voices the game speaks. Nothing
  // of the pipeline changes with it: it is a note on the canvas.
  if (link.to.socket == PipelineSocket.characterIn) {
    return HeardConnection(link.to.nodeId, false);
  }
  if (link.to.socket != PipelineSocket.readBy ||
      link.from.socket != PipelineSocket.characterVoice) {
    return const RefusedConnection(ConnectionRefusal.unsupported);
  }
  // The card whose part it was takes it back and speaks for itself again.
  return ReaderConnection(PipelineNodeIds.characterOf(link.from.nodeId) ?? '', null);
}

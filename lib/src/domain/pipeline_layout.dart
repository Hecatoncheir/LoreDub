// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// Where the canvas puts the pipeline: the cards drawn on it, the place of
/// every node, and where it is looked at from -- all that is the canvas's
/// own, and kept in `pipeline_graph.json`.
library;

import 'pipeline_graph_model.dart';

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

  /// The six stages in one line, in the order the work is done in: the
  /// pipeline is a line, and a scheme nobody has arranged yet should say so
  /// before it says anything else. Whisper stood raised above the rest while
  /// a line ran past it to the voice; that line is drawn through the
  /// translator now, and the step over it is the player's to make.
  static const standardPositions = {
    PipelineNodeIds.source: GraphPoint(40, 220),
    PipelineNodeIds.recognition: GraphPoint(325, 220),
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

  @override
  bool operator ==(Object other) =>
      other is GraphView &&
      other.x == x &&
      other.y == y &&
      other.zoom == zoom &&
      other.placed == placed;

  @override
  int get hashCode => Object.hash(x, y, zoom, placed);
}

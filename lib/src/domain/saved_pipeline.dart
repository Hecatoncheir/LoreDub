// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// A scheme the player kept, to draw again later or to hand to somebody else.
///
/// What is kept is what the graph screen draws and edits: the route the
/// pipeline takes, the arrangement of the nodes, which cards were put on the
/// canvas and whose voice reads whom among them, and which packs of the
/// glossary are drawn and switched on. The models, the languages
/// and the volumes are not in it — those belong to the machine the dubbing
/// runs on, and a scheme from somebody else's computer would drag their
/// downloads in with it.
library;

import 'pipeline_graph.dart';

class SavedPipeline {
  const SavedPipeline({
    required this.id,
    required this.name,
    this.scheme = PipelineScheme.live,
    this.captureRouted = true,
    this.layout = PipelineLayout.standard,
    this.readers = const {},
    this.activePacks,
  });

  final String id;
  final String name;

  /// Which canvas the scheme was kept from: Эфир's, or the Screen page's.
  /// Each keeps a shelf of its own, and a file of the other's is not read
  /// onto it -- its nodes would stand where nothing of this one is drawn.
  final PipelineScheme scheme;

  /// Whether the game's sound is drawn in: into whisper on Эфир, which is
  /// the way into the pipeline, and into the character detection on the
  /// Screen page, which is whether the voices behind the screen are told
  /// apart. Kept under the name the first of the two gave it.
  final bool captureRouted;

  /// Where the nodes sit, which cards are drawn, which of them the game is
  /// expected to speak and which of them are cut out of the mix.
  final PipelineLayout layout;

  /// Whose voice reads whom, by card id, among the cards on the canvas. A
  /// card that is read by nobody is kept as null rather than left out, so
  /// loading the scheme takes a substitution away as readily as it sets one.
  final Map<String, String?> readers;

  /// The packs of the glossary that were switched on -- the ones whose lines
  /// ran into the voice. Like [readers], the whole picture rather than the
  /// part the canvas draws: putting the scheme up switches on these and no
  /// others. Null for a scheme kept before the glossary was drawn, which
  /// leaves the packs as they are.
  final Set<String>? activePacks;

  SavedPipeline copyWith({String? name, PipelineLayout? layout}) => SavedPipeline(
    id: id,
    name: name ?? this.name,
    scheme: scheme,
    captureRouted: captureRouted,
    layout: layout ?? this.layout,
    readers: readers,
    activePacks: activePacks,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    // Written only for the Screen page's: a file of Эфир's schemes stays
    // the file it was before there were two.
    if (scheme != PipelineScheme.live) 'scheme': scheme.name,
    'captureRouted': captureRouted,
    'layout': layout.toJson(),
    'readers': readers,
    // Sorted so the file is the same file when nothing was changed.
    if (activePacks case final packs?) 'activePacks': [...packs]..sort(),
  };

  static SavedPipeline? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    // By name, and Эфир's where none is given: every scheme kept before the
    // Screen page drew one of its own is Эфир's.
    final scheme =
        PipelineScheme.values.where((value) => value.name == json['scheme']).firstOrNull ??
        PipelineScheme.live;
    return SavedPipeline(
      id: id,
      name: json['name'] as String? ?? '',
      scheme: scheme,
      // A scheme written before the subtitles moved off the graph carries a
      // `captureMode` as well; there is one route now, and it is ignored.
      captureRouted: json['captureRouted'] as bool? ?? true,
      // A scheme written while the cast was one switch says so with a
      // `castRouted` of its own: every card it draws comes back cut out of
      // the mix, which is the same scheme a card at a time.
      layout: switch (PipelineLayout.fromJson(json['layout'], scheme: scheme)) {
        final layout when json['castRouted'] == false => layout.copyWith(
          silent: {for (final placement in layout.cast) placement.characterId},
        ),
        final layout => layout,
      },
      readers: {
        for (final entry in (json['readers'] as Map<Object?, Object?>? ?? const {}).entries)
          if (entry.key case final String character)
            character: entry.value is String ? entry.value! as String : null,
      },
      activePacks: _packsFrom(json['activePacks']),
    );
  }

  /// The packs a scheme switched on, or null for one kept before it said.
  static Set<String>? _packsFrom(Object? json) => switch (json) {
    final List<Object?> packs => {...packs.whereType<String>()},
    _ => null,
  };
}

/// Every scheme kept on this machine, in the order they were saved.
class PipelineLibrary {
  const PipelineLibrary({this.pipelines = const []});

  static const empty = PipelineLibrary();

  final List<SavedPipeline> pipelines;

  bool get isEmpty => pipelines.isEmpty;

  Map<String, Object?> toJson() => {
    'version': 1,
    'pipelines': [for (final pipeline in pipelines) pipeline.toJson()],
  };

  /// The shelf of [scheme]'s canvas in [json].
  static PipelineLibrary fromJson(Object? json, {PipelineScheme scheme = PipelineScheme.live}) =>
      PipelineLibrary(pipelines: pipelinesOf(json, scheme));

  /// The schemes in [json], whether it is a whole library or the one scheme
  /// an export of a single card writes.
  static List<SavedPipeline> pipelinesFromJson(Object? json) {
    if (json is Map<String, Object?> && json['pipelines'] is List<Object?>) {
      return [
        for (final value in json['pipelines']! as List<Object?>) ?SavedPipeline.fromJson(value),
      ];
    }
    return [?SavedPipeline.fromJson(json)];
  }

  /// The schemes in [json] that [scheme]'s canvas draws. A file holding only
  /// the other canvas's is, to this one, a file holding none.
  static List<SavedPipeline> pipelinesOf(Object? json, PipelineScheme scheme) => [
    for (final pipeline in pipelinesFromJson(json))
      if (pipeline.scheme == scheme) pipeline,
  ];
}

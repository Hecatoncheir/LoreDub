// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// A scheme the player kept, to draw again later or to hand to somebody else.
///
/// What is kept is what the graph screen draws and edits: the route the
/// pipeline takes, the arrangement of the nodes, which cards were put on the
/// canvas and whose voice reads whom among them. The models, the languages
/// and the volumes are not in it — those belong to the machine the dubbing
/// runs on, and a scheme from somebody else's computer would drag their
/// downloads in with it.
library;

import 'pipeline_graph.dart';

class SavedPipeline {
  const SavedPipeline({
    required this.id,
    required this.name,
    this.captureRouted = true,
    this.layout = PipelineLayout.standard,
    this.readers = const {},
  });

  final String id;
  final String name;

  /// Whether the way into the pipeline is drawn.
  final bool captureRouted;

  /// Where the nodes sit, which cards are drawn, which of them the game is
  /// expected to speak and which of them are cut out of the mix.
  final PipelineLayout layout;

  /// Whose voice reads whom, by card id, among the cards on the canvas. A
  /// card that is read by nobody is kept as null rather than left out, so
  /// loading the scheme takes a substitution away as readily as it sets one.
  final Map<String, String?> readers;

  SavedPipeline copyWith({String? name, PipelineLayout? layout}) => SavedPipeline(
    id: id,
    name: name ?? this.name,
    captureRouted: captureRouted,
    layout: layout ?? this.layout,
    readers: readers,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'captureRouted': captureRouted,
    'layout': layout.toJson(),
    'readers': readers,
  };

  static SavedPipeline? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    return SavedPipeline(
      id: id,
      name: json['name'] as String? ?? '',
      // A scheme written before the subtitles moved off the graph carries a
      // `captureMode` as well; there is one route now, and it is ignored.
      captureRouted: json['captureRouted'] as bool? ?? true,
      // A scheme written while the cast was one switch says so with a
      // `castRouted` of its own: every card it draws comes back cut out of
      // the mix, which is the same scheme a card at a time.
      layout: switch (PipelineLayout.fromJson(json['layout'])) {
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
    );
  }
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

  static PipelineLibrary fromJson(Object? json) => PipelineLibrary(
    pipelines: pipelinesFromJson(json),
  );

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
}

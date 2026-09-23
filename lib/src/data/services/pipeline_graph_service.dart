// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/failure.dart';
import '../../domain/pipeline_graph.dart';
import 'json_file_store.dart';

/// Where a pipeline canvas was left: the place of every node, the cards put
/// on it, and the corner of the scheme the player was looking at.
///
/// Only the arrangement is kept. What the pipeline does is in the settings
/// and the cast, so a layout file that is lost or damaged costs the player
/// a drag of the mouse rather than their configuration. Each of the two
/// canvases keeps a file of its own: Эфир's is `pipeline_graph.json`, the
/// name it had while it was the only one, and the Screen page's
/// `screen_graph.json`.
class PipelineGraphService {
  PipelineGraphService({DirectoryProvider? root, PipelineScheme scheme = PipelineScheme.live})
    : _store = JsonFileStore(
        fileName: switch (scheme) {
          PipelineScheme.live => 'pipeline_graph.json',
          PipelineScheme.screen => 'screen_graph.json',
        },
        decode: (json) => PipelineLayout.fromJson(json, scheme: scheme),
        encode: (layout) => layout.toJson(),
        empty: PipelineLayout.standardOf(scheme),
        saveFailure: FailureCode.pipelineLayoutSaveFailed,
        root: root,
      );

  final JsonFileStore<PipelineLayout> _store;

  Future<String> file() => _store.file();

  /// The arrangement, or the standard one when nothing was ever saved.
  Future<PipelineLayout> load() => _store.load();

  Future<void> save(PipelineLayout layout) => _store.save(layout);
}

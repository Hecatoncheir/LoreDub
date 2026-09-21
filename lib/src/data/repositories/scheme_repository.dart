// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/pipeline_graph.dart';
import '../../domain/saved_pipeline.dart';
import '../services/pipeline_graph_service.dart';
import '../services/pipeline_library_service.dart';

/// The node canvas's own files: where its nodes were left, and the shelf of
/// schemes the player keeps.
///
/// Only the arrangement. What the pipeline does is the settings and the
/// cast, which the canvas writes through their own repositories.
class SchemeRepository {
  SchemeRepository({PipelineGraphService? layout, PipelineLibraryService? shelf})
    : _layout = layout ?? PipelineGraphService(),
      _shelf = shelf ?? PipelineLibraryService();

  final PipelineGraphService _layout;
  final PipelineLibraryService _shelf;

  /// Where the pipeline canvas was left.
  Future<PipelineLayout> loadLayout() => _layout.load();
  Future<void> saveLayout(PipelineLayout layout) => _layout.save(layout);

  /// The schemes kept on this machine.
  Future<PipelineLibrary> loadSchemes() => _shelf.load();
  Future<void> saveSchemes(PipelineLibrary library) => _shelf.save(library);

  Future<void> exportSchemes(String destination, List<SavedPipeline> schemes) =>
      _shelf.exportTo(destination, schemes);

  Future<List<SavedPipeline>> importSchemes(List<String> sources) => _shelf.readFiles(sources);
}

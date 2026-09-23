// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:lore_dub/src/data/repositories/scheme_repository.dart';
import 'package:lore_dub/src/domain/pipeline_graph.dart';
import 'package:lore_dub/src/domain/saved_pipeline.dart';
import 'package:mocktail/mocktail.dart';

/// The canvases' arrangements and their shelves of schemes, kept in memory:
/// Эфир's as [layout] and [shelf], the Screen page's as [screenLayout] and
/// [screenShelf].
class MemorySchemes extends Fake implements SchemeRepository {
  PipelineLayout layout = PipelineLayout.standard;
  PipelineLibrary shelf = PipelineLibrary.empty;
  PipelineLayout screenLayout = PipelineLayout.screenStandard;
  PipelineLibrary screenShelf = PipelineLibrary.empty;
  final exported = <(String, List<SavedPipeline>)>[];

  /// What an import reads, of which each shelf takes its own canvas's.
  List<SavedPipeline> incoming = const [];

  @override
  Future<PipelineLayout> loadLayout({PipelineScheme scheme = PipelineScheme.live}) async =>
      switch (scheme) {
        PipelineScheme.live => layout,
        PipelineScheme.screen => screenLayout,
      };

  @override
  Future<void> saveLayout(
    PipelineLayout value, {
    PipelineScheme scheme = PipelineScheme.live,
  }) async => switch (scheme) {
    PipelineScheme.live => layout = value,
    PipelineScheme.screen => screenLayout = value,
  };

  @override
  Future<PipelineLibrary> loadSchemes({PipelineScheme scheme = PipelineScheme.live}) async =>
      switch (scheme) {
        PipelineScheme.live => shelf,
        PipelineScheme.screen => screenShelf,
      };

  @override
  Future<void> saveSchemes(
    PipelineLibrary library, {
    PipelineScheme scheme = PipelineScheme.live,
  }) async => switch (scheme) {
    PipelineScheme.live => shelf = library,
    PipelineScheme.screen => screenShelf = library,
  };

  @override
  Future<void> exportSchemes(String destination, List<SavedPipeline> schemes) async =>
      exported.add((destination, schemes));

  @override
  Future<List<SavedPipeline>> importSchemes(
    List<String> sources, {
    PipelineScheme scheme = PipelineScheme.live,
  }) async => [
    for (final pipeline in incoming)
      if (pipeline.scheme == scheme) pipeline,
  ];
}

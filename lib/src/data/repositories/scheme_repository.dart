// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/pipeline_graph.dart';
import '../../domain/saved_pipeline.dart';
import '../services/pipeline_graph_service.dart';
import '../services/pipeline_library_service.dart';

/// The node canvases' own files: where the nodes of each were left, and the
/// shelf of schemes the player keeps for each.
///
/// Only the arrangement. What the pipeline does is the settings and the
/// cast, which the canvases write through their own repositories. There
/// are two canvases -- Эфир's and the Screen page's -- and each call names
/// the one it is for, Эфир's where it names none.
class SchemeRepository {
  SchemeRepository({
    PipelineGraphService? layout,
    PipelineLibraryService? shelf,
    PipelineGraphService? screenLayout,
    PipelineLibraryService? screenShelf,
  }) : _layouts = {
         PipelineScheme.live: layout ?? PipelineGraphService(),
         PipelineScheme.screen: screenLayout ?? PipelineGraphService(scheme: PipelineScheme.screen),
       },
       _shelves = {
         PipelineScheme.live: shelf ?? PipelineLibraryService(),
         PipelineScheme.screen:
             screenShelf ?? PipelineLibraryService(scheme: PipelineScheme.screen),
       };

  final Map<PipelineScheme, PipelineGraphService> _layouts;
  final Map<PipelineScheme, PipelineLibraryService> _shelves;

  /// Where [scheme]'s canvas was left.
  Future<PipelineLayout> loadLayout({PipelineScheme scheme = PipelineScheme.live}) =>
      _layouts[scheme]!.load();

  Future<void> saveLayout(PipelineLayout layout, {PipelineScheme scheme = PipelineScheme.live}) =>
      _layouts[scheme]!.save(layout);

  /// The schemes kept on this machine for [scheme]'s canvas.
  Future<PipelineLibrary> loadSchemes({PipelineScheme scheme = PipelineScheme.live}) =>
      _shelves[scheme]!.load();

  Future<void> saveSchemes(
    PipelineLibrary library, {
    PipelineScheme scheme = PipelineScheme.live,
  }) => _shelves[scheme]!.save(library);

  /// Writes [schemes] where the player asked; each says whose it is.
  Future<void> exportSchemes(String destination, List<SavedPipeline> schemes) =>
      _shelves[PipelineScheme.live]!.exportTo(destination, schemes);

  /// What the files the player chose hold for [scheme]'s shelf.
  Future<List<SavedPipeline>> importSchemes(
    List<String> sources, {
    PipelineScheme scheme = PipelineScheme.live,
  }) => _shelves[scheme]!.readFiles(sources);
}

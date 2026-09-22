// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:lore_dub/src/data/repositories/scheme_repository.dart';
import 'package:lore_dub/src/domain/pipeline_graph.dart';
import 'package:lore_dub/src/domain/saved_pipeline.dart';
import 'package:mocktail/mocktail.dart';

/// The canvas's arrangement and its shelf of schemes, kept in memory.
class MemorySchemes extends Fake implements SchemeRepository {
  PipelineLayout layout = PipelineLayout.standard;
  PipelineLibrary shelf = PipelineLibrary.empty;
  final exported = <(String, List<SavedPipeline>)>[];
  List<SavedPipeline> incoming = const [];

  @override
  Future<PipelineLayout> loadLayout() async => layout;

  @override
  Future<void> saveLayout(PipelineLayout value) async => layout = value;

  @override
  Future<PipelineLibrary> loadSchemes() async => shelf;

  @override
  Future<void> saveSchemes(PipelineLibrary library) async => shelf = library;

  @override
  Future<void> exportSchemes(String destination, List<SavedPipeline> schemes) async =>
      exported.add((destination, schemes));

  @override
  Future<List<SavedPipeline>> importSchemes(List<String> sources) async => incoming;
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/failure.dart';
import '../../domain/saved_pipeline.dart';
import 'json_file_store.dart';

/// The schemes the player kept, in one file beside the arrangement the
/// canvas is left in.
///
/// `pipeline_graph.json` is where the canvas stands right now; this is the
/// shelf of schemes to put it back to.
class PipelineLibraryService {
  PipelineLibraryService({DirectoryProvider? root})
    : _store = JsonFileStore(
        fileName: 'pipelines.json',
        decode: PipelineLibrary.fromJson,
        encode: (library) => library.toJson(),
        empty: PipelineLibrary.empty,
        saveFailure: FailureCode.pipelinesSaveFailed,
        root: root,
      );

  final JsonFileStore<PipelineLibrary> _store;

  Future<String> file() => _store.file();

  Future<PipelineLibrary> load() => _store.load();

  Future<void> save(PipelineLibrary library) => _store.save(library);

  /// Writes [pipelines] to a file of the player's choosing: one scheme, or
  /// the whole shelf, in the same shape either way.
  Future<void> exportTo(String destination, List<SavedPipeline> pipelines) => exportJson(
    destination,
    PipelineLibrary(pipelines: pipelines).toJson(),
    FailureCode.pipelinesExportFailed,
  );

  /// What the files the player chose hold. A file with no scheme in it — the
  /// wrong file, or a damaged one — is reported rather than passed over.
  Future<List<SavedPipeline>> readFiles(List<String> sources) async => [
    for (final read in await importJsonFiles(
      sources,
      decode: PipelineLibrary.pipelinesFromJson,
      holdsNothing: (pipelines) => pipelines.isEmpty,
      failure: FailureCode.pipelinesImportFailed,
    ))
      ...read,
  ];
}

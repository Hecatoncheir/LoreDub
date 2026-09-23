// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/failure.dart';
import '../../domain/pipeline_graph.dart';
import '../../domain/saved_pipeline.dart';
import 'json_file_store.dart';

/// The schemes the player kept, in one file beside the arrangement the
/// canvas is left in.
///
/// `pipeline_graph.json` is where the canvas stands right now; this is the
/// shelf of schemes to put it back to. The Screen page's canvas keeps a
/// shelf of its own, `screen_pipelines.json`, beside `screen_graph.json`.
class PipelineLibraryService {
  PipelineLibraryService({DirectoryProvider? root, PipelineScheme scheme = PipelineScheme.live})
    : _scheme = scheme,
      _store = JsonFileStore(
        fileName: switch (scheme) {
          PipelineScheme.live => 'pipelines.json',
          PipelineScheme.screen => 'screen_pipelines.json',
        },
        decode: (json) => PipelineLibrary.fromJson(json, scheme: scheme),
        encode: (library) => library.toJson(),
        empty: PipelineLibrary.empty,
        saveFailure: FailureCode.pipelinesSaveFailed,
        root: root,
      );

  final PipelineScheme _scheme;
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

  /// What the files the player chose hold for this shelf. A file with no
  /// scheme in it — the wrong file, a damaged one, or one of the other
  /// canvas's — is reported rather than passed over.
  Future<List<SavedPipeline>> readFiles(List<String> sources) async => [
    for (final read in await importJsonFiles(
      sources,
      decode: (json) => PipelineLibrary.pipelinesOf(json, _scheme),
      holdsNothing: (pipelines) => pipelines.isEmpty,
      failure: FailureCode.pipelinesImportFailed,
    ))
      ...read,
  ];
}

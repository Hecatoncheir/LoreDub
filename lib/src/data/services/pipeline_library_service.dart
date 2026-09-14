// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../domain/failure.dart';
import '../../domain/saved_pipeline.dart';

typedef PipelineLibraryRootProvider = Future<Directory> Function();

/// The schemes the player kept, in one file beside the arrangement the
/// canvas is left in.
///
/// `pipeline_graph.json` is where the canvas stands right now; this is the
/// shelf of schemes to put it back to. They are written the same way the
/// cast is — whole, through a temporary file — so a crash mid-write leaves
/// the shelf as it was.
class PipelineLibraryService {
  PipelineLibraryService({PipelineLibraryRootProvider? root})
    : _root = root ?? getApplicationSupportDirectory;

  final PipelineLibraryRootProvider _root;

  Future<String> file() async {
    final root = await _root();
    await root.create(recursive: true);
    return path.join(root.path, 'pipelines.json');
  }

  Future<PipelineLibrary> load() async {
    try {
      final source = File(await file());
      if (!await source.exists()) return PipelineLibrary.empty;
      return PipelineLibrary.fromJson(jsonDecode(await source.readAsString()));
    } on FormatException {
      return PipelineLibrary.empty;
    } on FileSystemException {
      return PipelineLibrary.empty;
    }
  }

  Future<void> save(PipelineLibrary library) async {
    final destination = await file();
    final temporary = File('$destination.tmp');
    try {
      await temporary.writeAsString(jsonEncode(library.toJson()), flush: true);
      await temporary.rename(destination);
    } on FileSystemException catch (error) {
      throw LoreDubFailure(FailureCode.pipelinesSaveFailed, detail: error.message);
    }
  }

  /// Writes [pipelines] to a file of the player's choosing: one scheme, or
  /// the whole shelf, in the same shape either way.
  Future<void> exportTo(String destination, List<SavedPipeline> pipelines) async {
    try {
      await File(destination).writeAsString(
        jsonEncode(PipelineLibrary(pipelines: pipelines).toJson()),
        flush: true,
      );
    } on FileSystemException catch (error) {
      throw LoreDubFailure(FailureCode.pipelinesExportFailed, detail: error.message);
    }
  }

  /// What the files the player chose hold. A file with no scheme in it — the
  /// wrong file, or a damaged one — is reported rather than passed over.
  Future<List<SavedPipeline>> readFiles(List<String> sources) async {
    final pipelines = <SavedPipeline>[];
    for (final source in sources) {
      try {
        final incoming = PipelineLibrary.pipelinesFromJson(
          jsonDecode(await File(source).readAsString()),
        );
        if (incoming.isEmpty) {
          throw LoreDubFailure(
            FailureCode.pipelinesImportFailed,
            detail: path.basename(source),
          );
        }
        pipelines.addAll(incoming);
      } on FormatException {
        throw LoreDubFailure(FailureCode.pipelinesImportFailed, detail: path.basename(source));
      } on FileSystemException {
        throw LoreDubFailure(FailureCode.pipelinesImportFailed, detail: path.basename(source));
      }
    }
    return pipelines;
  }
}

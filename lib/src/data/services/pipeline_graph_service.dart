// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../domain/failure.dart';
import '../../domain/json_text.dart';
import '../../domain/pipeline_graph.dart';

typedef PipelineGraphRootProvider = Future<Directory> Function();

/// Where the pipeline canvas was left: the place of every node, the cards
/// put on it, and the corner of the scheme the player was looking at.
///
/// Only the arrangement is kept. What the pipeline does is in the settings
/// and the cast, so a layout file that is lost or damaged costs the player
/// a drag of the mouse rather than their configuration.
class PipelineGraphService {
  PipelineGraphService({PipelineGraphRootProvider? root})
    : _root = root ?? getApplicationSupportDirectory;

  final PipelineGraphRootProvider _root;

  Future<String> file() async {
    final root = await _root();
    await root.create(recursive: true);
    return path.join(root.path, 'pipeline_graph.json');
  }

  /// The arrangement, or the standard one when nothing was ever saved.
  Future<PipelineLayout> load() async {
    final source = File(await file());
    if (!await source.exists()) return PipelineLayout.standard;
    try {
      return PipelineLayout.fromJson(decodeJsonText(await source.readAsString()));
    } on FormatException {
      return PipelineLayout.standard;
    } on FileSystemException {
      return PipelineLayout.standard;
    }
  }

  /// Writes the arrangement whole, replacing it in one step so a crash
  /// mid-write leaves the canvas as it was.
  Future<void> save(PipelineLayout layout) async {
    final destination = await file();
    final temporary = File('$destination.tmp');
    try {
      await temporary.writeAsString(jsonEncode(layout.toJson()), flush: true);
      await temporary.rename(destination);
    } on FileSystemException catch (error) {
      throw LoreDubFailure(FailureCode.pipelineLayoutSaveFailed, detail: error.message);
    }
  }
}

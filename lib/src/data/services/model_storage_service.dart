// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../domain/download_control.dart';
import '../../domain/failure.dart';
import '../../domain/model_package.dart';
import 'artifact_downloader.dart';

export 'artifact_downloader.dart' show DownloadProgress;

typedef ModelRootProvider = Future<Directory> Function();

class ModelStorageService {
  ModelStorageService({this._client, ModelRootProvider? rootProvider})
    : _rootProvider = rootProvider ?? _defaultRoot;

  final http.Client? _client;
  final ModelRootProvider _rootProvider;

  static Future<Directory> _defaultRoot() async {
    final support = await getApplicationSupportDirectory();
    return Directory(path.join(support.path, 'models'));
  }

  Future<Directory> modelDirectory(ModelPackage model) async {
    final root = await rootDirectory();
    return Directory(path.join(root.path, model.id));
  }

  Future<Directory> rootDirectory() async {
    final root = await _rootProvider();
    await root.create(recursive: true);
    return root;
  }

  Future<void> openRootDirectory() async {
    final root = await rootDirectory();
    if (!Platform.isWindows) {
      throw const LoreDubFailure(FailureCode.explorerUnsupported);
    }
    await Process.start(
      'explorer.exe',
      [root.path],
      mode: ProcessStartMode.detached,
    );
  }

  Future<bool> isInstalled(ModelPackage model) async {
    final directory = await modelDirectory(model);
    for (final artifact in model.artifacts) {
      final file = File(path.join(directory.path, artifact.fileName));
      if (!await file.exists()) return false;
      if (artifact.byteSize case final expected?) {
        if (await file.length() != expected) return false;
      }
    }
    return true;
  }

  /// Deletes a downloaded package, part files and all, so its space is given
  /// back. Nothing there is nothing to do.
  Future<void> remove(ModelPackage model) async {
    final directory = await modelDirectory(model);
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } on FileSystemException catch (error) {
      throw LoreDubFailure(
        FailureCode.modelRemoveFailed,
        detail: '${error.path}: ${error.message}',
      );
    }
  }

  Future<DownloadOutcome> install(
    ModelPackage model, {
    required DownloadProgress onProgress,
    String proxyUrl = '',
    DownloadControl? control,
  }) async {
    final client = _client ?? await createDownloadClient(proxyUrl);
    final directory = await modelDirectory(model);
    try {
      final outcome = await downloadArtifacts(
        model.artifacts,
        directory: directory,
        client: client,
        onProgress: onProgress,
        control: control,
      );
      if (outcome == DownloadOutcome.completed) await _removeStrangers(model, directory);
      return outcome;
    } finally {
      if (_client == null) client.close();
    }
  }

  /// Files left in a package's directory that the package no longer names.
  ///
  /// A model that changes shape leaves its old self behind otherwise: the
  /// translators became CTranslate2 models rather than PyTorch checkpoints,
  /// and the checkpoint would sit in the same folder afterwards -- hundreds
  /// of megabytes with nothing to read them and nothing to remove them but a
  /// hand. Swept only after a download finished, so a paused one keeps its
  /// parts.
  Future<void> _removeStrangers(ModelPackage model, Directory directory) async {
    final kept = {for (final artifact in model.artifacts) artifact.fileName};
    await for (final entry in directory.list()) {
      if (entry is! File) continue;
      final name = path.basename(entry.path);
      if (kept.contains(name) || name.endsWith('.part')) continue;
      try {
        await entry.delete();
      } on FileSystemException {
        // Best effort: a file still held open is swept the next time.
      }
    }
  }
}

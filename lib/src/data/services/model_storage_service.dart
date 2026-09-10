// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

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

  Future<void> install(
    ModelPackage model, {
    required DownloadProgress onProgress,
    String proxyUrl = '',
  }) async {
    final client = _client ?? await createDownloadClient(proxyUrl);
    try {
      await downloadArtifacts(
        model.artifacts,
        directory: await modelDirectory(model),
        client: client,
        onProgress: onProgress,
      );
    } finally {
      if (_client == null) client.close();
    }
  }
}

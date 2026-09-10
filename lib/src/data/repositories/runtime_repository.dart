// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/runtime_package.dart';
import '../services/artifact_downloader.dart';
import '../services/runtime_catalog.dart';
import '../services/runtime_storage_service.dart';

class RuntimeRepository {
  RuntimeRepository(this._storage);

  final RuntimeStorageService _storage;

  List<RuntimePackage> get catalog => runtimeCatalog;

  Future<Set<String>> installedIds() => _storage.installedRuntimeIds();

  Future<void> install(
    RuntimePackage package, {
    required DownloadProgress onProgress,
    String proxyUrl = '',
    String pythonExecutable = '',
  }) => _storage.install(
    package,
    onProgress: onProgress,
    proxyUrl: proxyUrl,
    pythonExecutable: pythonExecutable,
  );

  Future<void> remove(RuntimePackage package) => _storage.remove(package);

  Future<String> rootDirectory() async => (await _storage.rootDirectory()).path;
}

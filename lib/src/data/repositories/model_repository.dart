// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/download_control.dart';
import '../../domain/model_package.dart';
import '../services/model_catalog.dart';
import '../services/model_storage_service.dart';

class ModelRepository {
  ModelRepository(this._storage);

  final ModelStorageService _storage;

  Future<List<ModelInstallState>> loadStates() async => Future.wait(
    modelCatalog.map(
      (model) async => ModelInstallState(
        model: model,
        installed: await _storage.isInstalled(model),
      ),
    ),
  );

  Future<DownloadOutcome> install(
    ModelPackage model, {
    required DownloadProgress onProgress,
    String proxyUrl = '',
    DownloadControl? control,
  }) => _storage.install(
    model,
    onProgress: onProgress,
    proxyUrl: proxyUrl,
    control: control,
  );

  Future<void> remove(ModelPackage model) => _storage.remove(model);

  Future<String> directoryFor(ModelPackage model) async =>
      (await _storage.modelDirectory(model)).path;

  Future<String> rootDirectory() async => (await _storage.rootDirectory()).path;
  Future<void> openRootDirectory() => _storage.openRootDirectory();
}

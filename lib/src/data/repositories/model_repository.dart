// Copyright (c) 2026 GameLingo contributors.
// SPDX-License-Identifier: MIT

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

  Future<void> install(
    ModelPackage model, {
    required DownloadProgress onProgress,
  }) => _storage.install(model, onProgress: onProgress);

  Future<String> directoryFor(ModelPackage model) async =>
      (await _storage.modelDirectory(model)).path;
}

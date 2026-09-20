// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import '../../domain/compute_device.dart';
import '../../domain/model_package.dart';
import 'model_repository.dart';
import 'runtime_repository.dart';

/// What the machine has to run the pipeline with: the packages on disk,
/// what it can run them on, and where the GPU runtimes live.
class InstalledParts {
  const InstalledParts({
    this.models = const [],
    this.availability = const ComputeAvailability(),
    this.modelDirectory = '',
    this.runtimeDirectory = '',
  });

  /// Every package of the catalogue, said to be installed or not. No
  /// progress: this is what is there, not what is arriving.
  final List<ModelInstallState> models;

  /// What this machine's adapters offer, and which GPU runtimes are down.
  final ComputeAvailability availability;

  final String modelDirectory;
  final String runtimeDirectory;

  InstalledParts copyWith({
    List<ModelInstallState>? models,
    ComputeAvailability? availability,
    String? modelDirectory,
    String? runtimeDirectory,
  }) => InstalledParts(
    models: models ?? this.models,
    availability: availability ?? this.availability,
    modelDirectory: modelDirectory ?? this.modelDirectory,
    runtimeDirectory: runtimeDirectory ?? this.runtimeDirectory,
  );
}

/// What is installed, read once and told to everyone who cares.
///
/// The dubbing screens and the cast screen all have to know which packages
/// are on disk and what the machine can run them on, and they used to ask
/// `DownloadsCubit` for it — a screen's cubit, holding progress bars and
/// pause buttons, read by two other screens for the three fields of it
/// that were not about downloading at all.
///
/// So it is read here, and [changes] tells whoever follows. The downloads
/// screen is then one more reader: it lays its own rows over this, with
/// the progress of whatever is arriving.
class InstallRepository {
  InstallRepository(this._models, this._runtimes);

  final ModelRepository _models;
  final RuntimeRepository _runtimes;
  final _changes = StreamController<InstalledParts>.broadcast();
  InstalledParts _parts = const InstalledParts();

  InstalledParts get parts => _parts;

  /// Every value from now on. What holds at this moment is [parts]: the
  /// stream does not replay, for the reason `SettingsRepository.changes`
  /// gives.
  Stream<InstalledParts> get changes => _changes.stream;

  /// Rereads what is on disk, and where.
  Future<void> load() async {
    final read = await Future.wait<Object>([
      _models.loadStates(),
      _models.rootDirectory(),
      _runtimes.rootDirectory(),
    ]);
    _publish(
      _parts.copyWith(
        models: read[0] as List<ModelInstallState>,
        modelDirectory: read[1] as String,
        runtimeDirectory: read[2] as String,
      ),
    );
  }

  /// Rereads what the machine can run.
  ///
  /// The hardware half is asked for only when it is handed over: adapters
  /// do not appear mid-session, while a runtime download finishing is
  /// exactly what changes here.
  Future<void> refreshAvailability({ComputeAvailability? probe}) async {
    final hardware = probe ?? _parts.availability;
    final installed = await _runtimes.installedIds();
    _publish(
      _parts.copyWith(availability: hardware.copyWith(installedRuntimes: installed)),
    );
  }

  /// Says that one model is or is no longer on disk, without rereading the
  /// rest: a download that has just landed is known about here first.
  void modelSettled(String id, {required bool installed}) => _publish(
    _parts.copyWith(
      models: [
        for (final install in _parts.models)
          if (install.model.id == id) install.copyWith(installed: installed) else install,
      ],
    ),
  );

  /// Stages [value] as though it had been read, without touching disk.
  void seed(InstalledParts value) => _publish(value);

  void _publish(InstalledParts value) {
    _parts = value;
    if (!_changes.isClosed) _changes.add(value);
  }

  Future<void> dispose() => _changes.close();
}

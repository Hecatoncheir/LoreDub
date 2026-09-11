// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/model_repository.dart';
import '../../../data/repositories/runtime_repository.dart';
import '../../../domain/compute_device.dart';
import '../../../domain/download_control.dart';
import '../../../domain/model_package.dart';
import '../../../domain/progress_ticker.dart';
import '../../../domain/runtime_package.dart';
import 'settings_cubit.dart';
import 'shell_cubit.dart';

/// What is on disk and what is on its way there: the model packages, the
/// optional GPU runtimes, and what the machine can run them on.
class DownloadsState {
  const DownloadsState({
    this.models = const [],
    this.runtimes = const [],
    this.availability = const ComputeAvailability(),
    this.modelDirectoryPath = '',
    this.runtimeDirectoryPath = '',
    this.stopping = const {},
  });

  final List<ModelInstallState> models;
  final List<RuntimeInstallState> runtimes;

  /// What this machine offers, and which GPU runtimes are downloaded.
  final ComputeAvailability availability;
  final String modelDirectoryPath;
  final String runtimeDirectoryPath;

  /// Packages whose download was told to stop and has not noticed yet.
  final Set<String> stopping;

  bool isStopping(String id) => stopping.contains(id);

  /// What is on disk. The live screen depends on this and not on how far a
  /// download has got, so it can be compared to skip the progress ticks.
  Set<String> get installedModelIds => {
    for (final install in models)
      if (install.installed) install.model.id,
  };

  /// Whether the interface should offer this choice at all.
  bool isBackendOffered(ComputeStage stage, ComputeBackend backend) =>
      stageBackends(stage).contains(backend);

  /// Whether picking it would actually work right now.
  bool isBackendReady(ComputeStage stage, ComputeBackend backend) =>
      availability.isReady(stage, backend);

  /// The downloaded runtime this stage is using, so it can be given back.
  RuntimeInstallState? installedRuntimeFor(ComputeStage stage) {
    for (final backend in stageBackends(stage)) {
      final id = requiredRuntimeId(stage, backend);
      if (id == null || !availability.installedRuntimes.contains(id)) continue;
      final found = runtimeWithId(id);
      if (found != null) return found;
    }
    return null;
  }

  /// The runtime a backend still needs, or null when nothing is missing.
  RuntimeInstallState? missingRuntimeFor(ComputeStage stage, ComputeBackend backend) {
    if (!availability.supportsHardware(backend)) return null;
    final id = requiredRuntimeId(stage, backend);
    if (id == null || availability.installedRuntimes.contains(id)) return null;
    return runtimeWithId(id);
  }

  RuntimeInstallState? runtimeWithId(String id) {
    for (final install in runtimes) {
      if (install.package.id == id) return install;
    }
    return null;
  }

  DownloadsState copyWith({
    List<ModelInstallState>? models,
    List<RuntimeInstallState>? runtimes,
    ComputeAvailability? availability,
    String? modelDirectoryPath,
    String? runtimeDirectoryPath,
    Set<String>? stopping,
  }) => DownloadsState(
    models: models ?? this.models,
    runtimes: runtimes ?? this.runtimes,
    availability: availability ?? this.availability,
    modelDirectoryPath: modelDirectoryPath ?? this.modelDirectoryPath,
    runtimeDirectoryPath: runtimeDirectoryPath ?? this.runtimeDirectoryPath,
    stopping: stopping ?? this.stopping,
  );
}

class DownloadsCubit extends Cubit<DownloadsState> {
  DownloadsCubit(this._modelRepository, this._runtimeRepository, this._settings, this._errors)
    : super(const DownloadsState());

  final ModelRepository _modelRepository;
  final RuntimeRepository _runtimeRepository;
  final SettingsCubit _settings;
  final FailureSink _errors;

  /// The handle on each running download, by package id, so the interface
  /// can pause or cancel the one it is showing.
  final _controls = <String, DownloadControl>{};

  Future<void> load() async {
    final values = await Future.wait<Object>([
      _modelRepository.loadStates(),
      _modelRepository.rootDirectory(),
      _runtimeRepository.rootDirectory(),
    ]);
    if (isClosed) return;
    emit(
      state.copyWith(
        models: values[0] as List<ModelInstallState>,
        modelDirectoryPath: values[1] as String,
        runtimeDirectoryPath: values[2] as String,
      ),
    );
  }

  /// Rereads what the machine offers. The hardware half is asked for only
  /// when it is not already known: adapters do not appear mid-session, while
  /// a runtime download finishing is exactly what changes here.
  Future<void> refreshAvailability({ComputeAvailability? probe}) async {
    final hardware = probe ?? state.availability;
    final installed = await _runtimeRepository.installedIds();
    if (isClosed) return;
    emit(
      state.copyWith(
        availability: hardware.copyWith(installedRuntimes: installed),
        runtimes: [
          for (final package in _runtimeRepository.catalog)
            // A download that is paused or still running keeps its progress:
            // rebuilding the list must not lose where it got to.
            state.runtimeWithId(package.id)?.copyWith(installed: installed.contains(package.id)) ??
                RuntimeInstallState(
                  package: package,
                  installed: installed.contains(package.id),
                ),
        ],
      ),
    );
  }

  Future<void> installModel(ModelInstallState install) async {
    final index = state.models.indexOf(install);
    if (index < 0 || install.downloading) return;
    _errors.report(null);
    final control = DownloadControl();
    final ticker = ProgressTicker();
    _controls[install.model.id] = control;
    _replaceModel(
      index,
      install.copyWith(progress: install.progress ?? 0, paused: false, clearError: true),
    );
    try {
      final outcome = await _modelRepository.install(
        install.model,
        proxyUrl: _settings.settings.modelProxyUrl,
        control: control,
        onProgress: (progress) {
          // Every chunk reports; only a change the reader can see redraws.
          if (ticker.shouldReport(progress)) {
            _replaceModel(index, state.models[index].copyWith(progress: progress));
          }
        },
      );
      _replaceModel(index, switch (outcome) {
        DownloadOutcome.completed => state.models[index].copyWith(
          installed: true,
          clearProgress: true,
        ),
        // The bar stays where it stopped, so resuming reads as continuing.
        DownloadOutcome.paused => state.models[index].copyWith(paused: true),
        DownloadOutcome.cancelled => state.models[index].copyWith(
          clearProgress: true,
          paused: false,
        ),
      });
    } catch (exception) {
      _replaceModel(index, state.models[index].copyWith(clearProgress: true, error: exception));
    }
    _finished(install.model.id);
  }

  Future<void> installRuntime(RuntimeInstallState install) async {
    // Found by id: the state a button was built with may already have been
    // replaced by a newer one for the same package.
    final index = state.runtimes.indexWhere((runtime) => runtime.package.id == install.package.id);
    if (index < 0 || state.runtimes[index].installing) return;
    final current = state.runtimes[index];
    _errors.report(null);
    final control = DownloadControl();
    final ticker = ProgressTicker();
    _controls[install.package.id] = control;
    _replaceRuntime(
      index,
      current.copyWith(progress: current.progress ?? 0, paused: false, clearError: true),
    );
    try {
      final outcome = await _runtimeRepository.install(
        install.package,
        proxyUrl: _settings.settings.modelProxyUrl,
        pythonExecutable: _settings.settings.pythonExecutable,
        control: control,
        onProgress: (progress) {
          if (ticker.shouldReport(progress)) {
            _replaceRuntime(index, state.runtimes[index].copyWith(progress: progress));
          }
        },
      );
      _replaceRuntime(index, switch (outcome) {
        DownloadOutcome.completed => state.runtimes[index].copyWith(
          installed: true,
          clearProgress: true,
        ),
        DownloadOutcome.paused => state.runtimes[index].copyWith(paused: true),
        DownloadOutcome.cancelled => state.runtimes[index].copyWith(
          clearProgress: true,
          paused: false,
        ),
      });
      // A finished or discarded runtime changes which backends can be picked.
      await refreshAvailability();
    } catch (exception) {
      _replaceRuntime(index, state.runtimes[index].copyWith(clearProgress: true, error: exception));
    }
    _finished(install.package.id);
  }

  /// Deletes a downloaded model to give its space back. A download still in
  /// flight is not a model yet; that one is cancelled instead.
  Future<void> removeModel(ModelInstallState install) async {
    final index = state.models.indexWhere((model) => model.model.id == install.model.id);
    if (index < 0 || state.models[index].stoppable) return;
    _errors.report(null);
    try {
      await _modelRepository.remove(install.model);
      _replaceModel(index, state.models[index].copyWith(installed: false, clearError: true));
    } catch (exception) {
      _errors.report(exception);
    }
  }

  Future<void> removeRuntime(RuntimeInstallState install) async {
    _errors.report(null);
    try {
      await _runtimeRepository.remove(install.package);
      await refreshAvailability();
    } catch (exception) {
      _errors.report(exception);
    }
  }

  /// Stops a download and keeps what arrived, so asking again resumes.
  void pauseDownload(String id) => _stop(id, (control) => control.pause());

  /// Stops a download and throws away what arrived.
  ///
  /// A paused model has no attempt left to signal — the pause ended it — so
  /// its waiting part files are deleted here instead. Without that the
  /// cancel button of a paused download did nothing at all.
  void cancelDownload(String id) {
    if (_controls.containsKey(id)) return _stop(id, (control) => control.cancel());
    unawaited(_discardPaused(id));
  }

  Future<void> _discardPaused(String id) async {
    final index = state.models.indexWhere((model) => model.model.id == id);
    if (index < 0 || !state.models[index].paused || state.models[index].installed) return;
    try {
      await _modelRepository.remove(state.models[index].model);
      _replaceModel(index, state.models[index].copyWith(clearProgress: true, paused: false));
    } catch (exception) {
      _errors.report(exception);
    }
  }

  void _stop(String id, void Function(DownloadControl) ask) {
    final control = _controls[id];
    if (control == null) return;
    ask(control);
    emit(state.copyWith(stopping: {...state.stopping, id}));
  }

  void _finished(String id) {
    _controls.remove(id);
    if (isClosed || !state.stopping.contains(id)) return;
    emit(state.copyWith(stopping: {...state.stopping}..remove(id)));
  }

  Future<void> openModelDirectory() async {
    _errors.report(null);
    try {
      await _modelRepository.openRootDirectory();
    } catch (exception) {
      _errors.report(exception);
    }
  }

  void _replaceModel(int index, ModelInstallState value) {
    if (isClosed) return;
    emit(state.copyWith(models: [...state.models]..[index] = value));
  }

  void _replaceRuntime(int index, RuntimeInstallState value) {
    if (isClosed) return;
    emit(state.copyWith(runtimes: [...state.runtimes]..[index] = value));
  }

  /// Stages a state a widget test wants to render without touching disk.
  @visibleForTesting
  void seed(DownloadsState value) => emit(value);
}

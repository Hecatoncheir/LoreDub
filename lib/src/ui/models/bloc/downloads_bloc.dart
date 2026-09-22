// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/install_repository.dart';
import '../../../data/repositories/model_repository.dart';
import '../../../data/repositories/runtime_repository.dart';
import '../../../domain/compute_device.dart';
import '../../../domain/download_control.dart';
import '../../../domain/model_package.dart';
import '../../../domain/package_download.dart';
import '../../../domain/progress_ticker.dart';
import '../../../domain/runtime_package.dart';
import '../../shell/bloc/failure_cubit.dart';
import 'installed_packages.dart';

export 'installed_packages.dart';

/// What is on disk and what is on its way there: the model packages, the
/// optional GPU runtimes, and what the machine can run them on.
class DownloadsState extends Equatable {
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

  /// The same, together with the GPU runtimes on disk, as a value a widget
  /// can select: it stays equal through every tick of a download and changes
  /// only when something lands or is removed.
  InstalledPackages get installed =>
      InstalledPackages(models: installedModelIds, runtimes: availability.installedRuntimes);

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

  /// Whether a backend waits on a runtime this copy can never fetch.
  ///
  /// The Vulkan build of whisper.cpp travels inside the installer rather than
  /// the catalogue, so a copy built without the Vulkan SDK carries none and
  /// there is nothing to download that would mend it.
  bool lacksBuiltInRuntime(ComputeStage stage, ComputeBackend backend) {
    final id = requiredRuntimeId(stage, backend);
    if (id == null || availability.installedRuntimes.contains(id)) return false;
    return runtimeWithId(id) == null;
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

  @override
  List<Object?> get props => [
    models,
    runtimes,
    availability,
    modelDirectoryPath,
    runtimeDirectoryPath,
    stopping,
  ];
}

sealed class DownloadsEvent extends Equatable {
  const DownloadsEvent();

  @override
  List<Object?> get props => const [];
}

/// Fetches a model package, or resumes one that was paused.
final class ModelInstallAsked extends DownloadsEvent {
  const ModelInstallAsked(this.install);

  final ModelInstallState install;

  @override
  List<Object?> get props => [install.model.id];
}

/// Deletes a downloaded model to give its space back.
final class ModelRemoved extends DownloadsEvent {
  const ModelRemoved(this.install);

  final ModelInstallState install;

  @override
  List<Object?> get props => [install.model.id];
}

/// Fetches a GPU runtime, or resumes one that was paused.
final class RuntimeInstallAsked extends DownloadsEvent {
  const RuntimeInstallAsked(this.install);

  final RuntimeInstallState install;

  @override
  List<Object?> get props => [install.package.id];
}

final class RuntimeRemoved extends DownloadsEvent {
  const RuntimeRemoved(this.install);

  final RuntimeInstallState install;

  @override
  List<Object?> get props => [install.package.id];
}

/// Stops a download and keeps what arrived, so asking again resumes.
final class DownloadPaused extends DownloadsEvent {
  const DownloadPaused(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Stops a download and throws away what arrived.
final class DownloadCancelled extends DownloadsEvent {
  const DownloadCancelled(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Shows the player where the models are kept.
final class ModelDirectoryOpened extends DownloadsEvent {
  const ModelDirectoryOpened();
}

final class _InstalledChanged extends DownloadsEvent {
  const _InstalledChanged(this.parts);

  final InstalledParts parts;
}

/// The models screen, and the GPU runtimes of the settings screen: what is
/// on disk, with whatever is arriving laid over it.
///
/// Every download is a handler of its own and they run side by side --
/// several packages come down at once, and a pause or a cancel has to be
/// answered while the download it stops is still waiting on the network.
/// The ticks of a download are emitted from inside its handler, which is
/// the download's for as long as it runs.
class DownloadsBloc extends Bloc<DownloadsEvent, DownloadsState> {
  DownloadsBloc(
    this._modelRepository,
    this._runtimeRepository,
    this._installed,
    this._settings,
    this._errors,
  ) : super(const DownloadsState()) {
    // What is on disk is read and published once, for everyone; this
    // screen lays its own rows over it, with the progress of whatever is
    // arriving.
    on<_InstalledChanged>((event, emit) => _followInstalled(event.parts, emit));
    on<ModelInstallAsked>((event, emit) => _installModel(event.install, emit));
    on<RuntimeInstallAsked>((event, emit) => _installRuntime(event.install, emit));
    on<ModelRemoved>((event, emit) => _removeModel(event.install, emit));
    on<RuntimeRemoved>((event, emit) => _removeRuntime(event.install));
    on<DownloadPaused>((event, emit) => _stop(event.id, (control) => control.pause(), emit));
    on<DownloadCancelled>((event, emit) => _cancel(event.id, emit));
    on<ModelDirectoryOpened>((event, emit) => _openModelDirectory());
    _parts = _installed.changes.listen((parts) => add(_InstalledChanged(parts)));
  }

  final ModelRepository _modelRepository;
  final RuntimeRepository _runtimeRepository;
  final InstallRepository _installed;
  final SettingsRepository _settings;
  final FailureSink _errors;
  StreamSubscription<InstalledParts>? _parts;

  /// The handle on each running download, by package id, so the interface
  /// can pause or cancel the one it is showing.
  final _controls = <String, DownloadControl>{};

  /// What was read off disk, with whatever is arriving kept as it was: a
  /// download that is paused or still running keeps its progress, since
  /// rereading the list must not lose where it got to.
  void _followInstalled(InstalledParts parts, Emitter<DownloadsState> emit) {
    final runtimes = parts.availability.installedRuntimes;
    emit(
      state.copyWith(
        models: [
          for (final read in parts.models)
            _modelWithId(read.model.id)?.copyWith(installed: read.installed) ?? read,
        ],
        runtimes: [
          for (final package in _runtimeRepository.catalog)
            state.runtimeWithId(package.id)?.copyWith(installed: runtimes.contains(package.id)) ??
                RuntimeInstallState(
                  package: package,
                  installed: runtimes.contains(package.id),
                ),
        ],
        availability: parts.availability,
        modelDirectoryPath: parts.modelDirectory,
        runtimeDirectoryPath: parts.runtimeDirectory,
      ),
    );
  }

  Future<void> _installModel(ModelInstallState install, Emitter<DownloadsState> emit) => _download(
    install.model.id,
    emit,
    among: () => state.models,
    replacing: (models) => emit(state.copyWith(models: models)),
    run: (control, onProgress) => _modelRepository.install(
      install.model,
      proxyUrl: _settings.settings.modelProxyUrl,
      control: control,
      onProgress: onProgress,
    ),
    // A model that has landed is on disk for everyone, not only for the
    // screen that fetched it.
    afterwards: () async => _installed.modelSettled(
      install.model.id,
      installed: _modelWithId(install.model.id)?.installed ?? false,
    ),
  );

  Future<void> _installRuntime(RuntimeInstallState install, Emitter<DownloadsState> emit) =>
      _download(
        install.package.id,
        emit,
        among: () => state.runtimes,
        replacing: (runtimes) => emit(state.copyWith(runtimes: runtimes)),
        run: (control, onProgress) => _runtimeRepository.install(
          install.package,
          proxyUrl: _settings.settings.modelProxyUrl,
          pythonExecutable: _settings.settings.pythonExecutable,
          control: control,
          onProgress: onProgress,
        ),
        // A finished or discarded runtime changes which backends can be picked.
        afterwards: _installed.refreshAvailability,
      );

  /// Fetches the package [id] names and writes what became of it on its own
  /// row: a model and a GPU runtime arrive the same way, and this is that
  /// way, once.
  ///
  /// Addressed by id from beginning to end. Both halves used to take the
  /// row's index before the first `await` and then write the ticks and the
  /// outcome through it, so a list rebuilt in between -- which is what
  /// rereading what is on disk does -- had them writing on whatever stood
  /// in that place by the time the download ended.
  Future<void> _download<T extends PackageDownload<T>>(
    String id,
    Emitter<DownloadsState> emit, {
    required List<T> Function() among,
    required void Function(List<T>) replacing,
    required Future<DownloadOutcome> Function(DownloadControl, DownloadProgress) run,
    Future<void> Function()? afterwards,
  }) async {
    void change(T Function(T) becomes) {
      final rows = [...among()];
      final at = rows.indexWhere((row) => row.packageId == id);
      if (at < 0) return;
      rows[at] = becomes(rows[at]);
      replacing(rows);
    }

    // The row a button was built from may already have been replaced by a
    // newer one for the same package, so it is looked up rather than used.
    final asking = among().where((row) => row.packageId == id).firstOrNull;
    if (asking == null || asking.arriving) return;
    _errors.report(null);
    final control = DownloadControl();
    final ticker = ProgressTicker();
    _controls[id] = control;
    change((row) => row.started());
    try {
      final outcome = await run(control, (progress) {
        // Every chunk reports; only a change the reader can see redraws.
        if (ticker.shouldReport(progress)) change((row) => row.reaching(progress));
      });
      change(
        (row) => switch (outcome) {
          DownloadOutcome.completed => row.arrived(),
          // The bar stays where it stopped, so resuming reads as continuing.
          DownloadOutcome.paused => row.held(),
          DownloadOutcome.cancelled => row.dropped(),
        },
      );
      await afterwards?.call();
    } catch (exception) {
      change((row) => row.failing(exception));
    }
    _finished(id, emit);
  }

  /// Deletes a downloaded model to give its space back. A download still in
  /// flight is not a model yet; that one is cancelled instead.
  Future<void> _removeModel(ModelInstallState install, Emitter<DownloadsState> emit) async {
    final id = install.model.id;
    if (_modelWithId(id)?.stoppable ?? true) return;
    _errors.report(null);
    try {
      await _modelRepository.remove(install.model);
      _changeModel(id, (row) => row.copyWith(installed: false, clearError: true), emit);
      _installed.modelSettled(id, installed: false);
    } catch (exception) {
      _errors.report(exception);
    }
  }

  Future<void> _removeRuntime(RuntimeInstallState install) async {
    _errors.report(null);
    try {
      await _runtimeRepository.remove(install.package);
      await _installed.refreshAvailability();
    } catch (exception) {
      _errors.report(exception);
    }
  }

  /// A paused model has no attempt left to signal — the pause ended it — so
  /// its waiting part files are deleted here instead. Without that the
  /// cancel button of a paused download did nothing at all.
  Future<void> _cancel(String id, Emitter<DownloadsState> emit) async {
    if (_controls.containsKey(id)) return _stop(id, (control) => control.cancel(), emit);
    await _discardPaused(id, emit);
  }

  Future<void> _discardPaused(String id, Emitter<DownloadsState> emit) async {
    try {
      if (_modelWithId(id) case final install?) {
        if (!install.paused || install.installed) return;
        await _modelRepository.remove(install.model);
        _changeModel(id, (row) => row.dropped(), emit);
        return;
      }
      // A paused GPU runtime waits the same way, its part under
      // runtime/.downloads, which removing the runtime clears too.
      final install = state.runtimeWithId(id);
      if (install == null || !install.paused || install.installed) return;
      await _runtimeRepository.remove(install.package);
      _changeRuntime(id, (row) => row.dropped(), emit);
    } catch (exception) {
      _errors.report(exception);
    }
  }

  ModelInstallState? _modelWithId(String id) =>
      state.models.where((install) => install.model.id == id).firstOrNull;

  void _stop(String id, void Function(DownloadControl) ask, Emitter<DownloadsState> emit) {
    final control = _controls[id];
    if (control == null) return;
    ask(control);
    emit(state.copyWith(stopping: {...state.stopping, id}));
  }

  void _finished(String id, Emitter<DownloadsState> emit) {
    _controls.remove(id);
    if (!state.stopping.contains(id)) return;
    emit(state.copyWith(stopping: {...state.stopping}..remove(id)));
  }

  Future<void> _openModelDirectory() async {
    _errors.report(null);
    try {
      await _modelRepository.openRootDirectory();
    } catch (exception) {
      _errors.report(exception);
    }
  }

  void _changeModel(
    String id,
    ModelInstallState Function(ModelInstallState) becomes,
    Emitter<DownloadsState> emit,
  ) {
    final models = [...state.models];
    final at = models.indexWhere((install) => install.model.id == id);
    if (at < 0) return;
    models[at] = becomes(models[at]);
    emit(state.copyWith(models: models));
  }

  void _changeRuntime(
    String id,
    RuntimeInstallState Function(RuntimeInstallState) becomes,
    Emitter<DownloadsState> emit,
  ) {
    final runtimes = [...state.runtimes];
    final at = runtimes.indexWhere((install) => install.package.id == id);
    if (at < 0) return;
    runtimes[at] = becomes(runtimes[at]);
    emit(state.copyWith(runtimes: runtimes));
  }

  @override
  Future<void> close() async {
    await _parts?.cancel();
    return super.close();
  }
}

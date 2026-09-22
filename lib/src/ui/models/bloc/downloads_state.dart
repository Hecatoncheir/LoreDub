// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

part of 'downloads_bloc.dart';

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

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'model_package.dart';

/// How a GPU runtime gets onto the machine.
///
/// The whisper.cpp cuBLAS build is a signed release archive, so it is
/// downloaded and unpacked like a model. CUDA torch is one large wheel plus a
/// few small dependencies: [wheel] fetches the wheel with the model
/// downloader and has pip install the local file, while [pip] leaves the
/// whole thing to pip resolving from an index.
enum RuntimeInstallKind { archive, pip, wheel }

/// A GPU runtime the application fetches on demand.
///
/// Nothing here ships with the installer: a player on a CPU-only machine, or
/// one who never turns the GPU on, pays nothing for these.
class RuntimePackage {
  const RuntimePackage({
    required this.id,
    required this.kind,
    required this.approximateBytes,
    this.artifacts = const [],
    this.pipArguments = const [],
    this.probeFileName,
    this.wheelPython,
  });

  final String id;
  final RuntimeInstallKind kind;

  /// What the download costs, for the interface to show before it starts.
  /// pip resolves its own sizes, so for those this is an honest estimate.
  final int approximateBytes;

  /// Archives to fetch, verified exactly like model artifacts.
  final List<ModelArtifact> artifacts;

  /// Arguments after `pip install --target <directory>`.
  final List<String> pipArguments;

  /// A file that proves the unpack or install finished, relative to the
  /// package directory. Size alone cannot answer that for an archive.
  final String? probeFileName;

  /// The interpreter tag the [wheel] kind's wheel was built for, `cp311`.
  /// Any other interpreter falls back to [pipArguments].
  final String? wheelPython;
}

class RuntimeInstallState {
  const RuntimeInstallState({
    required this.package,
    this.installed = false,
    this.progress,
    this.paused = false,
    this.error,
  });

  final RuntimePackage package;
  final bool installed;
  final double? progress;

  /// Stopped part way with the partial file kept, so asking again resumes.
  /// A runtime left wholly to pip cannot reach this: pip has no half-way point.
  final bool paused;

  /// Why the install failed, as raised; written out by the interface.
  final Object? error;

  bool get installing => progress != null && !paused;
  bool get stoppable => progress != null;

  /// Whether stopping this one could be resumed later.
  bool get pausable => package.kind != RuntimeInstallKind.pip;

  RuntimeInstallState copyWith({
    bool? installed,
    double? progress,
    bool clearProgress = false,
    bool? paused,
    Object? error,
    bool clearError = false,
  }) => RuntimeInstallState(
    package: package,
    installed: installed ?? this.installed,
    progress: clearProgress ? null : progress ?? this.progress,
    paused: paused ?? this.paused,
    error: clearError ? null : error ?? this.error,
  );
}

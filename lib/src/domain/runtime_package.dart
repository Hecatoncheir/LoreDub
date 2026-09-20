// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'model_package.dart';
import 'package_download.dart';

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
    this.companions = const [],
    this.probeFileName,
    this.previousProbeFileName,
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

  /// Requirements pip installs beside the [wheel] kind's local wheel, from
  /// the index, in the same run. The [pip] route names its own in
  /// [pipArguments].
  final List<String> companions;

  /// A file that proves the unpack or install finished, relative to the
  /// package directory. Size alone cannot answer that for an archive.
  final String? probeFileName;

  /// The probe an install made before [companions] joined the package. Found
  /// without [probeFileName] beside it, only the companions are installed.
  final String? previousProbeFileName;

  /// The interpreter tag the [wheel] kind's wheel was built for, `cp311`.
  /// Any other interpreter falls back to [pipArguments].
  final String? wheelPython;
}

class RuntimeInstallState with PackageDownload<RuntimeInstallState> {
  const RuntimeInstallState({
    required this.package,
    this.installed = false,
    this.progress,
    this.paused = false,
    this.error,
  });

  final RuntimePackage package;

  @override
  final bool installed;

  @override
  final double? progress;

  /// Stopped part way with the partial file kept, so asking again resumes.
  /// A runtime left wholly to pip cannot reach this: pip has no half-way point.
  @override
  final bool paused;

  @override
  final Object? error;

  @override
  String get packageId => package.id;

  /// [PackageDownload.arriving] in this screen's words. A runtime left
  /// wholly to pip is installed rather than downloaded.
  bool get installing => arriving;

  @override
  RuntimeInstallState started() =>
      copyWith(progress: progress ?? 0, paused: false, clearError: true);

  @override
  RuntimeInstallState reaching(double progress) => copyWith(progress: progress);

  @override
  RuntimeInstallState arrived() => copyWith(installed: true, clearProgress: true);

  @override
  RuntimeInstallState held() => copyWith(paused: true);

  @override
  RuntimeInstallState dropped() => copyWith(clearProgress: true, paused: false);

  @override
  RuntimeInstallState failing(Object error) => copyWith(clearProgress: true, error: error);

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

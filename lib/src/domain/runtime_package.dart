// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'model_package.dart';

/// How a GPU runtime gets onto the machine.
///
/// The two heavy runtimes cannot be shipped the same way. The whisper.cpp
/// cuBLAS build is a signed release archive, so it is downloaded and unpacked
/// like a model. CUDA torch is a set of wheels that only pip can resolve for
/// the interpreter in use, so it is installed rather than copied.
enum RuntimeInstallKind { archive, pip }

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
}

class RuntimeInstallState {
  const RuntimeInstallState({
    required this.package,
    this.installed = false,
    this.progress,
    this.error,
  });

  final RuntimePackage package;
  final bool installed;
  final double? progress;

  /// Why the install failed, as raised; written out by the interface.
  final Object? error;

  bool get installing => progress != null;

  RuntimeInstallState copyWith({
    bool? installed,
    double? progress,
    bool clearProgress = false,
    Object? error,
    bool clearError = false,
  }) => RuntimeInstallState(
    package: package,
    installed: installed ?? this.installed,
    progress: clearProgress ? null : progress ?? this.progress,
    error: clearError ? null : error ?? this.error,
  );
}

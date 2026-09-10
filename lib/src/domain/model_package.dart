// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

enum HashAlgorithm { md5, sha256 }

class ModelArtifact {
  const ModelArtifact({
    required this.fileName,
    required this.url,
    this.byteSize,
    this.hash,
    this.hashAlgorithm = HashAlgorithm.sha256,
  });

  final String fileName;
  final Uri url;
  final int? byteSize;
  final String? hash;
  final HashAlgorithm hashAlgorithm;
}

/// What a package is for. Recognition is language-independent — one Whisper
/// model turns any speech into English — while translation and speech come as
/// a pair per language the game can be dubbed into.
enum ModelKind { recognition, translation, speech }

class ModelPackage {
  const ModelPackage({
    required this.id,
    required this.title,
    required this.description,
    required this.artifacts,
    this.kind = ModelKind.recognition,
    this.language,
    this.speaker,
  });

  final String id;
  final String title;
  final String description;
  final List<ModelArtifact> artifacts;
  final ModelKind kind;

  /// The language this package produces; null for recognition.
  final String? language;

  /// Silero voice to synthesize with. The worker falls back to whatever the
  /// package actually ships if this name is not among its speakers.
  final String? speaker;

  /// The file the pipeline hands to the runtime, for packages that ship one.
  String get primaryFileName => artifacts.first.fileName;
}

class ModelInstallState {
  const ModelInstallState({
    required this.model,
    this.installed = false,
    this.progress,
    this.error,
  });

  final ModelPackage model;
  final bool installed;
  final double? progress;
  final String? error;

  bool get downloading => progress != null;

  ModelInstallState copyWith({
    bool? installed,
    double? progress,
    bool clearProgress = false,
    String? error,
    bool clearError = false,
  }) => ModelInstallState(
    model: model,
    installed: installed ?? this.installed,
    progress: clearProgress ? null : progress ?? this.progress,
    error: clearError ? null : error ?? this.error,
  );
}

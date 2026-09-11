// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'model_package.dart';

/// A language the game can be dubbed into: its translator and its voice.
///
/// The two are only ever useful together, so the models screen downloads,
/// picks and deletes them as one, and shows one state for the pair.
class LanguagePair {
  const LanguagePair({required this.language, this.translation, this.speech});

  final String language;
  final ModelInstallState? translation;
  final ModelInstallState? speech;

  /// The halves the catalogue has, translator first.
  List<ModelInstallState> get parts => [?translation, ?speech];

  /// Both halves are on disk.
  bool get installed => parts.isNotEmpty && parts.every((part) => part.installed);

  int get downloadBytes => parts.fold(0, (sum, part) => sum + part.model.downloadBytes);

  /// The share of the pair's bytes on disk while either half is downloading
  /// or paused, or null while neither is. A half already installed counts in
  /// full, so the ring does not start from nothing when only the voice is
  /// missing.
  double? get progress {
    if (!parts.any((part) => part.progress != null)) return null;
    final total = downloadBytes;
    if (total == 0) return 0;
    var done = 0.0;
    for (final part in parts) {
      done += part.model.downloadBytes * (part.installed ? 1.0 : part.progress ?? 0.0);
    }
    return done / total;
  }

  /// Stopped part way with nothing still running.
  bool get paused => parts.any((part) => part.paused) && !parts.any((part) => part.downloading);
}

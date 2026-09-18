// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'model_package.dart';

/// Where a package stands on its way to the disk -- or a pair of them,
/// downloaded, held and let go of together, the way a language's translator
/// and voice are.
class PackageTransfer {
  PackageTransfer(this.parts)
    : downloading = [
        for (final part in parts)
          if (part.downloading) part,
      ],
      paused = [
        for (final part in parts)
          if (part.paused) part,
      ],
      missing = [
        for (final part in parts)
          if (!part.installed && part.progress == null) part,
      ];

  final List<ModelInstallState> parts;

  /// Parts arriving right now.
  final List<ModelInstallState> downloading;

  /// Parts stopped part way, with what arrived kept.
  final List<ModelInstallState> paused;

  /// Parts neither on disk nor on their way.
  final List<ModelInstallState> missing;

  /// Something is on its way, running or held.
  bool get inFlight => downloading.isNotEmpty || paused.isNotEmpty;

  /// Something is arriving rather than held.
  bool get running => downloading.isNotEmpty;

  /// Some part is on disk, so there is something to give back.
  bool get anyInstalled => parts.any((part) => part.installed);

  /// What a resume fetches: the whole pair, not only the half that happened
  /// to be paused.
  List<ModelInstallState> get toResume => [...paused, ...missing];

  /// What a cancel lets go of: everything on its way, running or held.
  List<ModelInstallState> get toCancel => [...downloading, ...paused];
}

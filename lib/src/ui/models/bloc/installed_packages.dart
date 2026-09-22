// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/foundation.dart';

/// Which model packages and GPU runtimes are on disk, compared by what they
/// hold rather than by which set instance holds it.
@immutable
class InstalledPackages {
  const InstalledPackages({required this.models, required this.runtimes});

  final Set<String> models;
  final Set<String> runtimes;

  @override
  bool operator ==(Object other) =>
      other is InstalledPackages &&
      setEquals(other.models, models) &&
      setEquals(other.runtimes, runtimes);

  @override
  int get hashCode =>
      Object.hash(Object.hashAllUnordered(models), Object.hashAllUnordered(runtimes));
}

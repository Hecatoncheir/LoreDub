// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'failure.dart';

/// An interpreter that was found and turned down, and why.
class RejectedPython {
  const RejectedPython(this.path, {this.version});

  final String path;

  /// Null when the executable would not start at all.
  final String? version;
}

class PythonDiscoveryResult {
  const PythonDiscoveryResult({required this.executable, required this.rejected});

  /// The first interpreter that can run the worker, or null when none can.
  final String? executable;

  /// Everything that was found but turned down. Kept as data: the interface
  /// writes the reasons out in its own language.
  final List<RejectedPython> rejected;

  LoreDubFailure get failure => rejected.isEmpty
      ? const LoreDubFailure(FailureCode.pythonSearchEmpty)
      : const LoreDubFailure(FailureCode.pythonSearchNoDependencies);
}

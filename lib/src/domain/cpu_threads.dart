// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// Threads to hand to whisper.cpp and torch by default.
///
/// Recognition dominates the delay before a phrase is voiced and scales well
/// with threads, so a fixed small number wastes a modern CPU. Half of the
/// logical processors keeps the game responsive while roughly halving the
/// wait compared to four threads.
int defaultCpuThreads(int logicalProcessors) {
  final available = logicalProcessors;
  if (available <= 4) return 2;
  return (available ~/ 2).clamp(4, 12);
}

/// Thread counts worth offering on a machine with [logicalProcessors],
/// always including [selected] -- so a setting carried over from another
/// processor still shows -- and the default.
List<int> cpuThreadOptions(int selected, int logicalProcessors) {
  final available = logicalProcessors;
  final options = {2, 3, 4, 6, 8, 12, 16}.where((value) => value <= available).toSet()
    ..add(selected)
    ..add(defaultCpuThreads(available));
  return options.toList()..sort();
}

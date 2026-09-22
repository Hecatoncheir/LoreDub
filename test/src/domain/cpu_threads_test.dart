// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/cpu_threads.dart';

void main() {
  test('scales the default thread count with the CPU', () {
    expect(defaultCpuThreads(2), 2);
    expect(defaultCpuThreads(4), 2);
    expect(defaultCpuThreads(8), 4);
    expect(defaultCpuThreads(12), 6);
    expect(defaultCpuThreads(24), 12);
    expect(defaultCpuThreads(64), 12, reason: 'more threads stop paying off');
  });

  test('offers the thread counts a machine has, with the chosen and the default', () {
    expect(cpuThreadOptions(4, 8), [2, 3, 4, 6, 8]);
    // Carried over from a larger processor, the choice still shows.
    expect(cpuThreadOptions(16, 4), [2, 3, 4, 16]);
  });
}

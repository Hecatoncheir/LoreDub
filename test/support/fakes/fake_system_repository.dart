// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:math' as math;

import 'package:lore_dub/src/data/repositories/system_repository.dart';
import 'package:lore_dub/src/domain/python_search.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:lore_dub/src/domain/game_process.dart';
import 'package:lore_dub/src/domain/monitor_layout.dart';
import 'package:mocktail/mocktail.dart';

/// What the machine has, without the native library: every answer is a
/// field the test sets, and anything a test did not expect to be asked
/// throws rather than reaching for the real thing.
class FakeSystemRepository extends Fake implements SystemRepository {
  List<GameProcess> processes = const [];

  /// Whether listing the processes fails, as a machine refusing it does.
  bool listingFails = false;

  MonitorLayout monitors = const MonitorLayout([
    Monitor(math.Rectangle(0, 0, 1920, 1080), primary: true),
  ]);

  ComputeAvailability availability = const ComputeAvailability();

  /// The interpreter a search finds, or null for none.
  String? python;

  /// Holds a search until completed, when set.
  Completer<void>? holdSearch;

  int searches = 0;

  @override
  Future<List<GameProcess>> listProcesses() async {
    if (listingFails) throw StateError('no list');
    return processes;
  }

  @override
  Future<MonitorLayout> monitorLayout() async => monitors;

  @override
  Future<ComputeAvailability> probeGraphics() async => availability;

  @override
  Future<PythonDiscoveryResult> findPythonExecutable() async {
    searches++;
    await holdSearch?.future;
    return PythonDiscoveryResult(executable: python, rejected: const []);
  }
}

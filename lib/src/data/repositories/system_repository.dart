// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/compute_device.dart';
import '../../domain/game_process.dart';
import '../../domain/monitor_layout.dart';
import '../services/native_engine_service.dart';
import '../services/python_discovery.dart';
import '../services/runtime_paths.dart';

/// What this machine has, asked of it rather than kept: the processes
/// running, where the monitors stand, the graphics adapters and drivers,
/// and a Python interpreter the worker could run under.
///
/// Nothing here starts a session or writes a file. It used to sit inside
/// the one repository that did both, so a screen that only listed the
/// processes was handed the whole engine to do it.
class SystemRepository {
  SystemRepository(this._engine, [PythonDiscovery? pythonDiscovery])
    : _pythonDiscovery = pythonDiscovery ?? PythonDiscovery();

  final NativeEngineService _engine;

  /// The interpreter the installer puts beside the application, which the
  /// settings offer to go back to.
  String get bundledPython => bundledPythonExecutablePath();
  final PythonDiscovery _pythonDiscovery;

  Future<List<GameProcess>> listProcesses() => _engine.listProcesses();

  /// Where the monitors stand against each other.
  Future<MonitorLayout> monitorLayout() => _engine.monitorLayout();

  /// What the machine's adapters and drivers offer, before the download
  /// state of the GPU runtimes is taken into account.
  Future<ComputeAvailability> probeGraphics() => _engine.probeGraphics();

  Future<PythonDiscoveryResult> findPythonExecutable() => _pythonDiscovery.find();
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/app_settings.dart';
import '../../domain/game_process.dart';
import '../services/native_engine_service.dart';
import '../services/python_discovery.dart';
import '../services/settings_service.dart';

class AppRepository {
  AppRepository(this._nativeEngine, this._settingsService, [PythonDiscovery? pythonDiscovery])
    : _pythonDiscovery = pythonDiscovery ?? PythonDiscovery();

  final NativeEngineService _nativeEngine;
  final SettingsService _settingsService;
  final PythonDiscovery _pythonDiscovery;

  Future<PythonDiscoveryResult> findPythonExecutable() => _pythonDiscovery.find();

  Stream<Map<String, Object?>> get events => _nativeEngine.events;
  bool get processLoopbackSupported => _nativeEngine.processLoopbackSupported;

  Future<AppSettings> loadSettings() => _settingsService.load();
  Future<void> saveSettings(AppSettings settings) => _settingsService.save(settings);
  Future<List<GameProcess>> listProcesses() => _nativeEngine.listProcesses();

  Future<void> start({
    required GameProcess? process,
    required AppSettings settings,
    required Map<String, String> modelDirectories,
  }) async {
    try {
      await _nativeEngine.start({
        'processId': process?.pid ?? 0,
        'captureMode': settings.captureMode.name,
        'audioSource': settings.audioCaptureSource.name,
        'targetLanguage': settings.targetLanguage,
        'sourceLanguage': settings.effectiveSourceLanguage,
        'ttsSpeed': settings.ttsSpeed,
        'cpuThreads': settings.cpuThreads,
        'ocrRegionTop': settings.ocrRegionTop,
        'pythonExecutable': settings.pythonExecutable,
        'models': modelDirectories,
      });
      if (process != null &&
          (settings.captureMode == CaptureMode.ocr ||
              settings.audioCaptureSource == AudioCaptureSource.process)) {
        await _nativeEngine.setProcessVolume(
          process.pid,
          settings.originalVolume,
        );
      }
    } catch (_) {
      await _nativeEngine.stop();
      rethrow;
    }
  }

  Future<void> stop() => _nativeEngine.stop();
  void dispose() => _nativeEngine.dispose();
}

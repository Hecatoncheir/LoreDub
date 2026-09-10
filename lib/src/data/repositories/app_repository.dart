// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/app_settings.dart';
import '../../domain/compute_device.dart';
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

  /// What the machine's adapters and drivers offer, before the download
  /// state of the GPU runtimes is taken into account.
  Future<ComputeAvailability> probeGraphics() => _nativeEngine.probeGraphics();

  /// [modelDirectories] carries the three paths the pipeline needs for the
  /// chosen language: `whisper` and `translation` directories, and the
  /// `speech` model file. [speaker] is the voice of that speech model.
  /// [runtimeDirectory] is where downloaded GPU runtimes were unpacked.
  Future<void> start({
    required GameProcess? process,
    required AppSettings settings,
    required Map<String, String> modelDirectories,
    required String speaker,
    required bool followSpeaker,
    required List<String> maleVoices,
    required List<String> femaleVoices,
    required ComputeBackend recognitionBackend,
    required ComputeBackend translationBackend,
    required String runtimeDirectory,
  }) async {
    try {
      await _nativeEngine.start({
        'speaker': speaker,
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
        'followSpeaker': followSpeaker,
        'maleVoices': maleVoices.join(','),
        'femaleVoices': femaleVoices.join(','),
        'recognitionBackend': recognitionBackend.name,
        'translationBackend': translationBackend.name,
        'runtimeDirectory': runtimeDirectory,
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

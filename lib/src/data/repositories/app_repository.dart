// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/app_settings.dart';
import '../../domain/compute_device.dart';
import '../../domain/game_process.dart';
import '../services/native_engine_service.dart';
import '../services/python_discovery.dart';
import '../services/settings_service.dart';
import '../services/voice_bank_service.dart';

class AppRepository {
  AppRepository(
    this._nativeEngine,
    this._settingsService, [
    PythonDiscovery? pythonDiscovery,
    VoiceBankService? voiceBank,
  ]) : _pythonDiscovery = pythonDiscovery ?? PythonDiscovery(),
       _voiceBank = voiceBank ?? VoiceBankService();

  final NativeEngineService _nativeEngine;
  final SettingsService _settingsService;
  final PythonDiscovery _pythonDiscovery;
  final VoiceBankService _voiceBank;

  Future<PythonDiscoveryResult> findPythonExecutable() => _pythonDiscovery.find();

  Stream<Map<String, Object?>> get events => _nativeEngine.events;
  bool get processLoopbackSupported => _nativeEngine.processLoopbackSupported;

  Future<AppSettings> loadSettings() => _settingsService.load();
  Future<void> saveSettings(AppSettings settings) => _settingsService.save(settings);
  Future<List<GameProcess>> listProcesses() => _nativeEngine.listProcesses();

  /// The bank file the original voice keeps [game]'s characters in; the game
  /// is named by its executable.
  Future<String> voiceBankFileFor(String game) => _voiceBank.fileFor(game);

  /// How many voices the banks of all games hold together.
  Future<int> voiceBankSize() => _voiceBank.count();
  Future<void> clearVoiceBank() => _voiceBank.clear();

  /// What the machine's adapters and drivers offer, before the download
  /// state of the GPU runtimes is taken into account.
  Future<ComputeAvailability> probeGraphics() => _nativeEngine.probeGraphics();

  /// [modelDirectories] carries the three paths the pipeline needs for the
  /// chosen language: `whisper` and `translation` directories, and the
  /// `speech` model file, plus the `converter` directory when the original
  /// voice is on. [speaker] is the voice of that speech model.
  /// [runtimeDirectory] is where downloaded GPU runtimes were unpacked.
  /// [voiceBank] is the game's bank file, when characters are remembered.
  Future<void> start({
    required GameProcess? process,
    required AppSettings settings,
    required Map<String, String> modelDirectories,
    required String speaker,
    required String translationPrefix,
    required bool translateSpeech,
    required bool followSpeaker,
    required List<String> maleVoices,
    required List<String> femaleVoices,
    required ComputeBackend recognitionBackend,
    required ComputeBackend translationBackend,
    required ComputeBackend voiceConversionBackend,
    required String runtimeDirectory,
    String? voiceBank,
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
        'ocrRegionLeft': settings.ocrRegion.left,
        'ocrRegionTop': settings.ocrRegion.top,
        'ocrRegionRight': settings.ocrRegion.right,
        'ocrRegionBottom': settings.ocrRegion.bottom,
        'pythonExecutable': settings.pythonExecutable,
        'models': modelDirectories,
        'translationPrefix': translationPrefix,
        'translateSpeech': translateSpeech,
        'followSpeaker': followSpeaker,
        'overlapVoices': settings.overlapVoices,
        'maleVoices': maleVoices.join(','),
        'femaleVoices': femaleVoices.join(','),
        'recognitionBackend': recognitionBackend.name,
        'translationBackend': translationBackend.name,
        'voiceConversionBackend': voiceConversionBackend.name,
        'runtimeDirectory': runtimeDirectory,
        'voiceBank': ?voiceBank,
      });
      await _duck(process, settings);
      _sessionProcess = process;
      _sessionSettings = settings;
      _nativeEngine.setHotkeys(
        pause: settings.pauseHotkey,
        resume: settings.resumeHotkey,
        snapshot: settings.snapshotHotkey,
      );
    } catch (_) {
      await _nativeEngine.stop();
      rethrow;
    }
  }

  /// Starts the snapshot session: the translator, the voice and the snapshot
  /// key. Nothing is captured until the player selects an area, and no game
  /// is turned down.
  Future<void> startSnapshot({
    required AppSettings settings,
    required Map<String, String> modelDirectories,
    required String speaker,
    required String translationPrefix,
    required ComputeBackend translationBackend,
    required String runtimeDirectory,
  }) async {
    try {
      await _nativeEngine.startSnapshot({
        'speaker': speaker,
        'targetLanguage': settings.targetLanguage,
        'ttsSpeed': settings.ttsSpeed,
        'cpuThreads': settings.cpuThreads,
        'pythonExecutable': settings.pythonExecutable,
        'models': modelDirectories,
        'translationPrefix': translationPrefix,
        'translationBackend': translationBackend.name,
        'runtimeDirectory': runtimeDirectory,
      });
      _nativeEngine.setHotkeys(snapshot: settings.snapshotHotkey);
    } catch (_) {
      await _nativeEngine.stop();
      rethrow;
    }
  }

  /// What the running session was started with, so a resume can turn the
  /// game down again exactly as the start did.
  GameProcess? _sessionProcess;
  AppSettings? _sessionSettings;

  /// Turns the captured game down while it is dubbed.
  Future<void> _duck(GameProcess? process, AppSettings settings) async {
    if (process == null) return;
    if (settings.captureMode != CaptureMode.ocr &&
        settings.audioCaptureSource != AudioCaptureSource.process) {
      return;
    }
    await _nativeEngine.setProcessVolume(process.pid, settings.originalVolume);
  }

  /// Rests the session: capture hands nothing on, what was queued is
  /// dropped, and the game plays at its own volume.
  Future<void> pause() async => _nativeEngine.setPaused(true);

  /// Picks the session up where it rested.
  Future<void> resume() async {
    _nativeEngine.setPaused(false);
    final settings = _sessionSettings;
    if (settings != null) await _duck(_sessionProcess, settings);
  }

  Future<void> stop() {
    _sessionProcess = null;
    _sessionSettings = null;
    return _nativeEngine.stop();
  }

  void dispose() => _nativeEngine.dispose();
}

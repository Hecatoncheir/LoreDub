// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/app_settings.dart';
import '../../domain/compute_device.dart';
import '../../domain/ocr_region.dart';
import '../../domain/runtime_paths.dart';
import '../../domain/spoken_language.dart';

class SettingsService {
  /// A code stored by an older build, or one whose entry has since been
  /// removed, must not reach whisper.cpp as an unknown argument.
  /// An interface language this build no longer offers falls back to the
  /// default rather than leaving the app without any translation.
  static String _readInterfaceLanguage(SharedPreferences preferences) {
    final stored = preferences.getString('interfaceLanguage');
    if (stored == null || !interfaceLanguages.contains(stored)) {
      return defaultInterfaceLanguage;
    }
    return stored;
  }

  static String _readSourceLanguage(SharedPreferences preferences) {
    final stored = preferences.getString('sourceLanguage');
    if (stored == null || !isSupportedSpokenLanguage(stored)) return fallbackSpokenLanguage;
    return stored;
  }

  /// A pin written by a build that offered more backends than this one must
  /// not survive as a value no stage can resolve.
  static ComputeBackend? _readBackend(SharedPreferences preferences, String key) {
    final stored = preferences.getString(key);
    if (stored == null) return null;
    for (final backend in ComputeBackend.values) {
      if (backend.name == stored) return backend;
    }
    return null;
  }

  /// Builds before the frame could be drawn stored only `ocrRegionTop`, the
  /// top of a full-width band; the other edges then default to that band.
  static OcrRegion _readOcrRegion(SharedPreferences preferences) => OcrRegion(
    left: preferences.getDouble('ocrRegionLeft') ?? OcrRegion.standard.left,
    top: preferences.getDouble('ocrRegionTop') ?? OcrRegion.standard.top,
    right: preferences.getDouble('ocrRegionRight') ?? OcrRegion.standard.right,
    bottom: preferences.getDouble('ocrRegionBottom') ?? OcrRegion.standard.bottom,
  ).normalized();

  /// Never set means the default; set to nothing means none.
  static Hotkey? _readHotkey(SharedPreferences preferences, String key, Hotkey fallback) {
    final value = preferences.getString(key);
    if (value == null) return fallback;
    if (value.isEmpty) return null;
    return Hotkey.decode(value) ?? fallback;
  }

  static Future<void> _writeBackend(
    SharedPreferences preferences,
    String key,
    ComputeBackend? backend,
  ) => backend == null ? preferences.remove(key) : preferences.setString(key, backend.name);

  Future<AppSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    return AppSettings(
      captureMode: CaptureMode.values.firstWhere(
        (mode) => mode.name == preferences.getString('captureMode'),
        orElse: () => CaptureMode.audio,
      ),
      targetLanguage: preferences.getString('targetLanguage') ?? 'ru',
      originalVolume: preferences.getDouble('originalVolume') ?? 0.18,
      ttsSpeed: preferences.getDouble('ttsSpeed') ?? 1.12,
      cpuThreads: preferences.getInt('cpuThreads') ?? defaultCpuThreads(),
      showOverlay: preferences.getBool('showOverlay') ?? true,
      ocrRegion: _readOcrRegion(preferences),
      modelProxyUrl: preferences.getString('modelProxyUrl') ?? '',
      audioCaptureSource: AudioCaptureSource.values.firstWhere(
        (source) => source.name == preferences.getString('audioCaptureSource'),
        orElse: () => AudioCaptureSource.process,
      ),
      pythonExecutable: preferences.getString('pythonExecutable') ?? bundledPythonExecutablePath(),
      detectSourceLanguage: preferences.getBool('detectSourceLanguage') ?? true,
      sourceLanguage: _readSourceLanguage(preferences),
      interfaceLanguage: _readInterfaceLanguage(preferences),
      whisperModel: preferences.getString('whisperModel') ?? '',
      automaticVoice: preferences.getBool('automaticVoice') ?? true,
      voice: preferences.getString('voice') ?? '',
      originalVoice: preferences.getBool('originalVoice') ?? false,
      voiceBank: preferences.getBool('voiceBank') ?? false,
      overlapVoices: preferences.getBool('overlapVoices') ?? true,
      pauseHotkey: _readHotkey(preferences, 'pauseHotkey', Hotkey.defaultPause),
      resumeHotkey: _readHotkey(preferences, 'resumeHotkey', Hotkey.defaultResume),
      snapshotHotkey: _readHotkey(preferences, 'snapshotHotkey', Hotkey.defaultSnapshot),
      computeDevice: ComputeDevice.values.firstWhere(
        (device) => device.name == preferences.getString('computeDevice'),
        orElse: () => ComputeDevice.auto,
      ),
      recognitionBackend: _readBackend(preferences, 'recognitionBackend'),
      translationBackend: _readBackend(preferences, 'translationBackend'),
      speechBackend: _readBackend(preferences, 'speechBackend'),
      voiceConversionBackend: _readBackend(preferences, 'voiceConversionBackend'),
    );
  }

  Future<void> save(AppSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setString('captureMode', settings.captureMode.name),
      preferences.setString('targetLanguage', settings.targetLanguage),
      preferences.setDouble('originalVolume', settings.originalVolume),
      preferences.setDouble('ttsSpeed', settings.ttsSpeed),
      preferences.setInt('cpuThreads', settings.cpuThreads),
      preferences.setBool('showOverlay', settings.showOverlay),
      preferences.setDouble('ocrRegionLeft', settings.ocrRegion.left),
      preferences.setDouble('ocrRegionTop', settings.ocrRegion.top),
      preferences.setDouble('ocrRegionRight', settings.ocrRegion.right),
      preferences.setDouble('ocrRegionBottom', settings.ocrRegion.bottom),
      preferences.setString('modelProxyUrl', settings.modelProxyUrl),
      preferences.setString(
        'audioCaptureSource',
        settings.audioCaptureSource.name,
      ),
      preferences.setString('pythonExecutable', settings.pythonExecutable),
      preferences.setBool('detectSourceLanguage', settings.detectSourceLanguage),
      preferences.setString('sourceLanguage', settings.sourceLanguage),
      preferences.setString('interfaceLanguage', settings.interfaceLanguage),
      preferences.setString('whisperModel', settings.whisperModel),
      preferences.setBool('automaticVoice', settings.automaticVoice),
      preferences.setString('voice', settings.voice),
      preferences.setBool('originalVoice', settings.originalVoice),
      preferences.setBool('voiceBank', settings.voiceBank),
      preferences.setBool('overlapVoices', settings.overlapVoices),
      // An empty string is a combination the player removed on purpose,
      // which must not come back as the default next time.
      preferences.setString('pauseHotkey', settings.pauseHotkey?.encode() ?? ''),
      preferences.setString('resumeHotkey', settings.resumeHotkey?.encode() ?? ''),
      preferences.setString('snapshotHotkey', settings.snapshotHotkey?.encode() ?? ''),
      preferences.setString('computeDevice', settings.computeDevice.name),
      _writeBackend(preferences, 'recognitionBackend', settings.recognitionBackend),
      _writeBackend(preferences, 'translationBackend', settings.translationBackend),
      _writeBackend(preferences, 'speechBackend', settings.speechBackend),
      _writeBackend(preferences, 'voiceConversionBackend', settings.voiceConversionBackend),
    ]);
  }
}

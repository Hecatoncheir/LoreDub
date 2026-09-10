// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/app_settings.dart';
import '../../domain/runtime_paths.dart';
import '../../domain/spoken_language.dart';

class SettingsService {
  /// A code stored by an older build, or one whose entry has since been
  /// removed, must not reach whisper.cpp as an unknown argument.
  static String _readSourceLanguage(SharedPreferences preferences) {
    final stored = preferences.getString('sourceLanguage');
    if (stored == null || !isSupportedSpokenLanguage(stored)) return fallbackSpokenLanguage;
    return stored;
  }

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
      ocrRegionTop: preferences.getDouble('ocrRegionTop') ?? 0.55,
      modelProxyUrl: preferences.getString('modelProxyUrl') ?? '',
      audioCaptureSource: AudioCaptureSource.values.firstWhere(
        (source) => source.name == preferences.getString('audioCaptureSource'),
        orElse: () => AudioCaptureSource.process,
      ),
      pythonExecutable: preferences.getString('pythonExecutable') ?? bundledPythonExecutablePath(),
      detectSourceLanguage: preferences.getBool('detectSourceLanguage') ?? true,
      sourceLanguage: _readSourceLanguage(preferences),
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
      preferences.setDouble('ocrRegionTop', settings.ocrRegionTop),
      preferences.setString('modelProxyUrl', settings.modelProxyUrl),
      preferences.setString(
        'audioCaptureSource',
        settings.audioCaptureSource.name,
      ),
      preferences.setString('pythonExecutable', settings.pythonExecutable),
      preferences.setBool('detectSourceLanguage', settings.detectSourceLanguage),
      preferences.setString('sourceLanguage', settings.sourceLanguage),
    ]);
  }
}

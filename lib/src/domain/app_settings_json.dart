// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'app_settings.dart';
import 'compute_device.dart';
import 'ocr_region.dart';
import 'spoken_language.dart';

/// [AppSettings] as the one JSON object they are kept as, and back.
///
/// Flat, under the names each setting was stored by when every one was a
/// preference of its own -- so the preferences an older build left behind
/// read as this object does, and move over without a translation table.
/// Every default is the constructor's: a key missing, or holding something
/// this build cannot read, is the setting as a fresh install has it.
extension AppSettingsJson on AppSettings {
  Map<String, Object?> toJson() => {
    'captureRouted': captureRouted,
    'targetLanguage': targetLanguage,
    'originalVolume': originalVolume,
    'duckWhileSpeaking': duckWhileSpeaking,
    'hurryWhenQueued': hurryWhenQueued,
    'roughRecognition': roughRecognition,
    'ttsSpeed': ttsSpeed,
    'cpuThreads': cpuThreads,
    'ocrRegionLeft': ocrRegion.left,
    'ocrRegionTop': ocrRegion.top,
    'ocrRegionRight': ocrRegion.right,
    'ocrRegionBottom': ocrRegion.bottom,
    'modelProxyUrl': modelProxyUrl,
    'audioCaptureSource': audioCaptureSource.name,
    'screenSource': screenSource.name,
    'pythonExecutable': pythonExecutable,
    'detectSourceLanguage': detectSourceLanguage,
    'sourceLanguage': sourceLanguage,
    'screenLanguage': screenLanguage,
    'interfaceLanguage': interfaceLanguage,
    'interfaceScale': interfaceScale,
    'interfaceTheme': interfaceTheme.name,
    'whisperModel': whisperModel,
    'automaticVoice': automaticVoice,
    'voice': voice,
    'originalVoice': originalVoice,
    'voiceBank': voiceBank,
    'overlapVoices': overlapVoices,
    // An empty string is a combination the player removed on purpose,
    // which must not come back as the default next time.
    for (final action in HotkeyAction.values)
      '${action.name}Hotkey': hotkeys[action]?.encode() ?? '',
    'showFrameOverlay': showFrameOverlay,
    'screenVoices': screenVoices,
    'computeDevice': computeDevice.name,
    for (final MapEntry(key: stage, value: backend) in pinned.entries)
      '${stage.name}Backend': backend.name,
  };
}

/// The settings [json] holds.
///
/// What only the machine and the catalogue can answer is handed in: the
/// languages this build dubs into -- a language it no longer carries falls
/// back to the first, or the session would start with no translator and no
/// voice -- the interpreter it ships, and the threads it would use.
AppSettings appSettingsFromJson(
  Map<String, Object?> json, {
  required List<String> dubbingLanguages,
  required String bundledPython,
  required int defaultThreads,
}) {
  const fresh = AppSettings();
  bool flag(String key, bool fallback) => json[key] is bool ? json[key]! as bool : fallback;
  double number(String key, double fallback) => switch (json[key]) {
    final num value => value.toDouble(),
    _ => fallback,
  };
  String text(String key, String fallback) => json[key] is String ? json[key]! as String : fallback;
  T named<T extends Enum>(List<T> values, String key, T fallback) =>
      values.asNameMap()[json[key]] ?? fallback;
  String spoken(String key) {
    final stored = json[key];
    return stored is String && isSupportedSpokenLanguage(stored) ? stored : fallbackSpokenLanguage;
  }

  // Never set means the default; set to nothing means none.
  Hotkey? hotkey(HotkeyAction action) {
    final fallback = AppSettings.defaultHotkeys[action];
    return switch (json['${action.name}Hotkey']) {
      '' => null,
      final String value => Hotkey.decode(value) ?? fallback,
      _ => fallback,
    };
  }

  final target = json['targetLanguage'];
  final interface = json['interfaceLanguage'];
  final threads = json['cpuThreads'];
  return AppSettings(
    captureRouted: flag('captureRouted', fresh.captureRouted),
    targetLanguage: target is String && dubbingLanguages.contains(target)
        ? target
        : dubbingLanguages.first,
    originalVolume: number('originalVolume', fresh.originalVolume),
    duckWhileSpeaking: flag('duckWhileSpeaking', fresh.duckWhileSpeaking),
    hurryWhenQueued: flag('hurryWhenQueued', fresh.hurryWhenQueued),
    roughRecognition: flag('roughRecognition', fresh.roughRecognition),
    ttsSpeed: number('ttsSpeed', fresh.ttsSpeed),
    cpuThreads: threads is int ? threads : defaultThreads,
    // Builds before the frame could be drawn stored only its top, the top
    // of a full-width band; the other edges then default to that band.
    ocrRegion: OcrRegion(
      left: number('ocrRegionLeft', OcrRegion.standard.left),
      top: number('ocrRegionTop', OcrRegion.standard.top),
      right: number('ocrRegionRight', OcrRegion.standard.right),
      bottom: number('ocrRegionBottom', OcrRegion.standard.bottom),
    ).normalized(),
    modelProxyUrl: text('modelProxyUrl', fresh.modelProxyUrl),
    audioCaptureSource: named(
      AudioCaptureSource.values,
      'audioCaptureSource',
      fresh.audioCaptureSource,
    ),
    screenSource: named(ScreenSource.values, 'screenSource', fresh.screenSource),
    pythonExecutable: text('pythonExecutable', bundledPython),
    detectSourceLanguage: flag('detectSourceLanguage', fresh.detectSourceLanguage),
    // A code stored by an older build, or one whose entry has since been
    // removed, must not reach whisper.cpp as an unknown argument.
    sourceLanguage: spoken('sourceLanguage'),
    // Builds before the screen had a language of its own read it off the
    // game's; without the key the screen reads English, as it does unless
    // told otherwise.
    screenLanguage: spoken('screenLanguage'),
    interfaceLanguage: interface is String && interfaceLanguages.contains(interface)
        ? interface
        : defaultInterfaceLanguage,
    interfaceScale: number('interfaceScale', fresh.interfaceScale),
    interfaceTheme: named(InterfaceTheme.values, 'interfaceTheme', fresh.interfaceTheme),
    whisperModel: text('whisperModel', fresh.whisperModel),
    automaticVoice: flag('automaticVoice', fresh.automaticVoice),
    voice: text('voice', fresh.voice),
    originalVoice: flag('originalVoice', fresh.originalVoice),
    voiceBank: flag('voiceBank', fresh.voiceBank),
    overlapVoices: flag('overlapVoices', fresh.overlapVoices),
    hotkeys: {
      for (final action in HotkeyAction.values) action: ?hotkey(action),
    },
    showFrameOverlay: flag('showFrameOverlay', fresh.showFrameOverlay),
    screenVoices: flag('screenVoices', fresh.screenVoices),
    computeDevice: named(ComputeDevice.values, 'computeDevice', fresh.computeDevice),
    // A pin written by a build that offered more backends than this one
    // must not survive as a value no stage can resolve.
    pinned: {
      for (final stage in ComputeStage.values)
        stage: ?ComputeBackend.values.asNameMap()[json['${stage.name}Backend']],
    },
  );
}

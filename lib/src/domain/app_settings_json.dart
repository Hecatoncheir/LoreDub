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
  final stored = _Stored(json);
  final targetLanguage = stored.oneOf('targetLanguage', dubbingLanguages, dubbingLanguages.first);
  return AppSettings(
    captureRouted: stored.flag('captureRouted', fresh.captureRouted),
    targetLanguage: targetLanguage,
    originalVolume: stored.number('originalVolume', fresh.originalVolume),
    duckWhileSpeaking: stored.flag('duckWhileSpeaking', fresh.duckWhileSpeaking),
    hurryWhenQueued: stored.flag('hurryWhenQueued', fresh.hurryWhenQueued),
    roughRecognition: stored.flag('roughRecognition', fresh.roughRecognition),
    ttsSpeed: stored.number('ttsSpeed', fresh.ttsSpeed),
    cpuThreads: stored.whole('cpuThreads', defaultThreads),
    ocrRegion: stored.ocrRegion,
    modelProxyUrl: stored.text('modelProxyUrl', fresh.modelProxyUrl),
    audioCaptureSource: stored.named(
      AudioCaptureSource.values,
      'audioCaptureSource',
      fresh.audioCaptureSource,
    ),
    screenSource: stored.named(ScreenSource.values, 'screenSource', fresh.screenSource),
    pythonExecutable: stored.text('pythonExecutable', bundledPython),
    detectSourceLanguage: stored.flag('detectSourceLanguage', fresh.detectSourceLanguage),
    // A code stored by an older build, or one whose entry has since been
    // removed, must not reach whisper.cpp as an unknown argument.
    sourceLanguage: stored.spoken('sourceLanguage'),
    // Builds before the screen had a language of its own read it off the
    // game's; without the key the screen reads English, as it does unless
    // told otherwise -- and so does it in anything but the dubbing
    // language, which is all its voice could read.
    screenLanguage: stored.oneOf(
      'screenLanguage',
      [fallbackSpokenLanguage, targetLanguage],
      fallbackSpokenLanguage,
    ),
    interfaceLanguage: stored.oneOf(
      'interfaceLanguage',
      interfaceLanguages,
      defaultInterfaceLanguage,
    ),
    interfaceScale: stored.number('interfaceScale', fresh.interfaceScale),
    interfaceTheme: stored.named(InterfaceTheme.values, 'interfaceTheme', fresh.interfaceTheme),
    whisperModel: stored.text('whisperModel', fresh.whisperModel),
    automaticVoice: stored.flag('automaticVoice', fresh.automaticVoice),
    voice: stored.text('voice', fresh.voice),
    originalVoice: stored.flag('originalVoice', fresh.originalVoice),
    voiceBank: stored.flag('voiceBank', fresh.voiceBank),
    overlapVoices: stored.flag('overlapVoices', fresh.overlapVoices),
    hotkeys: stored.hotkeys,
    showFrameOverlay: stored.flag('showFrameOverlay', fresh.showFrameOverlay),
    screenVoices: stored.flag('screenVoices', fresh.screenVoices),
    computeDevice: stored.named(ComputeDevice.values, 'computeDevice', fresh.computeDevice),
    pinned: stored.pinned,
  );
}

/// The stored object read a key at a time, each answering its fallback for a
/// key that is missing or holds what this build cannot read.
extension type const _Stored(Map<String, Object?> json) {
  bool flag(String key, bool fallback) => switch (json[key]) {
    final bool value => value,
    _ => fallback,
  };

  double number(String key, double fallback) => switch (json[key]) {
    final num value => value.toDouble(),
    _ => fallback,
  };

  int whole(String key, int fallback) => switch (json[key]) {
    final int value => value,
    _ => fallback,
  };

  String text(String key, String fallback) => switch (json[key]) {
    final String value => value,
    _ => fallback,
  };

  /// A code among [allowed], or [fallback] for one this build no longer has.
  String oneOf(String key, List<String> allowed, String fallback) => switch (json[key]) {
    final String value when allowed.contains(value) => value,
    _ => fallback,
  };

  T named<T extends Enum>(List<T> values, String key, T fallback) =>
      values.asNameMap()[json[key]] ?? fallback;

  String spoken(String key) => switch (json[key]) {
    final String value when isSupportedSpokenLanguage(value) => value,
    _ => fallbackSpokenLanguage,
  };

  /// Builds before the frame could be drawn stored only its top, the top of
  /// a full-width band; the other edges then default to that band.
  OcrRegion get ocrRegion => OcrRegion(
    left: number('ocrRegionLeft', OcrRegion.standard.left),
    top: number('ocrRegionTop', OcrRegion.standard.top),
    right: number('ocrRegionRight', OcrRegion.standard.right),
    bottom: number('ocrRegionBottom', OcrRegion.standard.bottom),
  ).normalized();

  Map<HotkeyAction, Hotkey> get hotkeys => {
    for (final action in HotkeyAction.values) action: ?_hotkey(action),
  };

  /// Never set means the default; set to nothing means none.
  Hotkey? _hotkey(HotkeyAction action) {
    final fallback = AppSettings.defaultHotkeys[action];
    return switch (json['${action.name}Hotkey']) {
      '' => null,
      final String value => Hotkey.decode(value) ?? fallback,
      _ => fallback,
    };
  }

  /// A pin written by a build that offered more backends than this one must
  /// not survive as a value no stage can resolve.
  Map<ComputeStage, ComputeBackend> get pinned => {
    for (final stage in ComputeStage.values)
      stage: ?ComputeBackend.values.asNameMap()[json['${stage.name}Backend']],
  };
}

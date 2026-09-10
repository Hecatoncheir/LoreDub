// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'spoken_language.dart';

enum CaptureMode { audio, ocr }

enum AudioCaptureSource { process, system }

class AppSettings {
  const AppSettings({
    this.captureMode = CaptureMode.audio,
    this.targetLanguage = 'ru',
    this.originalVolume = 0.18,
    this.ttsSpeed = 1.12,
    this.cpuThreads = 4,
    this.showOverlay = true,
    this.ocrRegionTop = 0.55,
    this.modelProxyUrl = '',
    this.audioCaptureSource = AudioCaptureSource.process,
    this.pythonExecutable = '',
    this.detectSourceLanguage = true,
    this.sourceLanguage = fallbackSpokenLanguage,
  });

  final CaptureMode captureMode;

  /// Reserved for future language packs. Only Russian output is packaged, so
  /// nothing reads this value yet.
  final String targetLanguage;
  final double originalVolume;

  /// Playback rate of the synthesized speech, applied by the inference worker.
  final double ttsSpeed;
  final int cpuThreads;

  /// TODO: реализовать в будущем отображение переведённых субтитров поверх
  /// игры. Пока значение только сохраняется и ни на что не влияет.
  final bool showOverlay;
  final double ocrRegionTop;
  final String modelProxyUrl;
  final AudioCaptureSource audioCaptureSource;
  final String pythonExecutable;

  /// Whether whisper.cpp guesses the language of the game itself.
  final bool detectSourceLanguage;

  /// The language to expect while [detectSourceLanguage] is off.
  final String sourceLanguage;

  /// What whisper.cpp should be told to expect.
  String get effectiveSourceLanguage => detectSourceLanguage ? autoSpokenLanguage : sourceLanguage;

  AppSettings copyWith({
    CaptureMode? captureMode,
    String? targetLanguage,
    double? originalVolume,
    double? ttsSpeed,
    int? cpuThreads,
    bool? showOverlay,
    double? ocrRegionTop,
    String? modelProxyUrl,
    AudioCaptureSource? audioCaptureSource,
    String? pythonExecutable,
    bool? detectSourceLanguage,
    String? sourceLanguage,
  }) => AppSettings(
    captureMode: captureMode ?? this.captureMode,
    targetLanguage: targetLanguage ?? this.targetLanguage,
    originalVolume: originalVolume ?? this.originalVolume,
    ttsSpeed: ttsSpeed ?? this.ttsSpeed,
    cpuThreads: cpuThreads ?? this.cpuThreads,
    showOverlay: showOverlay ?? this.showOverlay,
    ocrRegionTop: ocrRegionTop ?? this.ocrRegionTop,
    modelProxyUrl: modelProxyUrl ?? this.modelProxyUrl,
    audioCaptureSource: audioCaptureSource ?? this.audioCaptureSource,
    pythonExecutable: pythonExecutable ?? this.pythonExecutable,
    detectSourceLanguage: detectSourceLanguage ?? this.detectSourceLanguage,
    sourceLanguage: sourceLanguage ?? this.sourceLanguage,
  );
}

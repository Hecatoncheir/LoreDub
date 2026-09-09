// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

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
  });

  final CaptureMode captureMode;
  final String targetLanguage;
  final double originalVolume;
  final double ttsSpeed;
  final int cpuThreads;
  final bool showOverlay;
  final double ocrRegionTop;
  final String modelProxyUrl;
  final AudioCaptureSource audioCaptureSource;
  final String pythonExecutable;

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
  );
}

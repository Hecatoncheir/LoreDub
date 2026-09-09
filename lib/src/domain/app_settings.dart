// Copyright (c) 2026 GameLingo contributors.
// SPDX-License-Identifier: MIT

enum CaptureMode { audio, ocr }

class AppSettings {
  const AppSettings({
    this.captureMode = CaptureMode.audio,
    this.targetLanguage = 'ru',
    this.originalVolume = 0.18,
    this.ttsSpeed = 1.12,
    this.cpuThreads = 4,
    this.showOverlay = true,
  });

  final CaptureMode captureMode;
  final String targetLanguage;
  final double originalVolume;
  final double ttsSpeed;
  final int cpuThreads;
  final bool showOverlay;

  AppSettings copyWith({
    CaptureMode? captureMode,
    String? targetLanguage,
    double? originalVolume,
    double? ttsSpeed,
    int? cpuThreads,
    bool? showOverlay,
  }) => AppSettings(
    captureMode: captureMode ?? this.captureMode,
    targetLanguage: targetLanguage ?? this.targetLanguage,
    originalVolume: originalVolume ?? this.originalVolume,
    ttsSpeed: ttsSpeed ?? this.ttsSpeed,
    cpuThreads: cpuThreads ?? this.cpuThreads,
    showOverlay: showOverlay ?? this.showOverlay,
  );
}

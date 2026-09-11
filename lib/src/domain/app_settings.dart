// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'compute_device.dart';
import 'ocr_region.dart';
import 'spoken_language.dart';

enum CaptureMode { audio, ocr }

enum AudioCaptureSource { process, system }

/// How the dubbing voice is picked, as the interface offers it. What is
/// stored is [AppSettings.automaticVoice] and [AppSettings.originalVoice].
enum VoiceMode { automatic, chosen, original }

class AppSettings {
  const AppSettings({
    this.captureMode = CaptureMode.audio,
    this.targetLanguage = 'ru',
    this.originalVolume = 0.18,
    this.ttsSpeed = 1.12,
    this.cpuThreads = 4,
    this.showOverlay = true,
    this.ocrRegion = OcrRegion.standard,
    this.modelProxyUrl = '',
    this.audioCaptureSource = AudioCaptureSource.process,
    this.pythonExecutable = '',
    this.detectSourceLanguage = true,
    this.sourceLanguage = fallbackSpokenLanguage,
    this.interfaceLanguage = defaultInterfaceLanguage,
    this.whisperModel = '',
    this.automaticVoice = true,
    this.voice = '',
    this.originalVoice = false,
    this.voiceBank = false,
    this.computeDevice = ComputeDevice.auto,
    this.recognitionBackend,
    this.translationBackend,
    this.speechBackend,
    this.voiceConversionBackend,
  });

  final CaptureMode captureMode;

  /// Reserved for future language packs. Only Russian output is packaged, so
  /// nothing reads this value yet.
  final String targetLanguage;
  final double originalVolume;

  /// Playback rate of the synthesized speech, applied by the inference worker.
  final double ttsSpeed;
  final int cpuThreads;

  /// TODO: draw the translated lines over the game. Persisted, but nothing
  /// reads it yet.
  final bool showOverlay;

  /// The part of the game window subtitle mode reads.
  final OcrRegion ocrRegion;
  final String modelProxyUrl;
  final AudioCaptureSource audioCaptureSource;
  final String pythonExecutable;

  /// Whether whisper.cpp guesses the language of the game itself.
  final bool detectSourceLanguage;

  /// The language to expect while [detectSourceLanguage] is off.
  final String sourceLanguage;

  /// Language of the interface itself, independent of what is being dubbed.
  final String interfaceLanguage;

  /// Which whisper.cpp model recognition uses, by catalogue id. Empty means
  /// the one the catalogue lists first, which is the smallest.
  final String whisperModel;

  /// Whether the voice follows the original speaker, phrase by phrase, from
  /// the pitch of the captured audio.
  final bool automaticVoice;

  /// The voice to read every line in while [automaticVoice] is off. Empty
  /// means the one the catalogue names for the language.
  final String voice;

  /// Whether each line is also re-voiced in the timbre of the phrase it
  /// answers, over the Silero voice picked the usual way.
  final bool originalVoice;

  /// Whether the original voice keeps a fingerprint of every character it
  /// meets, per game and across sessions, and voices their later lines with
  /// it. Off, the timbre is taken from each line afresh and never stored.
  final bool voiceBank;

  VoiceMode get voiceMode => originalVoice
      ? VoiceMode.original
      : automaticVoice
      ? VoiceMode.automatic
      : VoiceMode.chosen;

  /// Switches the voice mode. The original voice keeps [automaticVoice] as
  /// it was: it only decides the base voice under the original's timbre.
  AppSettings withVoiceMode(VoiceMode mode) => switch (mode) {
    VoiceMode.automatic => copyWith(automaticVoice: true, originalVoice: false),
    VoiceMode.chosen => copyWith(automaticVoice: false, originalVoice: false),
    VoiceMode.original => copyWith(originalVoice: true),
  };

  /// What the user asked the pipeline to run on, as a whole.
  final ComputeDevice computeDevice;

  /// What a single stage was pinned to, overriding [computeDevice].
  ///
  /// Null means the stage follows the preset. Speech has an entry only for
  /// symmetry: torch offers it nothing but the CPU on Windows today.
  final ComputeBackend? recognitionBackend;
  final ComputeBackend? translationBackend;
  final ComputeBackend? speechBackend;
  final ComputeBackend? voiceConversionBackend;

  ComputeBackend? backendOverride(ComputeStage stage) => switch (stage) {
    ComputeStage.recognition => recognitionBackend,
    ComputeStage.translation => translationBackend,
    ComputeStage.speech => speechBackend,
    ComputeStage.voiceConversion => voiceConversionBackend,
  };

  /// What a stage will actually run on, given what the machine offers.
  ComputeBackend backendFor(ComputeStage stage, ComputeAvailability availability) =>
      resolveComputeBackend(
        stage: stage,
        device: computeDevice,
        availability: availability,
        override: backendOverride(stage),
      );

  /// Pins one stage, leaving the others as they were.
  AppSettings withBackend(ComputeStage stage, ComputeBackend backend) => switch (stage) {
    ComputeStage.recognition => copyWith(recognitionBackend: backend),
    ComputeStage.translation => copyWith(translationBackend: backend),
    ComputeStage.speech => copyWith(speechBackend: backend),
    ComputeStage.voiceConversion => copyWith(voiceConversionBackend: backend),
  };

  /// Applies a preset, dropping every per-stage pin so the preset is what the
  /// interface then shows.
  AppSettings withComputeDevice(ComputeDevice device) => copyWith(
    computeDevice: device,
    clearBackendOverrides: true,
  );

  /// What whisper.cpp should be told to expect.
  String get effectiveSourceLanguage => detectSourceLanguage ? autoSpokenLanguage : sourceLanguage;

  AppSettings copyWith({
    CaptureMode? captureMode,
    String? targetLanguage,
    double? originalVolume,
    double? ttsSpeed,
    int? cpuThreads,
    bool? showOverlay,
    OcrRegion? ocrRegion,
    String? modelProxyUrl,
    AudioCaptureSource? audioCaptureSource,
    String? pythonExecutable,
    bool? detectSourceLanguage,
    String? sourceLanguage,
    String? interfaceLanguage,
    String? whisperModel,
    bool? automaticVoice,
    String? voice,
    bool? originalVoice,
    bool? voiceBank,
    ComputeDevice? computeDevice,
    ComputeBackend? recognitionBackend,
    ComputeBackend? translationBackend,
    ComputeBackend? speechBackend,
    ComputeBackend? voiceConversionBackend,
    bool clearBackendOverrides = false,
  }) => AppSettings(
    captureMode: captureMode ?? this.captureMode,
    targetLanguage: targetLanguage ?? this.targetLanguage,
    originalVolume: originalVolume ?? this.originalVolume,
    ttsSpeed: ttsSpeed ?? this.ttsSpeed,
    cpuThreads: cpuThreads ?? this.cpuThreads,
    showOverlay: showOverlay ?? this.showOverlay,
    ocrRegion: ocrRegion ?? this.ocrRegion,
    modelProxyUrl: modelProxyUrl ?? this.modelProxyUrl,
    audioCaptureSource: audioCaptureSource ?? this.audioCaptureSource,
    pythonExecutable: pythonExecutable ?? this.pythonExecutable,
    detectSourceLanguage: detectSourceLanguage ?? this.detectSourceLanguage,
    sourceLanguage: sourceLanguage ?? this.sourceLanguage,
    interfaceLanguage: interfaceLanguage ?? this.interfaceLanguage,
    whisperModel: whisperModel ?? this.whisperModel,
    automaticVoice: automaticVoice ?? this.automaticVoice,
    voice: voice ?? this.voice,
    originalVoice: originalVoice ?? this.originalVoice,
    voiceBank: voiceBank ?? this.voiceBank,
    computeDevice: computeDevice ?? this.computeDevice,
    recognitionBackend: clearBackendOverrides
        ? null
        : recognitionBackend ?? this.recognitionBackend,
    translationBackend: clearBackendOverrides
        ? null
        : translationBackend ?? this.translationBackend,
    speechBackend: clearBackendOverrides ? null : speechBackend ?? this.speechBackend,
    voiceConversionBackend: clearBackendOverrides
        ? null
        : voiceConversionBackend ?? this.voiceConversionBackend,
  );
}

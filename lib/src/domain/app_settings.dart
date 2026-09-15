// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'compute_device.dart';
import 'hotkey.dart';

export 'hotkey.dart';
import 'ocr_region.dart';
import 'spoken_language.dart';

enum AudioCaptureSource { process, system }

/// Where the screen session takes its text from: the window of the game it
/// was given, or everything the monitors show.
///
/// The window is the better of the two where it works -- text is read only
/// while the game is in front, so LoreDub's own window over it cannot pass
/// for subtitles -- but a game that keeps no ordinary window, or a launcher
/// or a browser beside it, is only readable off the screen itself.
enum ScreenSource { gameWindow, wholeScreen }

/// How the dubbing voice is picked, as the interface offers it. What is
/// stored is [AppSettings.automaticVoice] and [AppSettings.originalVoice].
enum VoiceMode { automatic, chosen, original }

class AppSettings {
  const AppSettings({
    this.captureRouted = true,
    this.targetLanguage = 'ru',
    this.originalVolume = 0.18,
    this.duckWhileSpeaking = true,
    this.silenceWhileReading = false,
    this.hurryWhenQueued = true,
    this.roughRecognition = false,
    this.ttsSpeed = 1.12,
    this.cpuThreads = 4,
    this.showOverlay = true,
    this.ocrRegion = OcrRegion.standard,
    this.modelProxyUrl = '',
    this.audioCaptureSource = AudioCaptureSource.process,
    this.screenSource = ScreenSource.gameWindow,
    this.pythonExecutable = '',
    this.detectSourceLanguage = true,
    this.sourceLanguage = fallbackSpokenLanguage,
    this.screenLanguage = fallbackSpokenLanguage,
    this.interfaceLanguage = defaultInterfaceLanguage,
    this.interfaceScale = 1,
    this.whisperModel = '',
    this.automaticVoice = true,
    this.voice = '',
    this.originalVoice = false,
    this.voiceBank = true,
    this.overlapVoices = true,
    this.pauseHotkey = Hotkey.defaultPause,
    this.resumeHotkey = Hotkey.defaultResume,
    this.snapshotHotkey = Hotkey.defaultSnapshot,
    this.frameHotkey = Hotkey.defaultFrame,
    this.computeDevice = ComputeDevice.auto,
    this.recognitionBackend,
    this.translationBackend,
    this.speechBackend,
    this.voiceConversionBackend,
  });

  /// Whether the capture is wired into the pipeline at all. Taken apart on
  /// the graph nothing is fed to the stages: the session cannot start until
  /// a link is drawn back.
  final bool captureRouted;

  /// Reserved for future language packs. Only Russian output is packaged, so
  /// nothing reads this value yet.
  final String targetLanguage;
  final double originalVolume;

  /// Whether the game is turned down only while the translation speaks,
  /// rather than from the start of the session to its end. Off, music and
  /// effects stay under the dubbing the whole evening; on, they play at
  /// their own volume between lines and step aside for each one.
  final bool duckWhileSpeaking;

  /// Whether the game is silenced outright while the screen is read.
  ///
  /// Only that session can offer it: it takes its text from the subtitle
  /// frame and listens to no sound at all, so nothing is lost by turning the
  /// game off -- and what is gained is not hearing the game speak a line the
  /// dubbing is reading at the same moment. Live dubbing has its ear in the
  /// game's own sound and is held above [audibleDuck] whatever is set here.
  final bool silenceWhileReading;

  /// Whether a line is read faster while others are already waiting for the
  /// voice. Off, every line is read at the pace the player set, and a queue
  /// is simply time spent further behind the game.
  final bool hurryWhenQueued;

  /// Whether whisper is asked to listen to a shortened stretch of sound.
  ///
  /// Recognition is the larger half of the delay before a line is heard, and
  /// nearly all of it is the encoder, which works over a fixed window
  /// whatever the phrase is worth. Shortening the window is the one knob that
  /// moved it: over nine clips it took 897 ms against 1329, and the words
  /// came back the same on all nine, two of them differing by a comma. It is
  /// off by default because the cost is paid on the phrases that were already
  /// hard -- shortened further, whisper began repeating itself.
  final bool roughRecognition;

  /// The loudest the game is left while it is dubbed. Past this it talks
  /// over the translation rather than under it.
  static const loudestDuck = 0.5;

  /// The quietest the game may be put while its own sound is what the
  /// pipeline listens to, and the floor both volume sliders stop at.
  ///
  /// Windows takes the process-loopback tap after the session volume, so
  /// turning the game down turns the capture down with it: measured against
  /// a tone of raw peak 2614, half volume gave 1308, 18% gave 472, and zero
  /// gave nothing at all — not one segment in eight seconds. Silenced
  /// outright the pipeline would listen to silence and never dub a word, and
  /// since capture decides what is speech from this same ducked signal, the
  /// quiet lines of a game are lost well before zero.
  static const audibleDuck = 0.1;

  /// The step both volume sliders move in, so a number set on the graph is
  /// one the settings screen can set again.
  static const duckStep = 0.02;

  /// What the game is actually turned down to while it is being listened
  /// to: [originalVolume] held to what the capture can still hear.
  double get duckedVolume => originalVolume.clamp(audibleDuck, loudestDuck);

  /// What the game is turned down to while the screen is read instead --
  /// the same number, or silence when the player asked for it.
  double get silentDuckedVolume => silenceWhileReading ? 0 : duckedVolume;

  /// The notches of a volume slider, from the range it may cover.
  static int get duckDivisions => ((loudestDuck - audibleDuck) / duckStep).round();

  /// The pace the dubbing is read at by the player's own hand. Slower than
  /// [slowestSpeech] it drags behind its own words; faster than
  /// [fastestSpeech] it is heard but no longer followed. A queue may still
  /// hurry a line past the top — that is the moment's doing, not a setting.
  static const slowestSpeech = 0.9;
  static const fastestSpeech = 1.35;
  static const speechStep = 0.025;

  /// The notches of a speed slider, so the two screens agree on them.
  static int get speechDivisions => ((fastestSpeech - slowestSpeech) / speechStep).round();

  /// The pace the player chose, held to the range both screens offer.
  double get chosenSpeed => ttsSpeed.clamp(slowestSpeech, fastestSpeech);

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
  final ScreenSource screenSource;

  /// Whether the frame is measured against the whole screen rather than
  /// against one window -- which is also whether a game has to be named
  /// before the reading can start.
  bool get readsWholeScreen => screenSource == ScreenSource.wholeScreen;
  final String pythonExecutable;

  /// Whether whisper.cpp guesses the language of the game itself.
  final bool detectSourceLanguage;

  /// The language to expect while [detectSourceLanguage] is off.
  final String sourceLanguage;

  /// Language of the interface itself, independent of what is being dubbed.
  final String interfaceLanguage;

  /// How much larger or smaller the whole interface is drawn.
  ///
  /// Windows has a scale of its own, and a player who reads the screen from
  /// across the room has already set it; this is the application's own,
  /// because the dubbing window often sits beside a game that fixed the
  /// resolution, and the system setting is not worth changing for one
  /// window. Held to [smallestScale]..[largestScale] by [chosenScale].
  final double interfaceScale;

  /// Smaller than this the process names and the times are no longer read;
  /// larger, the node canvas has nowhere left to draw a scheme.
  static const smallestScale = 0.8;
  static const largestScale = 1.4;
  static const scaleStep = 0.05;
  static int get scaleDivisions => ((largestScale - smallestScale) / scaleStep).round();

  /// What the interface is actually drawn at: a stored value from another
  /// build, or one written by hand, held to what the screen can carry.
  double get chosenScale => interfaceScale.clamp(smallestScale, largestScale);

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

  /// Whether a line of another character may start while the current one is
  /// still being spoken. A character never talks over themselves either way.
  final bool overlapVoices;

  /// The system-wide combinations that pause and resume a running session;
  /// null leaves the action to its button.
  final Hotkey? pauseHotkey;
  final Hotkey? resumeHotkey;

  /// The combination held down to select an area of the screen to translate
  /// once; null leaves the snapshot screen without a way to select.
  final Hotkey? snapshotHotkey;

  /// Held over the running game to draw the subtitle frame where the game
  /// actually writes, instead of guessing at it on a picture of the screen.
  final Hotkey? frameHotkey;

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

  /// What the screen session reads: English, or the dubbing language
  /// itself, which is then voiced as it is rather than translated.
  ///
  /// Its own setting rather than [sourceLanguage] read a second way. The
  /// two were one field, so naming the screen's text as Russian named the
  /// game's speech as Russian too -- and the graph, which draws the dubbing
  /// of sound and nothing else, redrew its translator around a choice made
  /// on another page.
  final String screenLanguage;

  /// The same, held to what the pair of models can actually do: Windows OCR
  /// detects nothing and the translators read only English, so anything but
  /// the dubbing language itself is English.
  String get textLanguage =>
      screenLanguage == targetLanguage ? targetLanguage : fallbackSpokenLanguage;

  /// What whisper.cpp should be told to expect.
  String get effectiveSourceLanguage => detectSourceLanguage ? autoSpokenLanguage : sourceLanguage;

  AppSettings copyWith({
    bool? captureRouted,
    String? targetLanguage,
    double? originalVolume,
    bool? duckWhileSpeaking,
    bool? silenceWhileReading,
    bool? hurryWhenQueued,
    bool? roughRecognition,
    double? ttsSpeed,
    int? cpuThreads,
    bool? showOverlay,
    OcrRegion? ocrRegion,
    String? modelProxyUrl,
    AudioCaptureSource? audioCaptureSource,
    ScreenSource? screenSource,
    String? pythonExecutable,
    bool? detectSourceLanguage,
    String? sourceLanguage,
    String? screenLanguage,
    String? interfaceLanguage,
    double? interfaceScale,
    String? whisperModel,
    bool? automaticVoice,
    String? voice,
    bool? originalVoice,
    bool? voiceBank,
    bool? overlapVoices,
    Hotkey? pauseHotkey,
    bool clearPauseHotkey = false,
    Hotkey? resumeHotkey,
    bool clearResumeHotkey = false,
    Hotkey? snapshotHotkey,
    bool clearSnapshotHotkey = false,
    Hotkey? frameHotkey,
    bool clearFrameHotkey = false,
    ComputeDevice? computeDevice,
    ComputeBackend? recognitionBackend,
    ComputeBackend? translationBackend,
    ComputeBackend? speechBackend,
    ComputeBackend? voiceConversionBackend,
    bool clearBackendOverrides = false,
  }) => AppSettings(
    captureRouted: captureRouted ?? this.captureRouted,
    targetLanguage: targetLanguage ?? this.targetLanguage,
    originalVolume: originalVolume ?? this.originalVolume,
    duckWhileSpeaking: duckWhileSpeaking ?? this.duckWhileSpeaking,
    silenceWhileReading: silenceWhileReading ?? this.silenceWhileReading,
    hurryWhenQueued: hurryWhenQueued ?? this.hurryWhenQueued,
    roughRecognition: roughRecognition ?? this.roughRecognition,
    ttsSpeed: ttsSpeed ?? this.ttsSpeed,
    cpuThreads: cpuThreads ?? this.cpuThreads,
    showOverlay: showOverlay ?? this.showOverlay,
    ocrRegion: ocrRegion ?? this.ocrRegion,
    modelProxyUrl: modelProxyUrl ?? this.modelProxyUrl,
    audioCaptureSource: audioCaptureSource ?? this.audioCaptureSource,
    screenSource: screenSource ?? this.screenSource,
    pythonExecutable: pythonExecutable ?? this.pythonExecutable,
    detectSourceLanguage: detectSourceLanguage ?? this.detectSourceLanguage,
    sourceLanguage: sourceLanguage ?? this.sourceLanguage,
    screenLanguage: screenLanguage ?? this.screenLanguage,
    interfaceLanguage: interfaceLanguage ?? this.interfaceLanguage,
    interfaceScale: interfaceScale ?? this.interfaceScale,
    whisperModel: whisperModel ?? this.whisperModel,
    automaticVoice: automaticVoice ?? this.automaticVoice,
    voice: voice ?? this.voice,
    originalVoice: originalVoice ?? this.originalVoice,
    voiceBank: voiceBank ?? this.voiceBank,
    overlapVoices: overlapVoices ?? this.overlapVoices,
    pauseHotkey: clearPauseHotkey ? null : pauseHotkey ?? this.pauseHotkey,
    resumeHotkey: clearResumeHotkey ? null : resumeHotkey ?? this.resumeHotkey,
    snapshotHotkey: clearSnapshotHotkey ? null : snapshotHotkey ?? this.snapshotHotkey,
    frameHotkey: clearFrameHotkey ? null : frameHotkey ?? this.frameHotkey,
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

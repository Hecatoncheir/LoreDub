// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'app_settings.dart';
import 'compute_device.dart';
import 'ocr_region.dart';
import 'pipeline_state.dart';
import 'spoken_language.dart';

/// The models a worker loads, by what each is for. A session loads only the
/// ones it names.
class ModelPaths {
  const ModelPaths({this.whisper, this.translation, this.speech, this.converter});

  /// The recognition model's file.
  final String? whisper;

  /// The translator's directory; none where the dubbing is into English
  /// and whisper handed English over already.
  final String? translation;

  /// The voice package's first file: `model.onnx`, or the config of a
  /// voice that clones.
  final String? speech;

  /// The OpenVoice converter's directory, which is also what hears who is
  /// speaking.
  final String? converter;
}

/// Where each of the worker's stages runs.
class StageBackends {
  const StageBackends({
    this.recognition = ComputeBackend.cpu,
    this.translation = ComputeBackend.cpu,
    this.speech = ComputeBackend.cpu,
    this.voiceConversion = ComputeBackend.cpu,
    this.languageModel = ComputeBackend.cpu,
  });

  /// Where each stage will run under [settings], given what the machine
  /// offers.
  StageBackends.resolved(AppSettings settings, ComputeAvailability availability)
    : recognition = settings.backendFor(ComputeStage.recognition, availability),
      translation = settings.backendFor(ComputeStage.translation, availability),
      speech = settings.backendFor(ComputeStage.speech, availability),
      voiceConversion = settings.backendFor(ComputeStage.voiceConversion, availability),
      languageModel = settings.backendFor(ComputeStage.languageModel, availability);

  final ComputeBackend recognition;
  final ComputeBackend translation;
  final ComputeBackend speech;
  final ComputeBackend voiceConversion;

  /// Where a translator that is a language model runs: llama.cpp's own
  /// builds rather than the worker's torch.
  final ComputeBackend languageModel;
}

/// What the Python worker is started with.
class WorkerPlan {
  const WorkerPlan({
    required this.threads,
    required this.pythonExecutable,
    required this.runtimeDirectory,
    this.models = const ModelPaths(),
    this.backends = const StageBackends(),
    this.speaker = '',
    this.speed = 1,
    this.sourceLanguage = autoSpokenLanguage,
    this.targetLanguage = 'ru',
    this.translationPrefix = '',
    this.languageModel = false,
    this.chatTemplate = '',
    this.followSpeaker = false,
    this.revoice = false,
    this.maleVoices = const [],
    this.femaleVoices = const [],
    this.voiceBank,
    this.characters,
    this.glossary,
    this.asHeard = const {},
  });

  /// A worker started the way [settings] say: its threads, its
  /// interpreter, the player's pace and the language the dubbing is in.
  /// What it loads is the caller's.
  WorkerPlan.under(
    AppSettings settings, {
    required String runtimeDirectory,
    ModelPaths models = const ModelPaths(),
    StageBackends backends = const StageBackends(),
    String speaker = '',
    String sourceLanguage = autoSpokenLanguage,
    String translationPrefix = '',
    bool languageModel = false,
    String chatTemplate = '',
    bool followSpeaker = false,
    bool revoice = false,
    List<String> maleVoices = const [],
    List<String> femaleVoices = const [],
    String? voiceBank,
  }) : this(
         threads: settings.cpuThreads,
         pythonExecutable: settings.pythonExecutable,
         runtimeDirectory: runtimeDirectory,
         models: models,
         backends: backends,
         speaker: speaker,
         speed: settings.chosenSpeed,
         sourceLanguage: sourceLanguage,
         targetLanguage: settings.targetLanguage,
         translationPrefix: translationPrefix,
         languageModel: languageModel,
         chatTemplate: chatTemplate,
         followSpeaker: followSpeaker,
         revoice: revoice,
         maleVoices: maleVoices,
         femaleVoices: femaleVoices,
         voiceBank: voiceBank,
       );

  final int threads;
  final String pythonExecutable;

  /// Where the downloaded GPU runtimes were unpacked.
  final String runtimeDirectory;
  final ModelPaths models;
  final StageBackends backends;

  /// The voice a line is read in where nothing chooses another.
  final String speaker;
  final double speed;

  /// What whisper is told the game speaks, or [autoSpokenLanguage].
  final String sourceLanguage;

  /// The language the dubbing is in, which a voice that clones and a
  /// translator that is a language model are both told by name.
  final String targetLanguage;

  /// The target token a multi-target translator wants before the text.
  final String translationPrefix;

  /// Whether the translator named in [models] is a language model, run by
  /// llama.cpp's server on the language-model backend, rather than Marian.
  final bool languageModel;

  /// The built-in chat template that server is told to use, or none.
  final String chatTemplate;

  /// Pick the voice per line from the gender heard in it.
  final bool followSpeaker;

  /// Carry the original's timbre over, rather than only telling the
  /// characters apart.
  final bool revoice;
  final List<String> maleVoices;
  final List<String> femaleVoices;

  /// The game's voice bank file, where characters are remembered.
  final String? voiceBank;

  /// The player's own cast, which speaks in every game.
  final String? characters;

  /// The glossary the session translates with.
  final String? glossary;

  /// The cards the canvas cut out of the mix.
  final Set<String> asHeard;

  WorkerPlan copyWith({
    String? speaker,
    Set<String>? asHeard,
    String? characters,
    String? glossary,
  }) => WorkerPlan(
    threads: threads,
    pythonExecutable: pythonExecutable,
    runtimeDirectory: runtimeDirectory,
    models: models,
    backends: backends,
    speaker: speaker ?? this.speaker,
    speed: speed,
    sourceLanguage: sourceLanguage,
    targetLanguage: targetLanguage,
    translationPrefix: translationPrefix,
    languageModel: languageModel,
    chatTemplate: chatTemplate,
    followSpeaker: followSpeaker,
    revoice: revoice,
    maleVoices: maleVoices,
    femaleVoices: femaleVoices,
    voiceBank: voiceBank,
    characters: characters ?? this.characters,
    glossary: glossary ?? this.glossary,
    asHeard: asHeard ?? this.asHeard,
  );
}

/// What the native capture takes in, by the names `ld_start` knows it by.
enum CaptureMode {
  /// The game's sound, cut into phrases.
  audio,

  /// The subtitle frame, read by Windows OCR.
  ocr,

  /// The frame, with the game's sound beside it to place the speaker.
  ocrAndAudio,

  /// Nothing: the engine is up, and only the snapshot key is answered.
  none;

  bool get readsScreen => this == ocr || this == ocrAndAudio;
}

/// What `ld_start` captures: the one part of a session that crosses into
/// the native library, and so the one that is written out as flat JSON.
class CapturePlan {
  const CapturePlan({
    required this.mode,
    required this.processId,
    this.audioSource = AudioCaptureSource.process,
    this.wholeScreen = false,
    this.region = OcrRegion.standard,
    this.ocrLanguage = 'en',
  });

  final CaptureMode mode;

  /// The game: whose sound is taken, whose window the frame is read out
  /// of, and what is turned down. Zero where there is none.
  final int processId;
  final AudioCaptureSource audioSource;

  /// The frame is a share of the whole virtual screen rather than of the
  /// game's window.
  final bool wholeScreen;
  final OcrRegion region;
  final String ocrLanguage;

  /// Whether the capture cuts the game's sound into files, and so needs a
  /// directory to put them in.
  bool get cutsSound => mode == CaptureMode.audio || mode == CaptureMode.ocrAndAudio;

  CapturePlan withRegion(OcrRegion value) => CapturePlan(
    mode: mode,
    processId: processId,
    audioSource: audioSource,
    wholeScreen: wholeScreen,
    region: value,
    ocrLanguage: ocrLanguage,
  );

  /// The keys `ld_start` reads: flat, and string or number valued, since
  /// the native side parses them by hand.
  Map<String, Object?> toNativeJson({String? captureDirectory}) => {
    'processId': processId,
    'captureMode': mode.name,
    'audioSource': audioSource.name,
    'ocrSource': wholeScreen ? 'screen' : 'process',
    'ocrRegionLeft': region.left,
    'ocrRegionTop': region.top,
    'ocrRegionRight': region.right,
    'ocrRegionBottom': region.bottom,
    'ocrLanguage': ocrLanguage,
    'captureDirectory': ?captureDirectory,
  };
}

/// How each line of a dubbing session is read and heard.
class LineRules {
  const LineRules({
    required this.targetLanguage,
    this.textLanguage = 'en',
    this.translateSpeech = true,
    this.languageModel = false,
    this.roughRecognition = false,
    this.speed = 1,
    this.hurryWhenQueued = false,
    this.duckWhileSpeaking = false,
    this.duckVolume = 0.18,
    this.overlapVoices = false,
  });

  /// The language the dubbing speaks.
  final String targetLanguage;

  /// The language text read off the screen is in.
  final String textLanguage;

  /// Whether whisper translates what it hears into English.
  final bool translateSpeech;

  /// Whether the translator is a language model, which takes what whisper
  /// heard in the game's own language and translates from there.
  final bool languageModel;
  final bool roughRecognition;

  /// The player's own pace.
  final double speed;

  /// Read faster while lines queue for the voice.
  final bool hurryWhenQueued;

  /// Turn the game down for the length of a line rather than the session.
  final bool duckWhileSpeaking;
  final double duckVolume;

  /// Let two speakers' lines sound side by side.
  final bool overlapVoices;

  /// Whether what whisper hands over is translated at all. English from
  /// whisper into English is not; a language model is handed every line,
  /// with the language it was heard in, and leaves one already in the
  /// dubbing language as it is.
  bool get translatesHeard => languageModel || targetLanguage != untranslatedDubbingLanguage;

  /// Whether text read off the screen is translated, rather than voiced in
  /// the language it was written in.
  bool get translatesText => textLanguage != targetLanguage;
}

/// Everything one session is started with. Which kind it is decides what
/// the worker loads and what the capture takes in.
sealed class SessionConfig {
  const SessionConfig({required this.worker});

  final WorkerPlan worker;

  /// The session this start names on the events it sends.
  PipelineSession get session;

  /// What `ld_start` is handed, where the session captures anything.
  CapturePlan? get capture => null;

  /// How lines are read, where the session reads any.
  LineRules? get lines => null;

  /// The same session, reading in [voice] from now on.
  SessionConfig withSpeaker(String voice);

  /// The same session, with [cards] cut out of the mix.
  SessionConfig withAsHeard(Set<String> cards);

  /// The same session, reading the subtitle frame at [region].
  SessionConfig withRegion(OcrRegion region) => this;
}

/// Live dubbing: the game's sound recognized, translated and voiced.
final class LiveSessionConfig extends SessionConfig {
  const LiveSessionConfig({required super.worker, required this.capture, required this.lines});

  @override
  final CapturePlan capture;
  @override
  final LineRules lines;

  @override
  PipelineSession get session => PipelineSession.live;

  @override
  LiveSessionConfig withSpeaker(String voice) => LiveSessionConfig(
    worker: worker.copyWith(speaker: voice),
    capture: capture,
    lines: lines,
  );

  @override
  LiveSessionConfig withAsHeard(Set<String> cards) => LiveSessionConfig(
    worker: worker.copyWith(asHeard: cards),
    capture: capture,
    lines: lines,
  );
}

/// The screen read: the subtitle frame, the snippets, or both.
final class ScreenSessionConfig extends SessionConfig {
  const ScreenSessionConfig({required super.worker, required this.capture, required this.lines});

  @override
  final CapturePlan capture;
  @override
  final LineRules lines;

  @override
  PipelineSession get session => PipelineSession.screen;

  @override
  ScreenSessionConfig withSpeaker(String voice) => ScreenSessionConfig(
    worker: worker.copyWith(speaker: voice),
    capture: capture,
    lines: lines,
  );

  @override
  ScreenSessionConfig withAsHeard(Set<String> cards) => ScreenSessionConfig(
    worker: worker.copyWith(asHeard: cards),
    capture: capture,
    lines: lines,
  );

  @override
  ScreenSessionConfig withRegion(OcrRegion region) =>
      ScreenSessionConfig(worker: worker, capture: capture.withRegion(region), lines: lines);
}

/// The voices of a scene placed, with nothing dubbed.
final class SceneSessionConfig extends SessionConfig {
  const SceneSessionConfig({required super.worker, required this.capture});

  @override
  final CapturePlan capture;

  @override
  PipelineSession get session => PipelineSession.scene;

  @override
  SceneSessionConfig withSpeaker(String voice) => SceneSessionConfig(
    worker: worker.copyWith(speaker: voice),
    capture: capture,
  );

  @override
  SceneSessionConfig withAsHeard(Set<String> cards) => SceneSessionConfig(
    worker: worker.copyWith(asHeard: cards),
    capture: capture,
  );
}

/// A card recorded from the game.
final class CharactersSessionConfig extends SessionConfig {
  const CharactersSessionConfig({required super.worker, required this.capture});

  @override
  final CapturePlan capture;

  @override
  PipelineSession get session => PipelineSession.characters;

  @override
  CharactersSessionConfig withSpeaker(String voice) => CharactersSessionConfig(
    worker: worker.copyWith(speaker: voice),
    capture: capture,
  );

  @override
  CharactersSessionConfig withAsHeard(Set<String> cards) => CharactersSessionConfig(
    worker: worker.copyWith(asHeard: cards),
    capture: capture,
  );
}

/// A card measured from files already on disk: the converter and nothing
/// captured.
final class VoiceFilesSessionConfig extends SessionConfig {
  const VoiceFilesSessionConfig({required super.worker});

  @override
  PipelineSession get session => PipelineSession.characters;

  @override
  VoiceFilesSessionConfig withSpeaker(String voice) =>
      VoiceFilesSessionConfig(worker: worker.copyWith(speaker: voice));

  @override
  VoiceFilesSessionConfig withAsHeard(Set<String> cards) =>
      VoiceFilesSessionConfig(worker: worker.copyWith(asHeard: cards));
}

/// A sample of a card's voice: the speech model and the converter, nothing
/// captured.
final class PreviewSessionConfig extends SessionConfig {
  const PreviewSessionConfig({required super.worker});

  @override
  PipelineSession get session => PipelineSession.preview;

  @override
  PreviewSessionConfig withSpeaker(String voice) =>
      PreviewSessionConfig(worker: worker.copyWith(speaker: voice));

  @override
  PreviewSessionConfig withAsHeard(Set<String> cards) =>
      PreviewSessionConfig(worker: worker.copyWith(asHeard: cards));
}

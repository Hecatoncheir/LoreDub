// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/engine_event.dart';
import '../../domain/ocr_region.dart';
import '../../domain/screen_reading.dart';
import '../../domain/app_settings.dart';
import '../../domain/built_voice.dart';
import '../../domain/compute_device.dart';
import '../../domain/failure.dart';
import '../../domain/game_process.dart';
import '../../domain/session_config.dart';
import '../services/character_service.dart';
import '../services/glossary_service.dart';
import '../services/native_engine_service.dart';
import '../services/pipeline_graph_service.dart';

/// The one engine and the sessions it runs: starting and stopping them,
/// resting one, what it is told while it runs, and what it plays.
///
/// It was `AppRepository`, which held every file the application keeps
/// besides -- the cast, the glossary, the schemes, the voice banks -- and
/// what the machine has. Those are repositories of their own now. What a
/// start still reads for itself is three paths it writes into the config:
/// the glossary the session translates with, the cast it recognizes, and
/// the cards the canvas cut out of the mix. It reads them off the services
/// directly, which are only where the files are, rather than off the
/// repositories that own what is in them.
class SessionRepository {
  SessionRepository(
    this._nativeEngine, [
    CharacterService? characters,
    GlossaryService? glossary,
    PipelineGraphService? layout,
  ]) : _characters = characters ?? CharacterService(),
       _glossary = glossary ?? GlossaryService(),
       _layout = layout ?? PipelineGraphService();

  final NativeEngineService _nativeEngine;
  final CharacterService _characters;
  final GlossaryService _glossary;
  final PipelineGraphService _layout;

  /// Plays a file to its end, outside the dubbing's own queue: a clip the
  /// player asked to hear does not wait behind a scene.
  Future<void> playWave(String wavePath) => _nativeEngine.playWave(wavePath);

  /// Ends whatever is sounding.
  void stopWave() => _nativeEngine.stopWave();

  Stream<EngineEvent> get events => _nativeEngine.events;

  /// Goes up with every session asked for and with every stop, so a start
  /// that fails can tell whether the engine still holds the session it began
  /// — and so can whoever borrowed one and comes to put it down.
  var _sessions = 0;

  /// Clears away what the failed start numbered [session] left behind —
  /// while it is still that start's to clear.
  ///
  /// A start is minutes long, and the player may stop it and begin another
  /// before it ends. Its failure then arrives into a session it has nothing
  /// to do with, and stopping the engine for it ended whichever session was
  /// running by then. Nor has such a start anything to report: whatever it
  /// failed with, it failed after nobody wanted it, so it ends as stopped,
  /// which the screens pass over.
  Future<void> _endFailedStart(int session) async {
    _throwIfSuperseded(session);
    await _nativeEngine.stop();
  }

  /// Ends the start numbered [session] as stopped once a stop or a newer
  /// start has come after it.
  ///
  /// Asked before the engine is called and after every wait of a start's
  /// own. The config is written out first — the session's glossary, the
  /// cast, the cut read off the graph — and a stop landing in those waits
  /// found an engine with nothing to cancel, which then started a worker and
  /// a capture for a session already stopped; one landing once the engine
  /// was up had its hotkeys registered again and the game turned down.
  /// Thrown inside the start's `try`, it reaches [_endFailedStart], which
  /// leaves the engine alone: the stop has ended it already, and a newer
  /// start owns it.
  void _throwIfSuperseded(int session) {
    if (session != _sessions) throw const LoreDubFailure(FailureCode.pipelineStopped);
  }

  /// [modelDirectories] carries the three paths the pipeline needs for the
  /// chosen language: `whisper` and `translation` directories, and the
  /// `speech` model file, plus the `converter` directory when the original
  /// voice is on. [speaker] is the voice of that speech model.
  /// [runtimeDirectory] is where downloaded GPU runtimes were unpacked.
  /// [voiceBank] is the game's bank file, when characters are remembered.
  Future<void> start({
    required GameProcess? process,
    required AppSettings settings,
    required Map<String, String> modelDirectories,
    required String speaker,
    required String translationPrefix,
    required bool translateSpeech,
    required bool followSpeaker,

    /// Whether the converter carries the original's timbre over, rather than
    /// only telling the characters apart.
    required bool revoice,
    required List<String> maleVoices,
    required List<String> femaleVoices,
    required ComputeBackend recognitionBackend,
    required ComputeBackend translationBackend,
    required ComputeBackend speechBackend,
    required ComputeBackend voiceConversionBackend,
    required String runtimeDirectory,
    String? voiceBank,
  }) async {
    final session = ++_sessions;
    try {
      final config = LiveSessionConfig(
        worker: WorkerPlan(
          threads: settings.cpuThreads,
          pythonExecutable: settings.pythonExecutable,
          runtimeDirectory: runtimeDirectory,
          models: _modelPaths(modelDirectories),
          backends: StageBackends(
            recognition: recognitionBackend,
            translation: translationBackend,
            speech: speechBackend,
            voiceConversion: voiceConversionBackend,
          ),
          speaker: speaker,
          speed: settings.chosenSpeed,
          sourceLanguage: settings.effectiveSourceLanguage,
          translationPrefix: translationPrefix,
          followSpeaker: followSpeaker,
          revoice: revoice,
          maleVoices: maleVoices,
          femaleVoices: femaleVoices,
          voiceBank: voiceBank,
          glossary: await _glossary.sessionFile(),
          // The player's own characters, who speak in every game.
          characters: await _characters.file(),
          // The cards cut out of the mix on the graph: each of them keeps who
          // stands in for whom, and none of it is applied.
          asHeard: await _cutFromMix(),
        ),
        capture: CapturePlan(
          mode: CaptureMode.audio,
          processId: process?.pid ?? 0,
          audioSource: settings.audioCaptureSource,
        ),
        lines: LineRules(
          targetLanguage: settings.targetLanguage,
          textLanguage: settings.textLanguage,
          translateSpeech: translateSpeech,
          roughRecognition: settings.roughRecognition,
          speed: settings.chosenSpeed,
          hurryWhenQueued: settings.hurryWhenQueued,
          // What the game is turned down to, and whether that happens for
          // the length of a line rather than for the whole session.
          duckWhileSpeaking: settings.duckWhileSpeaking,
          duckVolume: settings.duckedVolume,
          overlapVoices: settings.overlapVoices,
        ),
      );
      _throwIfSuperseded(session);
      await _nativeEngine.start(config);
      _throwIfSuperseded(session);
      await _duck(process, settings);
      _throwIfSuperseded(session);
      _sessionProcess = process;
      _sessionSettings = settings;
      _nativeEngine.setHotkeys(
        pause: settings.pauseHotkey,
        resume: settings.resumeHotkey,
        snapshot: settings.snapshotHotkey,
        frameOverlay: settings.frameOverlayHotkey,
        textLanguage: settings.textLanguage,
      );
    } catch (_) {
      await _endFailedStart(session);
      rethrow;
    }
  }

  /// Starts the screen session: the translator, the voice, the frame the
  /// subtitles are read out of, and the snapshot key.
  ///
  /// The capture is Windows OCR over the game's window and nothing else --
  /// no sound is listened to -- so the game may be turned down as far as
  /// silence without taking the recognition with it.
  Future<void> startScreenText({
    required ScreenReading reading,
    required bool hearsVoices,
    required GameProcess? process,
    String? voiceBank,
    required AppSettings settings,
    required Map<String, String> modelDirectories,
    required String speaker,
    required String translationPrefix,
    required ComputeBackend translationBackend,
    required ComputeBackend speechBackend,
    required ComputeBackend converterBackend,
    required String runtimeDirectory,
  }) async {
    final session = ++_sessions;
    try {
      final config = ScreenSessionConfig(
        worker: WorkerPlan(
          threads: settings.cpuThreads,
          pythonExecutable: settings.pythonExecutable,
          runtimeDirectory: runtimeDirectory,
          models: _modelPaths(modelDirectories),
          backends: StageBackends(
            translation: translationBackend,
            speech: speechBackend,
            voiceConversion: converterBackend,
          ),
          speaker: speaker,
          speed: settings.chosenSpeed,
          translationPrefix: translationPrefix,
          // The voices are heard by the converter and carried over the
          // reading, so this session asks for the same two as the original
          // voice does -- and for the game's own bank, so a character met
          // here is the one the dubbing session knows.
          revoice: hearsVoices,
          voiceBank: voiceBank,
          glossary: await _glossary.sessionFile(),
          characters: await _characters.file(),
        ),
        capture: CapturePlan(
          mode: _captureModeOf(reading, hearsVoices: hearsVoices),
          // The window the frame is read out of, and the game whose sound is
          // followed. Named even when the screen is what is read: nothing is
          // taken out of that window then, but it is still the game to turn
          // down for the length of a line.
          processId: process?.pid ?? 0,
          wholeScreen: settings.readsWholeScreen,
          region: settings.ocrRegion,
          ocrLanguage: settings.textLanguage,
        ),
        lines: LineRules(
          targetLanguage: settings.targetLanguage,
          textLanguage: settings.textLanguage,
          speed: settings.chosenSpeed,
          hurryWhenQueued: settings.hurryWhenQueued,
          duckWhileSpeaking: settings.duckWhileSpeaking,
          duckVolume: settings.duckedVolume,
        ),
      );
      _throwIfSuperseded(session);
      await _nativeEngine.startScreenText(config);
      _throwIfSuperseded(session);
      await _duckScreen(process, settings);
      _throwIfSuperseded(session);
      _sessionProcess = process;
      _sessionSettings = settings;
      _nativeEngine.setHotkeys(
        snapshot: reading.readsSnippets ? settings.snapshotHotkey : null,
        // Drawn over the game rather than over a picture of it, and
        // measured against whatever this session reads: the window it was
        // given, or -- with no process to name -- the screen itself. A
        // session reading no frame has none to redraw.
        frame: reading.readsSubtitles ? settings.frameHotkey : null,
        frameOverlay: settings.frameOverlayHotkey,
        frameOf: settings.readsWholeScreen ? 0 : process?.pid ?? 0,
        textLanguage: settings.textLanguage,
      );
    } catch (_) {
      await _endFailedStart(session);
      rethrow;
    }
  }

  /// Draws the subtitle frame over the game, or moves one already drawn.
  /// [processId] of zero measures it against the whole screen.
  void showFrameOverlay({required int processId, required OcrRegion region}) =>
      _nativeEngine.showFrame(processId: processId, region: region);

  /// Takes that frame off the screen.
  void hideFrameOverlay() => _nativeEngine.hideFrame();

  /// Registers the one key that answers while nothing is running: the frame
  /// over the game is the player's own and outlives a session, so the key
  /// that shows and hides it has to outlive one too. The session's own
  /// start registers the rest, and `ld_stop` drops the lot, which is why
  /// this is asked for again once a session ends.
  void setIdleHotkeys(AppSettings settings) => _nativeEngine.setHotkeys(
    frameOverlay: settings.showFrameOverlay ? settings.frameOverlayHotkey : null,
    textLanguage: settings.textLanguage,
  );

  /// The paths a session's models are at, by the role each plays.
  static ModelPaths _modelPaths(Map<String, String> directories) => ModelPaths(
    whisper: directories['whisper'],
    translation: directories['translation'],
    speech: directories['speech'],
    converter: directories['converter'],
  );

  /// The worker that measures a voice and loads nothing else.
  static WorkerPlan _converterOnly(
    AppSettings settings,
    String converterDirectory,
    ComputeBackend converterBackend,
    String runtimeDirectory,
  ) => WorkerPlan(
    threads: settings.cpuThreads,
    pythonExecutable: settings.pythonExecutable,
    runtimeDirectory: runtimeDirectory,
    models: ModelPaths(converter: converterDirectory),
    backends: StageBackends(voiceConversion: converterBackend),
  );

  /// What a reading of the screen captures: the frame, the frame and the
  /// game's own sound where the voices behind it are followed -- that
  /// sound is never recognized, only placed -- or nothing at all, where
  /// the key is the only way in and nothing is scanned until it is
  /// pressed.
  static CaptureMode _captureModeOf(ScreenReading reading, {required bool hearsVoices}) {
    if (!reading.readsSubtitles) return CaptureMode.none;
    return hearsVoices ? CaptureMode.ocrAndAudio : CaptureMode.ocr;
  }

  /// Plays a line this session has already read.
  Future<void> speakAgain(String wavePath) => _nativeEngine.speakAgain(wavePath);

  /// Reads the lines that follow in [voice], while a session runs.
  Future<void> useVoice(String voice) => _nativeEngine.useVoice(voice);

  /// Turns the game down for the screen session. Nothing here listens to the
  /// game's sound, so this one may silence it outright.
  Future<void> _duckScreen(GameProcess? process, AppSettings settings) async {
    if (process == null || settings.duckWhileSpeaking) return;
    await _nativeEngine.setProcessVolume(process.pid, settings.duckedVolume);
  }

  /// Loads the speech model and the converter so a card's voice can be
  /// heard before anything is dubbed. Nothing is captured: the line is the
  /// application's own, and the converter only lays the card's timbre over
  /// the voice the way the dubbing will.
  Future<void> startVoicePreview({
    required AppSettings settings,
    required Map<String, String> modelDirectories,
    required String speaker,
    required ComputeBackend speechBackend,
    required ComputeBackend converterBackend,
    required String runtimeDirectory,
  }) async {
    final session = ++_sessions;
    try {
      await _nativeEngine.startPreview(
        PreviewSessionConfig(
          worker: WorkerPlan(
            threads: settings.cpuThreads,
            pythonExecutable: settings.pythonExecutable,
            runtimeDirectory: runtimeDirectory,
            models: _modelPaths(modelDirectories),
            backends: StageBackends(speech: speechBackend, voiceConversion: converterBackend),
            speaker: speaker,
            speed: settings.chosenSpeed,
          ),
        ),
      );
      _throwIfSuperseded(session);
    } catch (_) {
      await _endFailedStart(session);
      rethrow;
    }
  }

  /// Speaks one line in a card's voice and plays it.
  Future<void> previewVoice({
    required String text,
    required String voice,
    List<double> timbre = const [],
  }) => _nativeEngine.previewVoice(text: text, voice: voice, timbre: timbre);

  /// Starts the session the characters screen records with: the game's audio
  /// and the converter that measures a voice, without the translator or the
  /// speech model, which would cost a minute this screen does not need.
  Future<void> startCharacterVoices({
    required GameProcess? process,
    required AppSettings settings,
    required String converterDirectory,
    required ComputeBackend converterBackend,
    required String runtimeDirectory,
  }) async {
    final session = ++_sessions;
    try {
      await _nativeEngine.startCharacters(
        CharactersSessionConfig(
          worker: _converterOnly(settings, converterDirectory, converterBackend, runtimeDirectory),
          capture: CapturePlan(
            mode: CaptureMode.audio,
            processId: process?.pid ?? 0,
            audioSource: settings.audioCaptureSource,
          ),
        ),
      );
      _throwIfSuperseded(session);
    } catch (_) {
      await _endFailedStart(session);
      rethrow;
    }
  }

  /// Starts the session a card is built through when the recordings are
  /// already on disk: the converter that measures a voice and nothing else,
  /// with no game listened to at all.
  ///
  /// It is borrowed rather than held — up for as long as the files take —
  /// so it answers with its number, which [stopSession] is handed back.
  Future<int> startVoiceFiles({
    required AppSettings settings,
    required String converterDirectory,
    required ComputeBackend converterBackend,
    required String runtimeDirectory,
  }) async {
    final session = ++_sessions;
    try {
      await _nativeEngine.startVoiceFiles(
        VoiceFilesSessionConfig(
          worker: _converterOnly(settings, converterDirectory, converterBackend, runtimeDirectory),
        ),
      );
      _throwIfSuperseded(session);
      return session;
    } catch (_) {
      await _endFailedStart(session);
      rethrow;
    }
  }

  /// One voice from the files at [paths], however they are encoded, measured
  /// through the session that was up when they were handed over or not at
  /// all.
  ///
  /// The files take a while to decode, and Live starting meanwhile takes the
  /// worker over without a word to the characters screen. Measured anyway,
  /// the files went into the dubbing's worker — a second inference beside
  /// its own lines — or, with that worker still coming up, failed into a
  /// banner over a session that was fine. So they end as stopped instead,
  /// which the screen passes over.
  Future<BuiltVoice> buildVoice(List<String> paths) async {
    final session = _sessions;
    final files = await _nativeEngine.decodeVoiceFiles(paths);
    if (session != _sessions) {
      await _nativeEngine.discardVoiceFiles(files);
      throw const LoreDubFailure(FailureCode.pipelineStopped);
    }
    return _nativeEngine.measureVoiceFiles(files);
  }

  /// Starts the session Live gathers the voices of a scene through: the
  /// game's audio and the converter that hears who is speaking, with neither
  /// whisper nor the translator loaded, so it is ready in seconds.
  ///
  /// A voice met here joins the game's bank under the same number a dubbing
  /// session would give it, which is what lets the replacements made now
  /// hold once the dubbing runs.
  Future<void> startSceneVoices({
    required GameProcess? process,
    required AppSettings settings,
    required String converterDirectory,
    required ComputeBackend converterBackend,
    required String runtimeDirectory,
    String? voiceBank,
  }) async {
    final session = ++_sessions;
    try {
      final config = SceneSessionConfig(
        worker: WorkerPlan(
          threads: settings.cpuThreads,
          pythonExecutable: settings.pythonExecutable,
          runtimeDirectory: runtimeDirectory,
          models: ModelPaths(converter: converterDirectory),
          backends: StageBackends(voiceConversion: converterBackend),
          voiceBank: voiceBank,
          characters: await _characters.file(),
          asHeard: await _cutFromMix(),
        ),
        capture: CapturePlan(
          mode: CaptureMode.audio,
          processId: process?.pid ?? 0,
          audioSource: settings.audioCaptureSource,
        ),
      );
      _throwIfSuperseded(session);
      await _nativeEngine.startScene(config);
      _throwIfSuperseded(session);
    } catch (_) {
      await _endFailedStart(session);
      rethrow;
    }
  }

  /// The cards the canvas has cut out of the mix.
  ///
  /// Read off the arrangement rather than out of the settings, the cut being
  /// a card's own since a scheme is wired a card at a time. The canvas
  /// writes the file as it is drawn on, so what a session starts with is
  /// what the player last drew.
  Future<Set<String>> _cutFromMix() async {
    try {
      return (await _layout.load()).silent;
    } on Object {
      // A scheme that cannot be read is no reason not to start: the cast
      // then plays the way it does with nothing cut.
      return const {};
    }
  }

  /// Opens or closes the take a character's card is measured from. Closing
  /// it waits for what was recorded to be measured.
  Future<void> recordCharacterVoice({required bool recording}) =>
      _nativeEngine.setRecordingVoice(recording: recording);

  /// What the running session was started with, so a resume can turn the
  /// game down again exactly as the start did.
  GameProcess? _sessionProcess;
  AppSettings? _sessionSettings;

  /// Turns the captured game down while it is dubbed.
  ///
  /// Only for the session as a whole. Asked to step aside for each line
  /// instead, the engine does it: it is the one that knows when the dubbing
  /// starts and stops speaking.
  Future<void> _duck(GameProcess? process, AppSettings settings) async {
    if (process == null) return;
    if (settings.audioCaptureSource != AudioCaptureSource.process) return;
    if (settings.duckWhileSpeaking) return;
    await _nativeEngine.setProcessVolume(process.pid, settings.duckedVolume);
  }

  /// Rests the session: capture hands nothing on, what was queued is
  /// dropped, and the game plays at its own volume.
  Future<void> pause() async => _nativeEngine.setPaused(true);

  /// Picks the session up where it rested.
  Future<void> resume() async {
    _nativeEngine.setPaused(false);
    final settings = _sessionSettings;
    if (settings != null) await _duck(_sessionProcess, settings);
  }

  Future<void> stop() {
    // A start still on its way fails for being stopped, and must not take
    // that for a failure of its own to clean up after.
    _sessions++;
    _sessionProcess = null;
    _sessionSettings = null;
    return _nativeEngine.stop();
  }

  /// Ends the session numbered [session], while it is still the one the
  /// engine holds, and leaves any other alone.
  ///
  /// A borrowed session is put down when the work it was borrowed for is
  /// over, and by then it may be gone: Live takes the worker over without
  /// asking, and the stop meant for the session it replaced ended the
  /// dubbing instead.
  Future<void> stopSession(int session) async {
    if (session != _sessions) return;
    await stop();
  }

  void dispose() => _nativeEngine.dispose();
}

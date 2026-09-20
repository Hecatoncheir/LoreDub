// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/engine_event.dart';
import '../../domain/ocr_region.dart';
import '../../domain/screen_reading.dart';
import '../../domain/app_settings.dart';
import '../../domain/built_voice.dart';
import '../../domain/character.dart';
import '../../domain/compute_device.dart';
import '../../domain/failure.dart';
import '../../domain/game_process.dart';
import '../../domain/glossary.dart';
import '../../domain/pipeline_graph.dart';
import '../../domain/saved_pipeline.dart';
import 'settings_repository.dart';
import '../services/character_service.dart';
import '../services/glossary_catalog.dart';
import '../services/glossary_service.dart';
import '../services/native_engine_service.dart';
import '../services/pipeline_graph_service.dart';
import '../services/pipeline_library_service.dart';
import '../services/python_discovery.dart';
import '../services/voice_bank_service.dart';

class AppRepository {
  AppRepository(
    this._nativeEngine,
    this._settings, [
    PythonDiscovery? pythonDiscovery,
    VoiceBankService? voiceBank,
    CharacterService? characters,
    GlossaryService? glossary,
    PipelineGraphService? graph,
    PipelineLibraryService? pipelines,
  ]) : _pythonDiscovery = pythonDiscovery ?? PythonDiscovery(),
       _voiceBank = voiceBank ?? VoiceBankService(),
       _characters = characters ?? CharacterService(),
       _glossary = glossary ?? GlossaryService(),
       _graph = graph ?? PipelineGraphService(),
       _pipelines = pipelines ?? PipelineLibraryService();

  final NativeEngineService _nativeEngine;
  final SettingsRepository _settings;
  final PythonDiscovery _pythonDiscovery;
  final VoiceBankService _voiceBank;
  final CharacterService _characters;
  final GlossaryService _glossary;
  final PipelineGraphService _graph;
  final PipelineLibraryService _pipelines;

  /// Where the pipeline canvas was left. Only the arrangement: what the
  /// pipeline does is the settings and the cast.
  Future<PipelineLayout> loadGraphLayout() => _graph.load();
  Future<void> saveGraphLayout(PipelineLayout layout) => _graph.save(layout);

  /// The characters the player recorded and named. They belong to the player
  /// rather than to one game, so every session is handed the same file.
  Future<CharacterLibrary> loadCharacters() => _characters.load();
  Future<void> saveCharacters(CharacterLibrary library) => _characters.save(library);
  Future<String> charactersFile() => _characters.file();

  /// What the player wrote down about their games. Theirs rather than one
  /// game's, so every session that translates is handed the same file.
  /// What is written down, with the packs LoreDub brings laid over it the
  /// first time the screen is opened.
  ///
  /// Only where the dubbing is into the language they are written in. A
  /// player dubbing into German is not offered a hundred Russian readings,
  /// and is offered them if they ever switch: nothing is marked as offered
  /// until it actually has been.
  ///
  /// Read off the settings as they stand, so they have to have been loaded
  /// first — which is why the first load reads them before anything else.
  Future<Glossary> loadGlossary() async {
    final kept = await _glossary.load();
    // The settings themselves rather than the file they came from: one
    // owner, one read. Awaited rather than read off the field, so this
    // does not depend on having been started after whoever loads them.
    final settings = await _settings.load();
    if (settings.targetLanguage != builtInGlossaryLanguage) return kept;
    final offered = await _glossary.withBuiltIn(kept, builtInGlossary());
    if (!identical(offered, kept)) await _glossary.save(offered);
    return offered;
  }

  /// Writes the glossary where the player asked.
  Future<void> exportGlossary(String destination, Glossary glossary) =>
      _glossary.exportTo(destination, glossary);

  /// What the files the player chose hold, for the screen to merge into what
  /// is already written down.
  Future<Glossary> readGlossaryFiles(List<String> sources) => _glossary.readFiles(sources);

  /// Keeps it, and tells a session already running: the player writes an
  /// entry because they just heard the line, and mean the next one to be
  /// said their way rather than the next session.
  Future<void> saveGlossary(Glossary glossary) async {
    await _glossary.save(glossary);
    // What the active packs leave in use, not the whole shelf: the worker
    // applies what it is given and knows nothing of packs.
    await _nativeEngine.writeGlossary(glossary.inUse);
  }

  /// The clip recorded for a card, when it kept one. An imported card
  /// carries a fingerprint but no audio, so it may have none.
  Future<String?> characterClip(String id) => _characters.clipFor(id);

  /// The cards with a clip to play.
  Future<Set<String>> characterClips() => _characters.clips();

  Future<void> keepCharacterClip(String id, String source) => _characters.keepClip(id, source);

  Future<void> removeCharacterClip(String id) => _characters.removeClip(id);

  /// Plays a file to its end, outside the dubbing's own queue: a clip the
  /// player asked to hear does not wait behind a scene.
  Future<void> playWave(String wavePath) => _nativeEngine.playWave(wavePath);

  /// Ends whatever is sounding.
  void stopWave() => _nativeEngine.stopWave();

  Future<void> exportCharacters(String destination, CharacterLibrary library) =>
      _characters.exportTo(destination, library);

  Future<CharacterLibrary> readCharacterFiles(List<String> sources) =>
      _characters.readFiles(sources);

  Future<PythonDiscoveryResult> findPythonExecutable() => _pythonDiscovery.find();

  Stream<EngineEvent> get events => _nativeEngine.events;
  bool get processLoopbackSupported => _nativeEngine.processLoopbackSupported;

  Future<List<GameProcess>> listProcesses() => _nativeEngine.listProcesses();

  /// The bank file the original voice keeps [game]'s characters in; the game
  /// is named by its executable.
  Future<String> voiceBankFileFor(String game) => _voiceBank.fileFor(game);

  /// How many voices the banks of all games hold together.
  Future<int> voiceBankSize() => _voiceBank.count();
  Future<void> clearVoiceBank() => _voiceBank.clear();

  /// What the machine's adapters and drivers offer, before the download
  /// state of the GPU runtimes is taken into account.
  Future<ComputeAvailability> probeGraphics() => _nativeEngine.probeGraphics();

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
      final config = <String, Object?>{
        'speaker': speaker,
        'processId': process?.pid ?? 0,
        'captureMode': 'audio',
        'audioSource': settings.audioCaptureSource.name,
        'targetLanguage': settings.targetLanguage,
        'sourceLanguage': settings.effectiveSourceLanguage,
        // What the game is turned down to, and whether that happens for the
        // length of a line rather than for the whole session.
        'duckVolume': settings.duckedVolume,
        'duckWhileSpeaking': settings.duckWhileSpeaking,
        'hurryWhenQueued': settings.hurryWhenQueued,
        'roughRecognition': settings.roughRecognition,
        'glossary': await _glossary.sessionFile(),
        'textLanguage': settings.textLanguage,
        'ocrLanguage': settings.textLanguage,
        'ttsSpeed': settings.chosenSpeed,
        'cpuThreads': settings.cpuThreads,
        'ocrRegionLeft': settings.ocrRegion.left,
        'ocrRegionTop': settings.ocrRegion.top,
        'ocrRegionRight': settings.ocrRegion.right,
        'ocrRegionBottom': settings.ocrRegion.bottom,
        'pythonExecutable': settings.pythonExecutable,
        'models': modelDirectories,
        'translationPrefix': translationPrefix,
        'translateSpeech': translateSpeech,
        'followSpeaker': followSpeaker,
        'revoice': revoice,
        'overlapVoices': settings.overlapVoices,
        'maleVoices': maleVoices.join(','),
        'femaleVoices': femaleVoices.join(','),
        'recognitionBackend': recognitionBackend.name,
        'translationBackend': translationBackend.name,
        'speechBackend': speechBackend.name,
        'voiceConversionBackend': voiceConversionBackend.name,
        'runtimeDirectory': runtimeDirectory,
        'voiceBank': ?voiceBank,
        // The player's own characters, who speak in every game.
        'characters': await _characters.file(),
        // The cards cut out of the mix on the graph: each of them keeps who
        // stands in for whom, and none of it is applied.
        'asHeard': await _cutFromMix(),
      };
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
      final config = <String, Object?>{
        'speaker': speaker,
        // Named even when the screen is what is read: nothing is taken out
        'captureMode': _captureModeOf(reading, hearsVoices: hearsVoices),
        'ocrSource': settings.readsWholeScreen ? 'screen' : 'process',
        'targetLanguage': settings.targetLanguage,
        'textLanguage': settings.textLanguage,
        'ocrLanguage': settings.textLanguage,
        'ocrRegionLeft': settings.ocrRegion.left,
        'ocrRegionTop': settings.ocrRegion.top,
        'ocrRegionRight': settings.ocrRegion.right,
        'ocrRegionBottom': settings.ocrRegion.bottom,
        'duckVolume': settings.duckedVolume,
        'duckWhileSpeaking': settings.duckWhileSpeaking,
        'ttsSpeed': settings.chosenSpeed,
        'hurryWhenQueued': settings.hurryWhenQueued,
        'glossary': await _glossary.sessionFile(),
        'cpuThreads': settings.cpuThreads,
        'pythonExecutable': settings.pythonExecutable,
        'models': modelDirectories,
        'translationPrefix': translationPrefix,
        'translationBackend': translationBackend.name,
        'speechBackend': speechBackend.name,
        'runtimeDirectory': runtimeDirectory,
        'characters': await _characters.file(),
        // The voices are heard by the converter and carried over the
        // reading, so this session asks for the same two as the original
        // voice does -- and for the game's own bank, so a character met
        // here is the one the dubbing session knows.
        'revoice': hearsVoices,
        'voiceConversionBackend': converterBackend.name,
        'voiceBank': ?voiceBank,
      };
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

  /// What a reading of the screen captures: the frame, the frame and the
  /// game's own sound where the voices behind it are followed -- that
  /// sound is never recognized, only placed -- or nothing at all, where
  /// the key is the only way in and nothing is scanned until it is
  /// pressed.
  static String _captureModeOf(ScreenReading reading, {required bool hearsVoices}) {
    if (!reading.readsSubtitles) return 'none';
    return hearsVoices ? 'ocrAndAudio' : 'ocr';
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
      await _nativeEngine.startPreview({
        'speaker': speaker,
        'ttsSpeed': settings.chosenSpeed,
        'cpuThreads': settings.cpuThreads,
        'pythonExecutable': settings.pythonExecutable,
        'models': modelDirectories,
        'speechBackend': speechBackend.name,
        'voiceConversionBackend': converterBackend.name,
        'runtimeDirectory': runtimeDirectory,
      });
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
      await _nativeEngine.startCharacters({
        'processId': process?.pid ?? 0,
        'captureMode': 'audio',
        'audioSource': settings.audioCaptureSource.name,
        'cpuThreads': settings.cpuThreads,
        'pythonExecutable': settings.pythonExecutable,
        'models': {'converter': converterDirectory},
        'voiceConversionBackend': converterBackend.name,
        'runtimeDirectory': runtimeDirectory,
      });
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
      await _nativeEngine.startVoiceFiles({
        'cpuThreads': settings.cpuThreads,
        'pythonExecutable': settings.pythonExecutable,
        'models': {'converter': converterDirectory},
        'voiceConversionBackend': converterBackend.name,
        'runtimeDirectory': runtimeDirectory,
      });
      _throwIfSuperseded(session);
      return session;
    } catch (_) {
      await _endFailedStart(session);
      rethrow;
    }
  }

  /// The schemes kept on this machine.
  Future<PipelineLibrary> loadPipelines() => _pipelines.load();

  Future<void> savePipelines(PipelineLibrary library) => _pipelines.save(library);

  Future<void> exportPipelines(String destination, List<SavedPipeline> pipelines) =>
      _pipelines.exportTo(destination, pipelines);

  Future<List<SavedPipeline>> importPipelines(List<String> sources) =>
      _pipelines.readFiles(sources);

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
      final config = <String, Object?>{
        'processId': process?.pid ?? 0,
        'captureMode': 'audio',
        'audioSource': settings.audioCaptureSource.name,
        'cpuThreads': settings.cpuThreads,
        'pythonExecutable': settings.pythonExecutable,
        'models': {'converter': converterDirectory},
        'voiceConversionBackend': converterBackend.name,
        'runtimeDirectory': runtimeDirectory,
        'voiceBank': ?voiceBank,
        'characters': await _characters.file(),
        'asHeard': await _cutFromMix(),
      };
      _throwIfSuperseded(session);
      await _nativeEngine.startScene(config);
      _throwIfSuperseded(session);
    } catch (_) {
      await _endFailedStart(session);
      rethrow;
    }
  }

  /// Tells a running session that the cast has been taken out of the mix on
  /// the graph, or joined back to it: out of it every voice is read as
  /// itself, and the cards keep who stands in for whom meanwhile.
  Future<void> readAsHeard(Set<String> value) => _nativeEngine.readAsHeard(value);

  /// The cards the canvas has cut out of the mix, as one comma-separated
  /// string: the config crosses to the native side as JSON of flat values.
  ///
  /// Read off the arrangement rather than out of the settings, the cut being
  /// a card's own since a scheme is wired a card at a time. The canvas
  /// writes the file as it is drawn on, so what a session starts with is
  /// what the player last drew.
  Future<String> _cutFromMix() async {
    try {
      return (await _graph.load()).silent.join(',');
    } on Object {
      // A scheme that cannot be read is no reason not to start: the cast
      // then plays the way it does with nothing cut.
      return '';
    }
  }

  /// Tells a running session that [character] is read in [target]'s voice
  /// from the next line on, as their card now says.
  ///
  /// The cast is read from the file when a session starts, so without this a
  /// card edited mid-session would only be heard after a restart.
  Future<void> voiceCharacterAs(String character, String? target) =>
      _nativeEngine.voiceCharacterAs(character, target);

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

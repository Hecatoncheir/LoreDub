// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/app_settings.dart';
import '../../domain/built_voice.dart';
import '../../domain/character.dart';
import '../../domain/compute_device.dart';
import '../../domain/game_process.dart';
import '../../domain/pipeline_graph.dart';
import '../../domain/saved_pipeline.dart';
import '../services/character_service.dart';
import '../services/native_engine_service.dart';
import '../services/pipeline_graph_service.dart';
import '../services/pipeline_library_service.dart';
import '../services/python_discovery.dart';
import '../services/settings_service.dart';
import '../services/voice_bank_service.dart';

class AppRepository {
  AppRepository(
    this._nativeEngine,
    this._settingsService, [
    PythonDiscovery? pythonDiscovery,
    VoiceBankService? voiceBank,
    CharacterService? characters,
    PipelineGraphService? graph,
    PipelineLibraryService? pipelines,
  ]) : _pythonDiscovery = pythonDiscovery ?? PythonDiscovery(),
       _voiceBank = voiceBank ?? VoiceBankService(),
       _characters = characters ?? CharacterService(),
       _graph = graph ?? PipelineGraphService(),
       _pipelines = pipelines ?? PipelineLibraryService();

  final NativeEngineService _nativeEngine;
  final SettingsService _settingsService;
  final PythonDiscovery _pythonDiscovery;
  final VoiceBankService _voiceBank;
  final CharacterService _characters;
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

  Stream<Map<String, Object?>> get events => _nativeEngine.events;
  bool get processLoopbackSupported => _nativeEngine.processLoopbackSupported;

  Future<AppSettings> loadSettings() => _settingsService.load();
  Future<void> saveSettings(AppSettings settings) => _settingsService.save(settings);
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
    required ComputeBackend voiceConversionBackend,
    required String runtimeDirectory,
    String? voiceBank,
  }) async {
    try {
      await _nativeEngine.start({
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
        'voiceConversionBackend': voiceConversionBackend.name,
        'runtimeDirectory': runtimeDirectory,
        'voiceBank': ?voiceBank,
        // The player's own characters, who speak in every game.
        'characters': await _characters.file(),
        // The cards cut out of the mix on the graph: each of them keeps who
        // stands in for whom, and none of it is applied.
        'asHeard': await _cutFromMix(),
      });
      await _duck(process, settings);
      _sessionProcess = process;
      _sessionSettings = settings;
      _nativeEngine.setHotkeys(
        pause: settings.pauseHotkey,
        resume: settings.resumeHotkey,
        snapshot: settings.snapshotHotkey,
        textLanguage: settings.textLanguage,
      );
    } catch (_) {
      await _nativeEngine.stop();
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
    required GameProcess? process,
    required AppSettings settings,
    required Map<String, String> modelDirectories,
    required String speaker,
    required String translationPrefix,
    required ComputeBackend translationBackend,
    required String runtimeDirectory,
  }) async {
    try {
      await _nativeEngine.startScreenText({
        'speaker': speaker,
        // Named even when the screen is what is read: nothing is taken out
        // of that window then, but it is still the game to turn down.
        'processId': process?.pid ?? 0,
        'captureMode': 'ocr',
        'ocrSource': settings.readsWholeScreen ? 'screen' : 'process',
        'targetLanguage': settings.targetLanguage,
        'textLanguage': settings.textLanguage,
        'ocrLanguage': settings.textLanguage,
        'ocrRegionLeft': settings.ocrRegion.left,
        'ocrRegionTop': settings.ocrRegion.top,
        'ocrRegionRight': settings.ocrRegion.right,
        'ocrRegionBottom': settings.ocrRegion.bottom,
        'duckVolume': settings.silentDuckedVolume,
        'duckWhileSpeaking': settings.duckWhileSpeaking,
        'ttsSpeed': settings.chosenSpeed,
        'hurryWhenQueued': settings.hurryWhenQueued,
        'cpuThreads': settings.cpuThreads,
        'pythonExecutable': settings.pythonExecutable,
        'models': modelDirectories,
        'translationPrefix': translationPrefix,
        'translationBackend': translationBackend.name,
        'runtimeDirectory': runtimeDirectory,
        'characters': await _characters.file(),
      });
      await _duckScreen(process, settings);
      _sessionProcess = process;
      _sessionSettings = settings;
      _nativeEngine.setHotkeys(
        snapshot: settings.snapshotHotkey,
        // Drawn over the game rather than over a picture of it, and
        // measured against whatever this session reads: the window it was
        // given, or -- with no process to name -- the screen itself.
        frame: settings.frameHotkey,
        frameOf: settings.readsWholeScreen ? 0 : process?.pid ?? 0,
        textLanguage: settings.textLanguage,
      );
    } catch (_) {
      await _nativeEngine.stop();
      rethrow;
    }
  }

  /// Turns the game down for the screen session. Nothing here listens to the
  /// game's sound, so this one may silence it outright.
  Future<void> _duckScreen(GameProcess? process, AppSettings settings) async {
    if (process == null || settings.duckWhileSpeaking) return;
    await _nativeEngine.setProcessVolume(process.pid, settings.silentDuckedVolume);
  }

  /// Loads the speech model and the converter so a card's voice can be
  /// heard before anything is dubbed. Nothing is captured: the line is the
  /// application's own, and the converter only lays the card's timbre over
  /// the voice the way the dubbing will.
  Future<void> startVoicePreview({
    required AppSettings settings,
    required Map<String, String> modelDirectories,
    required String speaker,
    required ComputeBackend converterBackend,
    required String runtimeDirectory,
  }) async {
    try {
      await _nativeEngine.startPreview({
        'speaker': speaker,
        'ttsSpeed': settings.chosenSpeed,
        'cpuThreads': settings.cpuThreads,
        'pythonExecutable': settings.pythonExecutable,
        'models': modelDirectories,
        'voiceConversionBackend': converterBackend.name,
        'runtimeDirectory': runtimeDirectory,
      });
    } catch (_) {
      await _nativeEngine.stop();
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
    } catch (_) {
      await _nativeEngine.stop();
      rethrow;
    }
  }

  /// Starts the session a card is built through when the recordings are
  /// already on disk: the converter that measures a voice and nothing else,
  /// with no game listened to at all.
  Future<void> startVoiceFiles({
    required AppSettings settings,
    required String converterDirectory,
    required ComputeBackend converterBackend,
    required String runtimeDirectory,
  }) async {
    try {
      await _nativeEngine.startVoiceFiles({
        'cpuThreads': settings.cpuThreads,
        'pythonExecutable': settings.pythonExecutable,
        'models': {'converter': converterDirectory},
        'voiceConversionBackend': converterBackend.name,
        'runtimeDirectory': runtimeDirectory,
      });
    } catch (_) {
      await _nativeEngine.stop();
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

  /// One voice from the files at [paths], however they are encoded.
  Future<BuiltVoice> buildVoice(List<String> paths) => _nativeEngine.buildVoice(paths);

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
    try {
      await _nativeEngine.startScene({
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
      });
    } catch (_) {
      await _nativeEngine.stop();
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
    _sessionProcess = null;
    _sessionSettings = null;
    return _nativeEngine.stop();
  }

  void dispose() => _nativeEngine.dispose();
}

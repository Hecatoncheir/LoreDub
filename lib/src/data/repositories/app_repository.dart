// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/app_settings.dart';
import '../../domain/character.dart';
import '../../domain/compute_device.dart';
import '../../domain/game_process.dart';
import '../../domain/pipeline_graph.dart';
import '../services/character_service.dart';
import '../services/native_engine_service.dart';
import '../services/pipeline_graph_service.dart';
import '../services/python_discovery.dart';
import '../services/settings_service.dart';
import '../services/speaker_map_service.dart';
import '../services/voice_bank_service.dart';

class AppRepository {
  AppRepository(
    this._nativeEngine,
    this._settingsService, [
    PythonDiscovery? pythonDiscovery,
    VoiceBankService? voiceBank,
    CharacterService? characters,
    SpeakerMapService? speakerMap,
    PipelineGraphService? graph,
  ]) : _pythonDiscovery = pythonDiscovery ?? PythonDiscovery(),
       _voiceBank = voiceBank ?? VoiceBankService(),
       _characters = characters ?? CharacterService(),
       _speakerMap = speakerMap ?? SpeakerMapService(),
       _graph = graph ?? PipelineGraphService();

  final NativeEngineService _nativeEngine;
  final SettingsService _settingsService;
  final PythonDiscovery _pythonDiscovery;
  final VoiceBankService _voiceBank;
  final CharacterService _characters;
  final SpeakerMapService _speakerMap;
  final PipelineGraphService _graph;

  /// Where the pipeline canvas was left. Only the arrangement: what the
  /// pipeline does is the settings and the cast.
  Future<PipelineLayout> loadGraphLayout() => _graph.load();
  Future<void> saveGraphLayout(PipelineLayout layout) => _graph.save(layout);

  /// The characters the player recorded and named. They belong to the player
  /// rather than to one game, so every session is handed the same file.
  Future<CharacterLibrary> loadCharacters() => _characters.load();
  Future<void> saveCharacters(CharacterLibrary library) => _characters.save(library);
  Future<String> charactersFile() => _characters.file();

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

  /// The file whose voice reads whom is kept in for [game].
  Future<String> speakerMapFileFor(String game) => _speakerMap.fileFor(game);

  /// Whose voice reads whom in [game], as the player assigned it.
  Future<Map<String, String>> loadSpeakerMap(String game) => _speakerMap.load(game);

  /// Keeps [replacements] for [game] and tells the running worker that
  /// [speaker] is read in [character]'s voice from now on — or in their own
  /// again, when [character] is null.
  ///
  /// Written for the next session and told to the one running, so the change
  /// is heard on the next line rather than on the next launch.
  Future<void> assignSpeaker({
    required String game,
    required Map<String, String> replacements,
    required String speaker,
    String? character,
  }) async {
    await _speakerMap.save(game, replacements);
    await _nativeEngine.assignSpeaker(speaker, character);
  }

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
    String? speakerMap,
    String? voiceBank,
  }) async {
    try {
      await _nativeEngine.start({
        'speaker': speaker,
        'processId': process?.pid ?? 0,
        'captureMode': settings.captureMode.name,
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
        // Whose voice reads whom in this game, as the player assigned it.
        'speakerMap': ?speakerMap,
        // The player's own characters speak in every game.
        'characters': await _characters.file(),
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

  /// Starts the snapshot session: the translator, the voice and the snapshot
  /// key. Nothing is captured until the player selects an area, and no game
  /// is turned down.
  Future<void> startSnapshot({
    required AppSettings settings,
    required Map<String, String> modelDirectories,
    required String speaker,
    required String translationPrefix,
    required ComputeBackend translationBackend,
    required String runtimeDirectory,
  }) async {
    try {
      await _nativeEngine.startSnapshot({
        'speaker': speaker,
        'targetLanguage': settings.targetLanguage,
        'textLanguage': settings.textLanguage,
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
      _nativeEngine.setHotkeys(
        snapshot: settings.snapshotHotkey,
        textLanguage: settings.textLanguage,
      );
    } catch (_) {
      await _nativeEngine.stop();
      rethrow;
    }
  }

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
        'captureMode': CaptureMode.audio.name,
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
        'captureMode': CaptureMode.audio.name,
        'audioSource': settings.audioCaptureSource.name,
        'cpuThreads': settings.cpuThreads,
        'pythonExecutable': settings.pythonExecutable,
        'models': {'converter': converterDirectory},
        'voiceConversionBackend': converterBackend.name,
        'runtimeDirectory': runtimeDirectory,
        'voiceBank': ?voiceBank,
        'speakerMap': await _speakerMap.fileFor(process?.name ?? ''),
        'characters': await _characters.file(),
      });
    } catch (_) {
      await _nativeEngine.stop();
      rethrow;
    }
  }

  /// Tells a running session that [character] is read in [target]'s voice
  /// from the next line on, as their card now says.
  ///
  /// The cast is read from the file when a session starts, so without this a
  /// card edited mid-session would only be heard after a restart.
  Future<void> voiceCharacterAs(String character, String? target) =>
      _nativeEngine.voiceCharacterAs(character, target);

  /// Whether what the game says is being measured for a character's card.
  /// Between recordings the captured audio is thrown away.
  void recordCharacterVoice({required bool recording}) =>
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
    if (settings.captureMode != CaptureMode.ocr &&
        settings.audioCaptureSource != AudioCaptureSource.process) {
      return;
    }
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

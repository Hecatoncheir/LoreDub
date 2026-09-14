// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import '../../domain/compute_device.dart';
import '../../domain/failure.dart';
import '../../domain/game_process.dart';
import '../../domain/hotkey.dart';
import '../../domain/ocr_text_delta.dart';
import '../../domain/built_voice.dart';
import '../../domain/pipeline_state.dart';
import '../../domain/sound_captions.dart';
import '../../domain/speech_pace.dart';
import '../../domain/wave_slices.dart';
import '../../native/lore_dub_native.g.dart';
import 'local_inference_service.dart';
import 'phrase_queue.dart';
import 'playback_scheduler.dart';

typedef NativeStringReader = int Function(Pointer<Char> output, int capacity);

class NativeEngineException implements Exception {
  const NativeEngineException(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'NativeEngineException($code): $message';
}

class NativeEngineService {
  NativeEngineService() {
    _inference.onStartupProgress = (value, stage) =>
        _events.add(_ofSession({'type': 'startup', 'value': value, 'stage': stage}));
    _playback.onSpeaking = _duckForSpeech;
  }

  final _events = StreamController<Map<String, Object?>>.broadcast();
  final _inference = LocalInferenceService();
  Timer? _pollTimer;
  late final _phrases = PhraseQueue(process: _processPhrase);

  /// Playback runs beside recognition instead of inside it. Voicing a reply
  /// takes as long as the reply itself, and holding the pipeline for that
  /// would put every later phrase further behind the game.
  late final _playback = PlaybackScheduler(play: _playQueued);
  Map<String, Object?>? _activeConfig;
  String? _reportedLanguage;
  String? _reportedVoice;
  int? _reportedBankSize;

  /// Set while the session rests: capture hands nothing on, and a line
  /// finishing its translation meanwhile is shown but not voiced.
  bool _paused = false;

  /// Which session is running, or null while the engine rests.
  ///
  /// The engine serves the dubbing screens and the characters screen in
  /// turn, and what a captured segment is for depends on which of them holds
  /// it: recognized and voiced for live dubbing, measured for a card on the
  /// characters screen, only placed among the voices of a scene. One field
  /// rather than a flag per session, so that a start can never leave the
  /// session before it set.
  PipelineSession? _session;

  /// Whether a card is recording right now. Between recordings what the game
  /// says is thrown away.
  bool _recordingVoice = false;

  /// What the recording has heard so far, kept until it ends: the screen
  /// picks one of them for the card, and cannot copy a file already gone.
  final _recordedClips = <String>[];

  /// What subtitle mode read last, so a line that grows in place is voiced
  /// only for what it gained, and one that comes back unchanged — even after
  /// leaving the screen — is not voiced again.
  String? _previousOcrText;

  Stream<Map<String, Object?>> get events => _events.stream;
  bool get processLoopbackSupported => ld_is_process_loopback_supported() == 1;

  Future<List<GameProcess>> listProcesses() async {
    final json = _readNativeString(ld_list_processes_json);
    final values = jsonDecode(json) as List<Object?>;
    final processes = values
        .map((value) => GameProcess.fromJson(value! as Map<String, Object?>))
        .toList();
    processes.sort(compareGameProcesses);
    return processes;
  }

  /// What the machine's graphics adapters and GPU drivers offer.
  ///
  /// Only the hardware half is filled in: whether the runtime for a backend
  /// has been downloaded is a question for the storage service.
  Future<ComputeAvailability> probeGraphics() async {
    final json = _readNativeString(ld_probe_graphics_json);
    return ComputeAvailability.fromProbeJson(jsonDecode(json) as Map<String, Object?>);
  }

  static ComputeBackend _backendFrom(Object? name) => ComputeBackend.values.firstWhere(
    (backend) => backend.name == name,
    orElse: () => ComputeBackend.cpu,
  );

  static List<String> _voiceList(Object? joined) =>
      (joined as String? ?? '').split(',').where((name) => name.isNotEmpty).toList();

  Future<void> start(Map<String, Object?> config) async {
    _reportedLanguage = null;
    _reportedVoice = null;
    _reportedBankSize = null;
    _paused = false;
    _session = PipelineSession.live;
    _playback.maxVoices = config['overlapVoices'] == true ? overlappingVoices : 1;
    await LocalInferenceService.removeStaleAudio();
    final models = config['models']! as Map<String, String>;
    await _inference.start(
      translationModel: models['translation']!,
      ttsModel: models['speech']!,
      speaker: config['speaker']! as String,
      threads: config['cpuThreads']! as int,
      speed: config['ttsSpeed']! as double,
      pythonExecutable: config['pythonExecutable']! as String,
      requiresWhisper: config['captureMode'] != 'ocr',
      sourceLanguage: config['sourceLanguage']! as String,
      translationPrefix: config['translationPrefix'] as String? ?? '',
      followSpeaker: config['followSpeaker'] as bool? ?? false,
      revoice: config['revoice'] as bool? ?? false,
      maleVoices: _voiceList(config['maleVoices']),
      femaleVoices: _voiceList(config['femaleVoices']),
      recognitionBackend: _backendFrom(config['recognitionBackend']),
      translationBackend: _backendFrom(config['translationBackend']),
      downloadedRuntimeDirectory: config['runtimeDirectory'] as String?,
      voiceConverter: models['converter'],
      voiceConversionBackend: _backendFrom(config['voiceConversionBackend']),
      voiceBank: config['voiceBank'] as String?,
      characters: config['characters'] as String?,
      asHeard: config['asHeard'] as bool? ?? false,
    );
    // What the worker settled on, which is not always what it was asked for.
    if (_inference.translationBackend case final actual?) {
      _events.add({'type': 'backend', 'stage': 'translation', 'backend': actual.name});
    }
    if (_inference.voiceConversionBackend case final actual?) {
      _events.add({'type': 'backend', 'stage': 'voiceConversion', 'backend': actual.name});
    }
    _events.add({'type': 'startup', 'value': 0.98, 'stage': 'capture'});
    final work = await LocalInferenceService.createWorkDirectory();
    final capture = Directory('${work.path}${Platform.pathSeparator}capture');
    await capture.create(recursive: true);
    _activeConfig = {...config, 'captureDirectory': capture.path};
    final pointer = jsonEncode(_activeConfig).toNativeUtf8();
    try {
      _throwIfError(ld_start(pointer.cast()));
    } catch (_) {
      await _inference.stop();
      rethrow;
    } finally {
      malloc.free(pointer);
    }
    _pollTimer ??= Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => _pollEvents(),
    );
  }

  /// Loads the translator and the voice for the screen session, and starts
  /// the capture that reads the subtitle frame.
  ///
  /// One session answers for both halves of the screen: what the frame
  /// gains as the game writes in it, and what the player picks out by hand
  /// while holding the snapshot key. Whisper takes no part in either --
  /// nothing here is heard -- so it is ready in seconds.
  Future<void> startScreenText(Map<String, Object?> config) async {
    _reportedLanguage = null;
    _reportedVoice = null;
    _reportedBankSize = null;
    _paused = false;
    _session = PipelineSession.screen;
    // One line at a time is read, so there is no one to talk over.
    _playback.maxVoices = 1;
    await LocalInferenceService.removeStaleAudio();
    final models = config['models']! as Map<String, String>;
    await _inference.start(
      translationModel: models['translation']!,
      ttsModel: models['speech']!,
      speaker: config['speaker']! as String,
      threads: config['cpuThreads']! as int,
      speed: config['ttsSpeed']! as double,
      pythonExecutable: config['pythonExecutable']! as String,
      requiresWhisper: false,
      translationPrefix: config['translationPrefix'] as String? ?? '',
      translationBackend: _backendFrom(config['translationBackend']),
      downloadedRuntimeDirectory: config['runtimeDirectory'] as String?,
      voiceConverter: (config['models']! as Map<String, String>)['converter'],
      voiceConversionBackend: _backendFrom(config['voiceConversionBackend']),
      characters: config['characters'] as String?,
    );
    if (_inference.translationBackend case final actual?) {
      _events.add({'type': 'backend', 'stage': 'translation', 'backend': actual.name});
    }
    _events.add({'type': 'startup', 'value': 0.98, 'stage': 'capture'});
    // No capture directory: the screen has no audio to cut into files, and
    // the native side asks for one only when it listens.
    _activeConfig = config;
    final pointer = jsonEncode(_activeConfig).toNativeUtf8();
    try {
      _throwIfError(ld_start(pointer.cast()));
    } catch (_) {
      await _inference.stop();
      rethrow;
    } finally {
      malloc.free(pointer);
    }
    _pollTimer ??= Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => _pollEvents(),
    );
  }

  /// Loads the speech model and the converter, and nothing else: the
  /// characters screen plays a sample of a card's voice with them. Neither
  /// whisper nor the translator is wanted — the line is one the application
  /// wrote — so the screen waits seconds rather than a minute.
  Future<void> startPreview(Map<String, Object?> config) async {
    _paused = false;
    _session = PipelineSession.preview;
    final models = config['models']! as Map<String, String>;
    await _inference.start(
      speechOnly: true,
      ttsModel: models['speech']!,
      speaker: config['speaker']! as String,
      threads: config['cpuThreads']! as int,
      speed: config['ttsSpeed']! as double,
      pythonExecutable: config['pythonExecutable']! as String,
      requiresWhisper: false,
      voiceConverter: models['converter'],
      voiceConversionBackend: _backendFrom(config['voiceConversionBackend']),
      downloadedRuntimeDirectory: config['runtimeDirectory'] as String?,
    );
    _activeConfig = config;
    _pollTimer ??= Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => _pollEvents(),
    );
    // Nothing native starts here to say so itself.
    _events.add(_ofSession({'type': 'state', 'state': 'listening'}));
  }

  /// Loads the converter and nothing else, with no capture at all: the
  /// files a card is built from are already on disk, and there is no game
  /// to listen to. The screen waits seconds rather than a minute.
  Future<void> startVoiceFiles(Map<String, Object?> config) async {
    _paused = false;
    _session = PipelineSession.characters;
    _recordingVoice = false;
    final models = config['models']! as Map<String, String>;
    await _inference.start(
      embedOnly: true,
      threads: config['cpuThreads']! as int,
      speed: 1,
      pythonExecutable: config['pythonExecutable']! as String,
      requiresWhisper: false,
      voiceConverter: models['converter'],
      voiceConversionBackend: _backendFrom(config['voiceConversionBackend']),
      downloadedRuntimeDirectory: config['runtimeDirectory'] as String?,
    );
    _activeConfig = config;
    _pollTimer ??= Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => _pollEvents(),
    );
    // Nothing native starts here to say so itself.
    _events.add(_ofSession({'type': 'state', 'state': 'listening'}));
  }

  /// Turns the files at [paths] into recordings the converter can measure
  /// and hands them to the worker as one voice.
  ///
  /// Windows does the decoding, so a card takes whatever the machine can
  /// play -- ogg and opus included. Each file is brought to the rate and
  /// the loudness the capture writes at, or a fingerprint from a file would
  /// not answer for the same character a fingerprint from the game does.
  Future<BuiltVoice> buildVoice(List<String> paths) async {
    final work = await LocalInferenceService.createWorkDirectory();
    final decoded = <String>[];
    final unreadable = <String>[];
    for (final (index, source) in paths.indexed) {
      final target = '${work.path}${Platform.pathSeparator}dropped_$index.wav';
      final milliseconds = await Isolate.run(() => _decodeAudio(source, target));
      if (milliseconds < 0) {
        unreadable.add(source);
        continue;
      }
      decoded.add(target);
    }
    if (decoded.isEmpty) {
      throw const LoreDubFailure(FailureCode.audioNotDecoded);
    }
    try {
      final built = await _inference.buildVoice(decoded);
      _anchorKept = built.anchor;
      // The worker answers about the files it was handed; the player knows
      // the ones they dropped, so the two are put back together here.
      final ofSource = {for (final (index, path) in decoded.indexed) path: index};
      return BuiltVoice(
        vector: built.vector,
        gender: built.gender,
        seconds: built.seconds,
        used: built.used,
        skipped: [
          ...unreadable,
          for (final path in built.skipped)
            if (ofSource[path] case final index?) paths[index] else path,
        ],
        agreement: built.agreement,
        weakest: built.weakest,
        together: built.together,
        anchor: built.anchor,
      );
    } finally {
      for (final path in decoded) {
        // The one the fingerprint stands closest to is left where it is:
        // the card keeps it to play back, and the caller drops it once it
        // has been copied there.
        if (path != _anchorKept) await _deleteIfPresent(path);
      }
      _anchorKept = null;
    }
  }

  /// The decoded file the last build left for the caller to keep.
  String? _anchorKept;

  /// Speaks [text] in [voice], over [timbre] when the converter is loaded,
  /// and plays it. The file is the worker's and is dropped afterwards.
  Future<void> previewVoice({
    required String text,
    required String voice,
    List<double> timbre = const [],
  }) async {
    final wavePath = await _inference.previewVoice(text: text, voice: voice, timbre: timbre);
    try {
      await _playInIsolate(wavePath);
    } finally {
      await _deleteIfPresent(wavePath);
    }
  }

  /// Starts the session the characters screen records through: the game's
  /// audio and the converter that measures a voice, with neither the
  /// translator nor the speech model loaded.
  Future<void> startCharacters(Map<String, Object?> config) async {
    _paused = false;
    _session = PipelineSession.characters;
    _recordingVoice = false;
    await LocalInferenceService.removeStaleAudio();
    final models = config['models']! as Map<String, String>;
    await _inference.start(
      embedOnly: true,
      threads: config['cpuThreads']! as int,
      speed: 1,
      pythonExecutable: config['pythonExecutable']! as String,
      requiresWhisper: false,
      voiceConverter: models['converter'],
      voiceConversionBackend: _backendFrom(config['voiceConversionBackend']),
      downloadedRuntimeDirectory: config['runtimeDirectory'] as String?,
    );
    final work = await LocalInferenceService.createWorkDirectory();
    final capture = Directory('${work.path}${Platform.pathSeparator}capture');
    await capture.create(recursive: true);
    _activeConfig = {...config, 'captureDirectory': capture.path};
    final pointer = jsonEncode(_activeConfig).toNativeUtf8();
    try {
      _throwIfError(ld_start(pointer.cast()));
    } catch (_) {
      await _inference.stop();
      rethrow;
    } finally {
      malloc.free(pointer);
    }
    _pollTimer ??= Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => _pollEvents(),
    );
  }

  /// Starts the session the voices of a scene are gathered through: the
  /// game's audio and the converter that hears who is speaking, with neither
  /// whisper nor the translator loaded.
  ///
  /// It is the characters session with the bank and the cast added and the
  /// recording gate left open: every phrase is placed, none is dubbed.
  Future<void> startScene(Map<String, Object?> config) async {
    _paused = false;
    _session = PipelineSession.scene;
    await LocalInferenceService.removeStaleAudio();
    final models = config['models']! as Map<String, String>;
    await _inference.start(
      embedOnly: true,
      threads: config['cpuThreads']! as int,
      speed: 1,
      pythonExecutable: config['pythonExecutable']! as String,
      requiresWhisper: false,
      voiceConverter: models['converter'],
      voiceConversionBackend: _backendFrom(config['voiceConversionBackend']),
      downloadedRuntimeDirectory: config['runtimeDirectory'] as String?,
      voiceBank: config['voiceBank'] as String?,
      characters: config['characters'] as String?,
      asHeard: config['asHeard'] as bool? ?? false,
    );
    final work = await LocalInferenceService.createWorkDirectory();
    final capture = Directory('${work.path}${Platform.pathSeparator}capture');
    await capture.create(recursive: true);
    _activeConfig = {...config, 'captureDirectory': capture.path};
    final pointer = jsonEncode(_activeConfig).toNativeUtf8();
    try {
      _throwIfError(ld_start(pointer.cast()));
    } catch (_) {
      await _inference.stop();
      rethrow;
    } finally {
      malloc.free(pointer);
    }
    _pollTimer ??= Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => _pollEvents(),
    );
  }

  /// Whether what the game says is measured for a card, or thrown away.
  ///
  /// What an ended recording heard is dropped: the screen has had its
  /// chance to keep the clip that earned the card.
  /// Opens or closes the take a card is recorded from.
  ///
  /// The capture holds it open meanwhile: neither a pause in the speech nor
  /// the length of a phrase ends it, so what the card is measured from is
  /// everything the player heard between pressing record and pressing stop.
  /// Closing it waits for that recording to be written and measured — it is
  /// the only one the take has, and the card is nothing without it.
  Future<void> setRecordingVoice({required bool recording}) async {
    if (recording) {
      _dropRecordedClips();
      _recordingVoice = true;
      ld_hold_take(1);
      return;
    }
    if (!_recordingVoice) return;
    // What the take had gathered when it was let go of. Nothing means the
    // game was silent throughout, and there is no recording to wait for.
    final held = ld_hold_take(0);
    if (held <= 0) {
      _recordingVoice = false;
      return;
    }
    final closing = Completer<void>();
    _takeClosing = closing;
    try {
      // Long enough for the capture's own wake-up, the file, and the
      // converter reading three minutes of it on a busy CPU.
      await closing.future.timeout(const Duration(seconds: 90));
    } on TimeoutException {
      // Nothing came of it after all: what was gathered held no voice.
    } finally {
      if (identical(_takeClosing, closing)) _takeClosing = null;
      _recordingVoice = false;
    }
  }

  /// Waiting for the recording a closed take leaves behind, if anything is.
  Completer<void>? _takeClosing;

  void _dropRecordedClips() {
    for (final clip in _recordedClips) {
      unawaited(_deleteIfPresent(clip));
    }
    _recordedClips.clear();
  }

  /// Plays a file to its end, outside the dubbing's own queue: a clip the
  /// player asked to hear is not a line of a scene.
  Future<void> playWave(String wavePath) => _playInIsolate(wavePath);

  /// Ends whatever is sounding. A card's recording may run for three
  /// minutes, and the button that started it is the one that stops it.
  void stopWave() => ld_stop_wave();

  /// Carries a card's standing substitution into the running session, which
  /// read the cast when it started.
  Future<void> voiceCharacterAs(String character, String? target) =>
      _inference.voiceCharacterAs(character, target);

  /// Tells a running session that the cast is out of the mix, or back in it.
  /// The config the session started with is kept in step, so what the canvas
  /// says now is what a restart of it would be given.
  Future<void> readAsHeard(bool value) async {
    _activeConfig?['asHeard'] = value;
    await _inference.readAsHeard(value);
  }

  Future<void> stop() async {
    // A take left open belongs to a session that is ending.
    if (_recordingVoice) {
      ld_hold_take(0);
      _recordingVoice = false;
      if (!(_takeClosing?.isCompleted ?? true)) _takeClosing!.complete();
    }
    // Cleared first: segments captured moments ago are still travelling
    // through the queue, and failing them is expected once the user stops.
    _activeConfig = null;
    _paused = false;
    // Cleared before ld_stop, so the idle it announces belongs to no session
    // in particular and puts every screen that was showing one back to rest.
    _session = null;
    _recordingVoice = false;
    _dropRecordedClips();
    _previousOcrText = null;
    // ld_stop drops the hotkeys too; nothing is left for them to pause.
    _throwIfError(ld_stop());
    _pollEvents();
    _pollTimer?.cancel();
    _pollTimer = null;
    for (final phrase in _phrases.clear()) {
      final wavePath = phrase.wavePath;
      if (wavePath != null) unawaited(_deleteIfPresent(wavePath));
    }
    for (final wavePath in _playback.clear()) {
      unawaited(_deleteIfPresent(wavePath));
    }
    await _inference.stop();
  }

  Future<void> setProcessVolume(int processId, double volume) async {
    _throwIfError(ld_set_process_volume(processId, volume));
  }

  /// Rests or wakes the running session without tearing it down, so the
  /// worker keeps its models and resuming costs no startup.
  void setPaused(bool paused) {
    if (_activeConfig == null) return;
    _paused = paused;
    _throwIfError(ld_set_paused(paused ? 1 : 0));
    if (!paused) return;
    // Nothing heard before the pause is voiced after it.
    for (final phrase in _phrases.clear()) {
      final wavePath = phrase.wavePath;
      if (wavePath != null) unawaited(_deleteIfPresent(wavePath));
    }
    for (final wavePath in _playback.clear()) {
      unawaited(_deleteIfPresent(wavePath));
    }
    // The game plays at its own volume while dubbing rests. A device that
    // cannot be reached is no reason to refuse the pause, so the result is
    // not checked.
    ld_restore_process_volumes();
  }

  /// Registers the system-wide combinations that pause and resume the
  /// session, and the one held to select an area of the screen. Presses
  /// arrive as `hotkey` events, a selection as `snapshotReading` and then
  /// `snapshot`. A combination another program holds comes back as an error
  /// naming the action.
  ///
  /// [textLanguage] is the language a selected area is read in.
  void setHotkeys({
    Hotkey? pause,
    Hotkey? resume,
    Hotkey? snapshot,
    String textLanguage = 'en',
  }) {
    final config = jsonEncode({
      'snapshotLanguage': textLanguage,
      'pauseKey': pause?.keyCode ?? 0,
      'pauseModifiers': pause?.modifiers ?? 0,
      'resumeKey': resume?.keyCode ?? 0,
      'resumeModifiers': resume?.modifiers ?? 0,
      'snapshotKey': snapshot?.keyCode ?? 0,
      'snapshotModifiers': snapshot?.modifiers ?? 0,
    }).toNativeUtf8();
    try {
      _throwIfError(ld_set_hotkeys(config.cast()));
    } finally {
      malloc.free(config);
    }
  }

  /// Takes what the native side has gathered since the last tick — at most a
  /// handful, so one slow turn cannot hold the interface — and gives each
  /// event to the part that knows what to do with it.
  void _pollEvents() {
    for (var index = 0; index < 16; index++) {
      final json = _readNativeString(ld_poll_event_json, emptyAllowed: true);
      if (json.isEmpty) break;
      final event = jsonDecode(json) as Map<String, Object?>;
      switch (event['type']) {
        case 'audioSegment':
          _onCapturedAudio(event['path']! as String);
        case 'ocrText':
          _onScreenText(event['text']! as String);
        case 'snapshot':
          _onSnapshotText(event);
        default:
          _events.add(_ofSession(fromNativeEvent(event)));
      }
    }
  }

  /// A phrase the capture cut out of the game's sound.
  void _onCapturedAudio(String wavePath) {
    // A segment queued a moment before the pause is dropped like one
    // captured during it, and so is everything heard between recordings.
    if (_listening && !_betweenRecordings) {
      _phrases.add(PendingPhrase.audio(wavePath));
      return;
    }
    unawaited(_deleteIfPresent(wavePath));
  }

  /// Whether captured sound is wanted at all right now.
  bool get _listening => _activeConfig != null && !_paused;

  /// The characters screen holds the capture open between takes, and what it
  /// hears then belongs to nobody.
  bool get _betweenRecordings => _session == PipelineSession.characters && !_recordingVoice;

  /// Subtitles read off the screen: only what the line gained is voiced.
  void _onScreenText(String text) {
    if (!_listening) return;
    final fresh = freshOcrText(_previousOcrText, text);
    _previousOcrText = text;
    if (fresh != null) _phrases.add(PendingPhrase.text(fresh));
  }

  /// An area of the screen the player selected by hand. Read even while the
  /// dubbing rests: it was asked for, not overheard.
  void _onSnapshotText(Map<String, Object?> event) {
    if (_activeConfig == null) return;
    // OCR reports the lines on screen apart; the translator wants prose.
    final text = (event['text'] as String? ?? '').split(RegExp(r'\s+')).join(' ').trim();
    if (text.isNotEmpty) _phrases.add(PendingPhrase.text(text, snapshot: true));
    _events.add(event);
  }

  /// [event] with the session it belongs to written on it.
  ///
  /// The native side reports what the capture is doing and nothing about who
  /// asked for it, so the same `state` event served whichever screen was
  /// listening: the characters screen holding the worker showed a dubbing
  /// session on Live, and a live session turned on the recording buttons of
  /// a card that could record nothing. A state event with no session — the
  /// idle `ld_stop` announces — belongs to everyone: one session runs at a
  /// time, and stopping it stops whatever any screen was showing.
  Map<String, Object?> _ofSession(Map<String, Object?> event) =>
      (event['type'] == 'state' || event['type'] == 'startup') && _session != null
      ? {...event, 'session': _session!.name}
      : event;

  Future<void> _processPhrase(PendingPhrase phrase) {
    final wavePath = phrase.wavePath;
    return wavePath != null
        ? _processSegment(wavePath)
        : _processOcrText(phrase.text!, snapshot: phrase.snapshot);
  }

  /// Measures a recorded voice for a character's card and hands it over; the
  /// characters screen keeps the clearest one it hears.
  Future<void> _measureVoice(String wavePath) async {
    var kept = false;
    try {
      final heard = await _inference.fingerprint(wavePath);
      if (heard.vector.isEmpty) return;
      // Kept while the recording runs, so the screen can put the clip that
      // earned the card beside it and let the player hear it back.
      kept = _recordingVoice;
      if (kept) _recordedClips.add(wavePath);
      _events.add({
        'type': 'characterVoice',
        'vector': heard.vector,
        'gender': heard.gender,
        'seconds': heard.seconds,
        if (kept) 'clip': wavePath,
      });
    } catch (error) {
      _reportFailure(error);
    } finally {
      if (!kept) await _deleteIfPresent(wavePath);
      // Whoever is waiting for the take to close has what it heard now.
      if (!(_takeClosing?.isCompleted ?? true)) _takeClosing!.complete();
    }
  }

  /// Places a phrase among the voices of the scene without dubbing it, which
  /// is what Live does before the pipeline itself runs.
  Future<void> _listenForSpeaker(String wavePath) async {
    try {
      final heard = await _inference.listenSpeaker(wavePath);
      // Too short or too unvoiced to belong to anyone.
      if (heard.speaker == null) return;
      _events.add({
        'type': 'sceneVoice',
        'speaker': heard.speaker,
        'seconds': heard.seconds,
      });
    } catch (error) {
      _reportFailure(error);
    } finally {
      await _deleteIfPresent(wavePath);
    }
  }

  Future<void> _processSegment(String wavePath) async {
    // The characters screen listens for a voice, not for a phrase.
    if (_session == PipelineSession.characters) return _measureVoice(wavePath);
    // Live before it dubs: who is speaking, and nothing more.
    if (_session == PipelineSession.scene) return _listenForSpeaker(wavePath);
    // Two characters answering each other without a pause land in one
    // segment; each of their halves earns its own recognition and voice.
    for (final piece in await _splitBySpeaker(wavePath)) {
      await _recognizeSegment(piece);
    }
  }

  /// [wavePath] cut where the voice in it changes, or the recording itself
  /// when it holds one speaker — or when nobody can tell.
  Future<List<String>> _splitBySpeaker(String wavePath) async {
    final config = _activeConfig;
    if (config == null) return [wavePath];
    // The converter is what hears who is speaking; without it the segment
    // goes on whole.
    if ((config['models']! as Map<String, String>)['converter'] == null) return [wavePath];
    try {
      final cuts = await _inference.speakerCuts(wavePath);
      if (cuts.isEmpty) return [wavePath];
      final pieces = sliceWave(await File(wavePath).readAsBytes(), cuts);
      if (pieces.length < 2) return [wavePath];
      final stem = wavePath.endsWith('.wav')
          ? wavePath.substring(0, wavePath.length - 4)
          : wavePath;
      final written = <String>[];
      for (var index = 0; index < pieces.length; index++) {
        final piece = '$stem-$index.wav';
        await File(piece).writeAsBytes(pieces[index], flush: true);
        written.add(piece);
      }
      await _deleteIfPresent(wavePath);
      return written;
    } catch (error) {
      // Hearing a second speaker is a courtesy; a phrase nobody could split
      // is still a phrase, and it is dubbed whole.
      _reportFailure(error);
      return [wavePath];
    }
  }

  Future<void> _recognizeSegment(String wavePath) async {
    final started = Stopwatch()..start();
    try {
      final config = _activeConfig;
      if (config == null) return;
      final models = config['models']! as Map<String, String>;
      final result = await _inference.processSegment(
        wavePath: wavePath,
        whisperModel: models['whisper']!,
        threads: config['cpuThreads']! as int,
        translateSpeech: config['translateSpeech'] as bool? ?? true,
        speed: _pace(config),
      );
      _publishSpokenLanguage();
      if (result == null) return;
      await _publishResult(result, started.elapsedMilliseconds, original: '');
    } catch (error) {
      _reportFailure(error);
    } finally {
      await _deleteIfPresent(wavePath);
    }
  }

  Future<void> _processOcrText(String recognizedText, {bool snapshot = false}) async {
    final started = Stopwatch()..start();
    try {
      final config = _activeConfig;
      if (config == null) return;
      // Subtitles caption sounds the way whisper does: "[Music]" is not a line.
      final spoken = withoutSoundCaptions(recognizedText);
      if (spoken.isEmpty) {
        // A selection is waiting for its answer; this one held no words.
        if (snapshot) _events.add({'type': 'snapshot', 'text': ''});
        return;
      }
      // Text read in the dubbing language itself is voiced as it is.
      final result = await _inference.processText(
        spoken,
        translate: config['textLanguage'] != config['targetLanguage'],
        speed: _pace(config),
      );
      await _publishResult(
        result,
        started.elapsedMilliseconds,
        original: spoken,
        snapshot: snapshot,
      );
    } catch (error) {
      _reportFailure(error);
    }
  }

  /// The pace the next line is read at: the player's own, hurried while
  /// lines are already queued for the voice. Counted at the moment the line
  /// is asked for, which is the last moment anything can be done about it —
  /// the worker retimes the waveform as it synthesizes it.
  double _pace(Map<String, Object?> config) {
    final chosen = (config['ttsSpeed']! as num).toDouble();
    if (config['hurryWhenQueued'] != true) return chosen;
    return hurriedSpeed(chosen, _playback.waiting);
  }

  /// Announces the language whisper settled on, once, so the interface can
  /// show what auto-detection actually decided.
  void _publishSpokenLanguage() {
    final detected = _inference.spokenLanguage;
    if (detected == null || detected == _reportedLanguage) return;
    _reportedLanguage = detected;
    _events.add({'type': 'language', 'code': detected});
  }

  /// Work already in flight fails when the user stops the pipeline. That is
  /// the expected outcome of stopping, not something to alarm them with.
  void _reportFailure(Object error) {
    if (_activeConfig == null) return;
    _events.add({'type': 'error', 'failure': error});
  }

  Future<void> _publishResult(
    InferenceResult result,
    int latencyMs, {
    required String original,
    bool snapshot = false,
  }) async {
    _events.add({
      'type': 'transcript',
      'original': original,
      'english': result.english,
      'translated': result.translated,
      'latencyMs': latencyMs,
      if (snapshot) 'snapshot': true,
      // Who said it, so the scene list can offer the voice a replacement.
      'speaker': ?result.speaker,
    });
    // Which voice read it: the automatic choice can change it per phrase, so
    // the interface should not have to guess.
    if (result.voice.isNotEmpty && result.voice != _reportedVoice) {
      _reportedVoice = result.voice;
      _events.add({'type': 'voice', 'name': result.voice});
    }
    // A new character joined the bank, so the count in the settings is stale.
    if (result.bankSize case final size? when size != _reportedBankSize) {
      _reportedBankSize = size;
      _events.add({'type': 'voiceBank', 'size': size});
    }
    // A line that was already being translated when the pause came is shown
    // in the transcript, but the pause means quiet. A selection is the
    // exception: the player asked for that one.
    if (_paused && !snapshot) {
      unawaited(_deleteIfPresent(result.wavePath));
      return;
    }
    // The worker says who is speaking, so a different character may start
    // while the last one is still talking — when the settings allow it.
    _playback.add(result.wavePath, speaker: result.speaker);
  }

  /// Turns the game down for as long as the dubbing speaks, when the session
  /// asked for that rather than for a session-long duck.
  ///
  /// The capture hears the game through this same volume, but a line being
  /// voiced now was recorded and recognized seconds ago — what is turned
  /// down is what the player hears, not what the pipeline listens to. A line
  /// the game starts while the dubbing speaks is captured as quietly as it
  /// would have been under the session-long duck.
  ///
  /// A device that cannot be reached is no reason to drop the line, so the
  /// result is not checked.
  void _duckForSpeech({required bool speaking}) {
    final config = _activeConfig;
    if (config == null || config['duckWhileSpeaking'] != true) return;
    final processId = config['processId'] as int? ?? 0;
    if (processId == 0) return;
    if (speaking) {
      ld_set_process_volume(processId, (config['duckVolume'] as num?)?.toDouble() ?? 0.18);
    } else {
      ld_restore_process_volumes();
    }
  }

  Future<void> _playQueued(String wavePath) async {
    try {
      if (_activeConfig != null) await _playInIsolate(wavePath);
    } catch (error) {
      _reportFailure(error);
    } finally {
      await _deleteIfPresent(wavePath);
    }
  }

  /// Static so the isolate closure captures nothing but the path. Reaching it
  /// from an instance closure would drag the whole service — and its futures,
  /// which cannot cross an isolate boundary — into the message.
  static Future<void> _playInIsolate(String wavePath) => Isolate.run(() => _playWave(wavePath));

  /// The length in milliseconds of what was written, or a negative code.
  /// Static for the same reason, and run apart because a long file is a
  /// wait rather than a moment.
  static int _decodeAudio(String source, String target) {
    final from = source.toNativeUtf8();
    final to = target.toNativeUtf8();
    try {
      return ld_decode_audio(from.cast(), to.cast());
    } finally {
      malloc.free(from);
      malloc.free(to);
    }
  }

  static void _playWave(String wavePath) {
    final pointer = wavePath.toNativeUtf8();
    try {
      final code = ld_play_wave(pointer.cast());
      if (code < 0) {
        throw NativeEngineException(
          code,
          ld_error_message(code).cast<Utf8>().toDartString(),
        );
      }
    } finally {
      malloc.free(pointer);
    }
  }

  static Future<void> _deleteIfPresent(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Temporary audio cleanup is best effort.
    }
  }

  String _readNativeString(
    NativeStringReader reader, {
    bool emptyAllowed = false,
  }) {
    return readNativeUtf8String(
      reader,
      emptyAllowed: emptyAllowed,
      throwIfError: _throwIfError,
    );
  }

  void _throwIfError(int code) {
    if (code >= 0) return;
    final message = ld_error_message(code).cast<Utf8>().toDartString();
    throw NativeEngineException(code, message);
  }

  void dispose() {
    _pollTimer?.cancel();
    ld_stop();
    unawaited(_inference.stop());
    _events.close();
  }
}

/// An event from the native queue in the shape the rest of the app reads.
///
/// Native capture reports trouble as `{"type":"error","message":...}`, a
/// sentence in English, while the interface expects a [LoreDubFailure] under
/// `failure`. Passed on as it came, the error arrived with no failure and
/// cleared the banner instead of raising one.
Map<String, Object?> fromNativeEvent(Map<String, Object?> event) {
  // Windows has no text recognition for the language the text is read in.
  if (event['type'] == 'ocrLanguageMissing') {
    return {
      'type': 'error',
      'failure': LoreDubFailure(
        FailureCode.ocrLanguageMissing,
        detail: event['language'] as String?,
      ),
    };
  }
  // Windows refused a combination: another program already holds it.
  if (event['type'] == 'hotkeyTaken') {
    return {
      'type': 'error',
      'failure': LoreDubFailure(FailureCode.hotkeyTaken, detail: event['action'] as String?),
    };
  }
  if (event['type'] != 'error' || event['failure'] != null) return event;
  return {
    'type': 'error',
    'failure': LoreDubFailure(FailureCode.captureFailed, detail: event['message'] as String?),
  };
}

String readNativeUtf8String(
  NativeStringReader reader, {
  bool emptyAllowed = false,
  required void Function(int code) throwIfError,
}) {
  var required = reader(nullptr, 0);
  if (required < 0) throwIfError(required);
  if (required == 0 && emptyAllowed) return '';

  // A native value can grow between the size query and the copy (for example,
  // when a Windows process starts while the process list is being built).
  // Retry with the newly reported size instead of decoding an untouched or
  // undersized buffer.
  for (var attempt = 0; attempt < 8; attempt++) {
    final capacity = required + 1;
    final buffer = calloc<Char>(capacity);
    try {
      final written = reader(buffer, capacity);
      if (written < 0) throwIfError(written);
      if (written < capacity) {
        return buffer.cast<Utf8>().toDartString(length: written);
      }
      required = written;
    } finally {
      calloc.free(buffer);
    }
  }

  throw const FormatException(
    'Native UTF-8 value kept changing while it was being read',
  );
}

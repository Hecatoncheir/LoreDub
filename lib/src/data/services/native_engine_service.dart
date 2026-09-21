// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:collection';
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import '../../domain/compute_device.dart';
import '../../domain/engine_event.dart';
import '../../domain/failure.dart';
import '../../domain/glossary.dart';
import '../../domain/game_process.dart';
import '../../domain/hotkey.dart';
import '../../domain/ocr_region.dart';
import '../../domain/ocr_text_delta.dart';
import '../../domain/built_voice.dart';
import '../../domain/session_config.dart';
import '../../domain/pipeline_state.dart';
import '../../domain/monitor_layout.dart';
import '../../domain/sound_captions.dart';
import '../../domain/speech_pace.dart';
import '../../domain/voice_files.dart';
import '../../domain/wave_slices.dart';
import '../../native/lore_dub_native.g.dart';
import 'local_inference_service.dart';
import 'phrase_queue.dart';
import 'playback_scheduler.dart';

typedef NativeStringReader = int Function(Pointer<Char> output, int capacity);

/// Where the work directory is: what a start sweeps of stale audio, and what
/// the capture cuts the game's sound into.
typedef WorkDirectoryProvider = Future<Directory> Function();

/// A call into the library that answered with an error code.
///
/// A [LoreDubFailure] rather than an exception of its own: it reaches the
/// banner like everything else, and `describeFailure` shows anything that
/// is not one as it came -- so this used to be read by the player as
/// `NativeEngineException(-3): ...`.
LoreDubFailure nativeCallFailed(int code, String message) =>
    LoreDubFailure(FailureCode.nativeCallFailed, detail: '$code: $message');

/// What every start and every stop ask of the native library.
///
/// The tests load no native library, so these few calls are made through
/// here, where a test can answer in its place. Everything else the engine
/// asks of the library — volumes, hotkeys, a take, playback — it still asks
/// directly.
class NativeSessionCalls {
  const NativeSessionCalls();

  /// `ld_start`, given the config as the JSON it crosses the boundary as.
  int start(String configJson) {
    final pointer = configJson.toNativeUtf8();
    try {
      return ld_start(pointer.cast());
    } finally {
      malloc.free(pointer);
    }
  }

  /// `ld_stop`: ends the capture and drops the hotkeys with it.
  int stop() => ld_stop();

  /// `ld_poll_event_json`, read the way every native string is.
  int pollEvent(Pointer<Char> output, int capacity) => ld_poll_event_json(output, capacity);

  /// `ld_restore_process_volumes`.
  int restoreProcessVolumes() => ld_restore_process_volumes();

  /// `ld_error_message`: what a negative answer from any of them means.
  String errorMessage(int code) => ld_error_message(code).cast<Utf8>().toDartString();
}

class NativeEngineService {
  NativeEngineService({
    LocalInferenceService? inference,
    this._native = const NativeSessionCalls(),
    WorkDirectoryProvider? workDirectory,
  }) : _inference = inference ?? LocalInferenceService(),
       _workDirectory = workDirectory ?? LocalInferenceService.createWorkDirectory {
    _inference.onStartupProgress = (value, stage) =>
        _events.add(StartupProgressed(value: value, stage: stage, session: _session));
    _inference.onWorkerLost = _onWorkerLost;
    _playback.onSpeaking = _duckForSpeech;
  }

  final _events = StreamController<EngineEvent>.broadcast();
  final LocalInferenceService _inference;
  final NativeSessionCalls _native;
  final WorkDirectoryProvider _workDirectory;
  Timer? _pollTimer;
  late final _phrases = PhraseQueue(process: _processPhrase);

  /// Playback runs beside recognition instead of inside it. Voicing a reply
  /// takes as long as the reply itself, and holding the pipeline for that
  /// would put every later phrase further behind the game.
  late final _playback = PlaybackScheduler(play: _playQueued);

  /// What the running session was started with, kept in step with what is
  /// changed under it; null while the engine rests.
  SessionConfig? _active;
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

  /// Goes up with every start and every stop, so that a start coming back
  /// from one of its waits can tell whether it is still the one wanted.
  ///
  /// The minutes of a start are the worker's, and [LocalInferenceService]
  /// counts those itself. Counted here are the moments on either side of
  /// them: the stale audio cleared before the worker is asked for, and the
  /// capture directory made once it is up. A stop landing in the first found
  /// no start to cancel, so the start went on to bring a worker up and begin
  /// a capture for a session already stopped — under no session's name by
  /// then, which every screen took for its own. One landing in the second
  /// ended the worker and left the start to begin a capture with nothing
  /// behind it, where every phrase failed for want of a worker.
  var _starts = 0;

  /// The start whose worker the inference service holds or is bringing up;
  /// null once the engine has ended it.
  ///
  /// A start that fails after its worker came up ends that worker only while
  /// this still names it. Stopped, the worker is gone already; replaced, a
  /// later start may have the service by now, and stopping it would end a
  /// worker that was never this start's to end.
  int? _workerOf;

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

  Stream<EngineEvent> get events => _events.stream;
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

  /// Where the monitors stand, which is what a frame over the whole screen
  /// is a share of.
  Future<MonitorLayout> monitorLayout() async =>
      MonitorLayout.fromJson(jsonDecode(_readNativeString(ld_list_monitors_json)) as List<Object?>);

  /// What the machine's graphics adapters and GPU drivers offer.
  ///
  /// Only the hardware half is filled in: whether the runtime for a backend
  /// has been downloaded is a question for the storage service.
  Future<ComputeAvailability> probeGraphics() async {
    final json = _readNativeString(ld_probe_graphics_json);
    return ComputeAvailability.fromProbeJson(jsonDecode(json) as Map<String, Object?>);
  }

  /// Brings the worker up with what [plan] names. [embedOnly] loads the
  /// converter and nothing else; [speechOnly] the voice and the converter.
  Future<void> _load(
    WorkerPlan plan, {
    bool requiresWhisper = false,
    bool embedOnly = false,
    bool speechOnly = false,
  }) => _inference.start(
    embedOnly: embedOnly,
    speechOnly: speechOnly,
    translationModel: plan.models.translation ?? '',
    ttsModel: plan.models.speech ?? '',
    speaker: plan.speaker,
    threads: plan.threads,
    speed: plan.speed,
    pythonExecutable: plan.pythonExecutable,
    requiresWhisper: requiresWhisper,
    sourceLanguage: plan.sourceLanguage,
    translationPrefix: plan.translationPrefix,
    followSpeaker: plan.followSpeaker,
    revoice: plan.revoice,
    maleVoices: plan.maleVoices,
    femaleVoices: plan.femaleVoices,
    recognitionBackend: plan.backends.recognition,
    translationBackend: plan.backends.translation,
    speechBackend: plan.backends.speech,
    downloadedRuntimeDirectory: plan.runtimeDirectory,
    voiceConverter: plan.models.converter,
    voiceConversionBackend: plan.backends.voiceConversion,
    voiceBank: plan.voiceBank,
    characters: plan.characters,
    glossary: plan.glossary,
    asHeard: plan.asHeard,
  );

  Future<void> start(LiveSessionConfig config) => _startSession(config, (start) async {
    _reportedLanguage = null;
    _reportedVoice = null;
    _reportedBankSize = null;
    _playback.maxVoices = config.lines.overlapVoices ? overlappingVoices : 1;
    await _removeStaleAudio(start);
    await _bringUpWorker(start, () => _load(config.worker, requiresWhisper: true));
    _reportWorkerUp(start, {
      'translation': _inference.translationBackend,
      'speech': _inference.speechBackend,
      'voiceConversion': _inference.voiceConversionBackend,
    });
    _beginCapture(start, config, captureDirectory: await _captureDirectory(start));
  });

  /// Loads the translator and the voice for the screen session, and starts
  /// the capture that reads the subtitle frame.
  ///
  /// One session answers for both halves of the screen: what the frame
  /// gains as the game writes in it, and what the player picks out by hand
  /// while holding the snapshot key. Whisper takes no part in either --
  /// nothing here is heard -- so it is ready in seconds.
  Future<void> startScreenText(ScreenSessionConfig config) => _startSession(config, (start) async {
    _reportedLanguage = null;
    _reportedVoice = null;
    _reportedBankSize = null;
    // One line at a time is read, so there is no one to talk over.
    _playback.maxVoices = 1;
    await _removeStaleAudio(start);
    await _bringUpWorker(start, () => _load(config.worker));
    _reportWorkerUp(start, {
      'translation': _inference.translationBackend,
      'speech': _inference.speechBackend,
    });
    // A capture directory only where the game is listened to as well:
    // reading the screen alone cuts no sound into files, and the native
    // side asks for one only when it does.
    _beginCapture(
      start,
      config,
      captureDirectory: config.capture.cutsSound ? await _captureDirectory(start) : null,
    );
  });

  /// Loads the speech model and the converter, and nothing else: the
  /// characters screen plays a sample of a card's voice with them. Neither
  /// whisper nor the translator is wanted — the line is one the application
  /// wrote — so the screen waits seconds rather than a minute.
  Future<void> startPreview(PreviewSessionConfig config) => _startSession(config, (start) async {
    await _bringUpWorker(start, () => _load(config.worker, speechOnly: true));
    _listenWithoutCapture(start, config);
  });

  /// Loads the converter and nothing else, with no capture at all: the
  /// files a card is built from are already on disk, and there is no game
  /// to listen to. The screen waits seconds rather than a minute.
  Future<void> startVoiceFiles(VoiceFilesSessionConfig config) =>
      _startSession(config, (start) async {
        _recordingVoice = false;
        await _bringUpWorker(start, () => _load(config.worker, embedOnly: true));
        _listenWithoutCapture(start, config);
      });

  /// Turns the files at [paths] into recordings the converter can measure.
  ///
  /// Windows does the decoding, so a card takes whatever the machine can
  /// play -- ogg and opus included. Each file is brought to the rate and
  /// the loudness the capture writes at, or a fingerprint from a file would
  /// not answer for the same character a fingerprint from the game does.
  Future<VoiceFiles> decodeVoiceFiles(List<String> paths) async {
    final work = await _workDirectory();
    final decoded = <String, String>{};
    final unreadable = <String>[];
    for (final (index, source) in paths.indexed) {
      final target = '${work.path}${Platform.pathSeparator}dropped_$index.wav';
      final milliseconds = await Isolate.run(() => _decodeAudio(source, target));
      if (milliseconds < 0) {
        unreadable.add(source);
      } else {
        decoded[target] = source;
      }
    }
    if (decoded.isEmpty) {
      throw const LoreDubFailure(FailureCode.audioNotDecoded);
    }
    return VoiceFiles(decoded: decoded, unreadable: unreadable);
  }

  /// Hands the decoded [files] to the worker as one voice, and drops them
  /// once it has answered.
  Future<BuiltVoice> measureVoiceFiles(VoiceFiles files) async {
    String? anchor;
    try {
      final built = await _inference.buildVoice([...files.decoded.keys]);
      anchor = built.anchor;
      // The worker answers about the files it was handed; the player knows
      // the ones they dropped, so the two are put back together here.
      return BuiltVoice(
        vector: built.vector,
        gender: built.gender,
        seconds: built.seconds,
        used: built.used,
        skipped: [
          ...files.unreadable,
          for (final path in built.skipped) files.decoded[path] ?? path,
        ],
        agreement: built.agreement,
        weakest: built.weakest,
        together: built.together,
        anchor: built.anchor,
      );
    } finally {
      // The one the fingerprint stands closest to is left where it is: the
      // card keeps it to play back, and the caller drops it once it has been
      // copied there.
      await discardVoiceFiles(files, keeping: anchor);
    }
  }

  /// Drops the decoded [files] from the work directory, all but [keeping].
  Future<void> discardVoiceFiles(VoiceFiles files, {String? keeping}) async {
    for (final path in files.decoded.keys) {
      if (path != keeping) await _deleteIfPresent(path);
    }
  }

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
  Future<void> startCharacters(CharactersSessionConfig config) =>
      _startSession(config, (start) async {
        _recordingVoice = false;
        await _removeStaleAudio(start);
        await _bringUpWorker(start, () => _load(config.worker, embedOnly: true));
        _beginCapture(start, config, captureDirectory: await _captureDirectory(start));
      });

  /// Starts the session the voices of a scene are gathered through: the
  /// game's audio and the converter that hears who is speaking, with neither
  /// whisper nor the translator loaded.
  ///
  /// It is the characters session with the bank and the cast added and the
  /// recording gate left open: every phrase is placed, none is dubbed.
  Future<void> startScene(SceneSessionConfig config) => _startSession(config, (start) async {
    await _removeStaleAudio(start);
    await _bringUpWorker(start, () => _load(config.worker, embedOnly: true));
    _beginCapture(start, config, captureDirectory: await _captureDirectory(start));
  });

  /// Runs one start from its first line to its last.
  ///
  /// The session is named and the start numbered before anything is waited
  /// for, and [steps] is handed that number: every step asks, as it begins
  /// and after everything it waits for, whether the start is still the one
  /// wanted ([_throwIfSuperseded]).
  ///
  /// Whatever a start fails with — stopped, replaced, a capture that would
  /// not begin — the worker it brought up is ended here, while it is still
  /// this start's to end.
  Future<void> _startSession(
    SessionConfig config,
    Future<void> Function(int start) steps,
  ) async {
    final start = ++_starts;
    _paused = false;
    _session = config.session;
    try {
      await steps(start);
    } catch (_) {
      if (_workerOf == start) await _endWorker();
      rethrow;
    }
  }

  /// A start that was stopped, or replaced by a later one, ends here: what
  /// it was waiting for came back to nobody.
  void _throwIfSuperseded(int start) {
    if (start != _starts) throw const LoreDubFailure(FailureCode.pipelineStopped);
  }

  /// Clears away the audio a previous run left behind.
  Future<void> _removeStaleAudio(int start) async {
    _throwIfSuperseded(start);
    final work = await _workDirectory();
    // Asked before the sweep as well as after it: the start that took this
    // one's place may be cutting phrases into that directory by now.
    _throwIfSuperseded(start);
    await LocalInferenceService.removeStaleAudio(work);
    _throwIfSuperseded(start);
  }

  /// Brings the worker up through [load], as the start numbered [start].
  Future<void> _bringUpWorker(int start, Future<void> Function() load) async {
    _throwIfSuperseded(start);
    // Named before the service is asked, which is the moment it becomes this
    // start's: asking ends whatever worker an earlier start left in it.
    _workerOf = start;
    await load();
    _throwIfSuperseded(start);
  }

  /// Says where the worker put each stage in [settled] — which is not always
  /// where it was asked to — and that the capture is what is left to start.
  void _reportWorkerUp(int start, Map<String, ComputeBackend?> settled) {
    _throwIfSuperseded(start);
    for (final MapEntry(key: named, value: backend) in settled.entries) {
      final stage = ComputeStage.values.asNameMap()[named];
      if (stage == null || backend == null) continue;
      _events.add(BackendSettled(stage: stage, backend: backend));
    }
    _events.add(const StartupProgressed(value: 0.98, stage: 'capture'));
  }

  /// The directory the capture cuts the game's sound into, made if need be.
  Future<String> _captureDirectory(int start) async {
    _throwIfSuperseded(start);
    final work = await _workDirectory();
    _throwIfSuperseded(start);
    final capture = Directory('${work.path}${Platform.pathSeparator}capture');
    await capture.create(recursive: true);
    _throwIfSuperseded(start);
    return capture.path;
  }

  /// Starts the native capture [config] describes, and the reading of what
  /// it reports. Only the capture crosses into the library: the rest of the
  /// config is the worker's and this service's.
  void _beginCapture(int start, SessionConfig config, {String? captureDirectory}) {
    _throwIfSuperseded(start);
    _active = config;
    final capture = config.capture!;
    _throwIfError(
      _native.start(jsonEncode(capture.toNativeJson(captureDirectory: captureDirectory))),
    );
    _pollRegularly();
  }

  /// Comes up with no capture at all: the session is its worker and nothing
  /// else, so nothing native starts to say it is listening, and the engine
  /// says so itself.
  void _listenWithoutCapture(int start, SessionConfig config) {
    _throwIfSuperseded(start);
    _active = config;
    _pollRegularly();
    _events.add(SessionStateChanged(status: PipelineStatus.listening, session: _session));
  }

  void _pollRegularly() {
    _pollTimer ??= Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => _pollEvents(),
    );
  }

  /// Ends the worker, whichever start brought it up.
  Future<void> _endWorker() {
    _workerOf = null;
    return _inference.stop();
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

  /// Tells a running worker what the player has just written down. The
  /// file is read when a session starts, so without this an entry added
  /// while one runs would wait for the next start.
  Future<void> writeGlossary(Glossary glossary) => _inference.updateGlossary(glossary);

  /// Tells a running session which cards are out of the mix. The config the
  /// session started with is kept in step, so what the canvas says now is
  /// what a restart of it would be given.
  Future<void> readAsHeard(Set<String> value) async {
    _active = _active?.withAsHeard(value);
    await _inference.readAsHeard(value);
  }

  Future<void> stop() async {
    // First, and before anything here can fail: whichever start is still in
    // one of its waits is no longer wanted, and finds that out when it comes
    // back from it.
    _starts++;
    // A take left open belongs to a session that is ending.
    if (_recordingVoice) {
      ld_hold_take(0);
      _recordingVoice = false;
      if (!(_takeClosing?.isCompleted ?? true)) _takeClosing!.complete();
    }
    // Cleared first: segments captured moments ago are still travelling
    // through the queue, and failing them is expected once the user stops.
    _active = null;
    _paused = false;
    // Cleared before ld_stop, so the idle it announces belongs to no session
    // in particular and puts every screen that was showing one back to rest.
    _session = null;
    _recordingVoice = false;
    _dropRecordedClips();
    _previousOcrText = null;
    // ld_stop drops the hotkeys too; nothing is left for them to pause.
    _throwIfError(_native.stop());
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
    // What was read is kept only while the session that read it is up.
    while (_spoken.isNotEmpty) {
      unawaited(_deleteIfPresent(_spoken.removeFirst()));
    }
    // The game gets its own volume back, whichever duck took it: the
    // session-long one, or the one that lasts a line. Only the pause used to
    // do this, so a stopped session left the game quiet for good -- and the
    // next session then had nothing left to turn down, which is how it was
    // found: the dubbing seemed not to duck the original at all.
    // `_duckForSpeech` cannot do it either, since the line still sounding as
    // the session ends finishes after `_active` is already null.
    _native.restoreProcessVolumes();
    await _endWorker();
  }

  Future<void> setProcessVolume(int processId, double volume) async {
    _throwIfError(ld_set_process_volume(processId, volume));
  }

  /// Rests or wakes the running session without tearing it down, so the
  /// worker keeps its models and resuming costs no startup.
  void setPaused(bool paused) {
    if (_active == null) return;
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
    _native.restoreProcessVolumes();
  }

  /// Registers the system-wide combinations that pause and resume the
  /// session, and the two held to draw a rectangle over the screen. Presses
  /// arrive as `hotkey` events, a selection as `snapshotReading` and then
  /// `snapshot`, and a frame drawn over the game as `subtitleFrame`. A
  /// combination another program holds comes back as an error naming the
  /// action.
  ///
  /// [textLanguage] is the language a selected area is read in. [frameOf] is
  /// the process whose window the subtitle frame is measured against: zero
  /// leaves that key unbound, there being nothing to measure it in.
  void setHotkeys({
    Hotkey? pause,
    Hotkey? resume,
    Hotkey? snapshot,
    Hotkey? frame,
    Hotkey? frameOverlay,
    int frameOf = 0,
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
      'frameKey': frame?.keyCode ?? 0,
      'frameModifiers': frame?.modifiers ?? 0,
      'frameProcessId': frameOf,
      // The key that shows and hides the frame draws nothing itself: it
      // arrives as an event, and the application answers with showFrame or
      // hideFrame, knowing what the player asked for and over which game.
      'frameOverlayKey': frameOverlay?.keyCode ?? 0,
      'frameOverlayModifiers': frameOverlay?.modifiers ?? 0,
    }).toNativeUtf8();
    try {
      _throwIfError(ld_set_hotkeys(config.cast()));
    } finally {
      malloc.free(config);
    }
  }

  /// Draws the subtitle frame over the running game, or moves one already
  /// drawn. [processId] of zero measures it against the whole screen, as
  /// reading the screen does.
  void showFrame({required int processId, required OcrRegion region}) {
    final config = jsonEncode({
      'processId': processId,
      'ocrRegionLeft': region.left,
      'ocrRegionTop': region.top,
      'ocrRegionRight': region.right,
      'ocrRegionBottom': region.bottom,
    }).toNativeUtf8();
    try {
      _throwIfError(ld_show_frame(config.cast()));
    } finally {
      malloc.free(config);
    }
  }

  /// Takes that frame off the screen. Drawing nothing is no error.
  void hideFrame() => _throwIfError(ld_hide_frame());

  /// Reads the lines that follow in [voice]. The session keeps it too, so
  /// a line that asks what this session was started with is answered with
  /// the voice actually in use.
  Future<void> useVoice(String voice) async {
    final config = _active;
    if (config == null || config.worker.speaker == voice) return;
    _active = config.withSpeaker(voice);
    await _inference.useVoice(voice);
  }

  /// Takes what the native side has gathered since the last tick — at most a
  /// handful, so one slow turn cannot hold the interface — and gives each
  /// event to the part that knows what to do with it.
  void _pollEvents() {
    for (var index = 0; index < 16; index++) {
      final json = _readNativeString(_native.pollEvent, emptyAllowed: true);
      if (json.isEmpty) break;
      final event = jsonDecode(json) as Map<String, Object?>;
      switch (event['type']) {
        case 'audioSegment':
          _onCapturedAudio(event['path']! as String);
        case 'ocrText':
          _onScreenText(event['text']! as String);
        case 'snapshot':
          _onSnapshotText(event);
        case 'subtitleFrame':
          _onSubtitleFrame(event);
        default:
          if (fromNativeEvent(event, session: _session) case final typed?) {
            _events.add(typed);
          }
      }
    }
  }

  /// A phrase the capture cut out of the game's sound.
  void _onCapturedAudio(String wavePath) {
    // While the screen is what is read, the sound is not a phrase to dub
    // but the voice speaking as the words appeared: it is kept for the
    // next line the frame gains rather than queued.
    if (_listening && _session == PipelineSession.screen) {
      _rememberVoiceHeard(wavePath);
      return;
    }
    // A segment queued a moment before the pause is dropped like one
    // captured during it, and so is everything heard between recordings.
    if (_listening && !_betweenRecordings) {
      _phrases.add(PendingPhrase.audio(wavePath));
      return;
    }
    unawaited(_deleteIfPresent(wavePath));
  }

  /// The game's sound as it was last heard, while a screen session is
  /// following the voices, and the ones a line still waiting is to be
  /// coloured with. A file is kept until nothing points at it: the same
  /// voice may colour several lines, and a line may be voiced long after
  /// the sound it was placed by.
  String? _voiceHeard;
  final _voicesInUse = <String>{};

  /// Keeps [wavePath] as the voice of the moment and lets the one before it
  /// go, unless a line still waiting is to be read in it.
  void _rememberVoiceHeard(String wavePath) {
    final before = _voiceHeard;
    _voiceHeard = wavePath;
    if (before != null && before != wavePath && !_voicesInUse.contains(before)) {
      unawaited(_deleteIfPresent(before));
    }
  }

  /// Lets go of the voice a line was read in, now that it has been.
  Future<void> _releaseVoiceHeard(String? wavePath) async {
    if (wavePath == null) return;
    _voicesInUse.remove(wavePath);
    if (wavePath != _voiceHeard) await _deleteIfPresent(wavePath);
  }

  /// Whether captured sound is wanted at all right now.
  bool get _listening => _active != null && !_paused;

  /// The characters screen holds the capture open between takes, and what it
  /// hears then belongs to nobody.
  bool get _betweenRecordings => _session == PipelineSession.characters && !_recordingVoice;

  /// Subtitles read off the screen: only what the line gained is voiced.
  void _onScreenText(String text) {
    if (!_listening) return;
    final fresh = freshOcrText(_previousOcrText, text);
    _previousOcrText = text;
    if (fresh == null) return;
    // The voice heard as the line appeared, where the session is following
    // them: held until the line has been read in it.
    final heard = _voiceHeard;
    if (heard != null) _voicesInUse.add(heard);
    _phrases.add(PendingPhrase.text(fresh, heardWave: heard));
  }

  /// The subtitle frame, redrawn over the running game.
  ///
  /// The capture has already moved into it — the native side hands the new
  /// frame straight to the reading thread — so what is left here is to
  /// forget the text of the old frame, which the new one has nothing to do
  /// with, and to keep the config this session was started with honest. A
  /// selection that landed off the game's window comes back `failed` and
  /// changes nothing.
  void _onSubtitleFrame(Map<String, Object?> event) {
    if (_active == null) return;
    if (event['failed'] == true) {
      _events.add(const SubtitleFrameMoved(null));
      return;
    }
    double edge(String key) => (event[key] as num?)?.toDouble() ?? 0;
    final region = OcrRegion(
      left: edge('left'),
      top: edge('top'),
      right: edge('right'),
      bottom: edge('bottom'),
    );
    _previousOcrText = null;
    _active = _active?.withRegion(region);
    _events.add(SubtitleFrameMoved(region));
  }

  /// An area of the screen the player selected by hand. Read even while the
  /// dubbing rests: it was asked for, not overheard.
  void _onSnapshotText(Map<String, Object?> event) {
    if (_active == null) return;
    // OCR reports the lines on screen apart; the translator wants prose.
    final text = (event['text'] as String? ?? '').split(RegExp(r'\s+')).join(' ').trim();
    if (text.isNotEmpty) _phrases.add(PendingPhrase.text(text, snapshot: true));
    _events.add(SnapshotRead(text: text, failed: event['failed'] == true));
  }

  Future<void> _processPhrase(PendingPhrase phrase) {
    final wavePath = phrase.wavePath;
    return wavePath != null
        ? _processSegment(wavePath)
        : _processOcrText(
            phrase.text!,
            snapshot: phrase.snapshot,
            heardWave: phrase.heardWave,
          );
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
      _events.add(
        CharacterVoiceMeasured(
          vector: heard.vector,
          gender: heard.gender,
          seconds: heard.seconds,
          clip: kept ? wavePath : null,
        ),
      );
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
      _events.add(SceneVoiceHeard(speaker: heard.speaker, seconds: heard.seconds));
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
    final config = _active;
    if (config == null) return [wavePath];
    // The converter is what hears who is speaking; without it the segment
    // goes on whole.
    if (config.worker.models.converter == null) return [wavePath];
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
      final config = _active;
      final lines = config?.lines;
      if (config == null || lines == null) return;
      final result = await _inference.processSegment(
        wavePath: wavePath,
        whisperModel: config.worker.models.whisper!,
        threads: config.worker.threads,
        translateSpeech: lines.translateSpeech,
        roughRecognition: lines.roughRecognition,
        // What whisper hands over is English; dubbing into English reads it
        // as it is, and the worker was started without a translator anyway.
        translate: lines.translatesHeard,
        speed: _pace(lines),
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

  Future<void> _processOcrText(
    String recognizedText, {
    bool snapshot = false,
    String? heardWave,
  }) async {
    final started = Stopwatch()..start();
    try {
      final lines = _active?.lines;
      if (lines == null) return;
      // Subtitles caption sounds the way whisper does: "[Music]" is not a line.
      final spoken = withoutSoundCaptions(recognizedText);
      if (spoken.isEmpty) {
        // A selection is waiting for its answer; this one held no words.
        if (snapshot) _events.add(const SnapshotRead(text: ''));
        return;
      }
      // Text read in the dubbing language itself is voiced as it is.
      final result = await _inference.processText(
        spoken,
        // The voice heard as the words appeared, so the worker can place
        // the speaker and lay their timbre over the reading.
        originalWavePath: heardWave,
        translate: lines.translatesText,
        speed: _pace(lines),
      );
      await _publishResult(
        result,
        started.elapsedMilliseconds,
        original: spoken,
        snapshot: snapshot,
      );
    } catch (error) {
      _reportFailure(error);
    } finally {
      await _releaseVoiceHeard(heardWave);
    }
  }

  /// The pace the next line is read at: the player's own, hurried while
  /// lines are already queued for the voice. Counted at the moment the line
  /// is asked for, which is the last moment anything can be done about it —
  /// the worker retimes the waveform as it synthesizes it.
  double _pace(LineRules lines) {
    if (!lines.hurryWhenQueued) return lines.speed;
    return hurriedSpeed(lines.speed, _playback.waiting);
  }

  /// Announces the language whisper settled on, once, so the interface can
  /// show what auto-detection actually decided.
  void _publishSpokenLanguage() {
    final detected = _inference.spokenLanguage;
    if (detected == null || detected == _reportedLanguage) return;
    _reportedLanguage = detected;
    _events.add(LanguageDetected(detected));
  }

  /// Work already in flight fails when the user stops the pipeline. That is
  /// the expected outcome of stopping, not something to alarm them with.
  void _reportFailure(Object error) {
    if (_active == null) return;
    _events.add(EngineFailed(error));
  }

  /// The worker died under a running session. The capture would go on
  /// cutting phrases for nobody — each one told there is no worker — so the
  /// session ends here, and the player is told what the worker said.
  void _onWorkerLost(LoreDubFailure failure) {
    // Said before the stop, which clears the session the failure is about;
    // the phrases that were in flight fail after it and are passed over.
    _events.add(EngineFailed(failure));
    unawaited(
      stop().catchError((Object error) {
        if (!_events.isClosed) _events.add(EngineFailed(error));
      }),
    );
  }

  Future<void> _publishResult(
    InferenceResult result,
    int latencyMs, {
    required String original,
    bool snapshot = false,
  }) async {
    _events.add(
      LineDubbed(
        line: TranscriptEntry(
          original: original,
          english: result.english,
          translated: result.translated,
          latency: Duration(milliseconds: latencyMs),
          // Shown as heard and passed over, rather than as a line that
          // arrived with nothing in it.
          silenced: result.silenced,
          // Who said it, so the scene list can offer the voice a
          // replacement.
          speaker: result.speaker,
          // What it was read as, so the line can be heard again.
          spoken: result.wavePath,
        ),
        snapshot: snapshot,
      ),
    );
    // Which voice read it: the automatic choice can change it per phrase, so
    // the interface should not have to guess.
    if (result.voice.isNotEmpty && result.voice != _reportedVoice) {
      _reportedVoice = result.voice;
      _events.add(VoiceSpoken(result.voice));
    }
    // A new character joined the bank, so the count in the settings is stale.
    if (result.bankSize case final size? when size != _reportedBankSize) {
      _reportedBankSize = size;
      _events.add(VoiceBankGrew(size));
    }
    // A line that was already being translated when the pause came is shown
    // in the transcript, but the pause means quiet. A selection is the
    // exception: the player asked for that one.
    final wavePath = result.wavePath;
    // A line the player silenced has no audio at all: it was never
    // synthesized, so there is nothing to play and nothing to delete.
    if (wavePath == null) return;
    if (_paused && !snapshot) {
      unawaited(_deleteIfPresent(wavePath));
      return;
    }
    // Kept after it has sounded, so the player can hear the line again
    // from the transcript rather than wait for the game to say it twice.
    _keepSpoken(wavePath);
    // The worker says who is speaking, so a different character may start
    // while the last one is still talking — when the settings allow it.
    _playback.add(wavePath, speaker: result.speaker);
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
    final lines = _active?.lines;
    if (lines == null || !lines.duckWhileSpeaking) return;
    final processId = _active?.capture?.processId ?? 0;
    if (processId == 0) return;
    if (speaking) {
      ld_set_process_volume(processId, lines.duckVolume);
    } else {
      _native.restoreProcessVolumes();
    }
  }

  Future<void> _playQueued(String wavePath) async {
    try {
      if (_active != null) await _playInIsolate(wavePath);
    } catch (error) {
      _reportFailure(error);
    }
  }

  /// How many readings are kept to be heard again: the lines the screens
  /// still list, and nothing older. Each is a few hundred kilobytes, and
  /// the lot goes when the session ends.
  static const _spokenKept = 60;
  final _spoken = Queue<String>();

  /// Keeps what a line was read as, and lets the oldest go.
  void _keepSpoken(String wavePath) {
    _spoken.addLast(wavePath);
    while (_spoken.length > _spokenKept) {
      unawaited(_deleteIfPresent(_spoken.removeFirst()));
    }
  }

  /// Plays a line the session has already read, as the transcript offers.
  /// A file the session has let go of is nothing to play.
  Future<void> speakAgain(String wavePath) async {
    if (!_spoken.contains(wavePath)) return;
    await _playInIsolate(wavePath);
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
        throw nativeCallFailed(code, ld_error_message(code).cast<Utf8>().toDartString());
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
    throw nativeCallFailed(code, _native.errorMessage(code));
  }

  void dispose() {
    // A start still on its way has nobody left to start for.
    _starts++;
    _pollTimer?.cancel();
    _native.stop();
    unawaited(_endWorker());
    _events.close();
  }
}

/// One event off the native queue as an [EngineEvent], or null for a kind
/// this build has nothing to do with.
///
/// This is the boundary: JSON is read here and nowhere above. Native
/// capture reports trouble as `{"type":"error","message":...}`, a sentence
/// in English, while the interface words a [LoreDubFailure] — passed on as
/// it came, the error arrived with no failure and cleared the banner
/// instead of raising one.
///
/// [session] is written onto a state event, because the native side reports
/// what the capture is doing and nothing about who asked for it: the same
/// state served whichever screen was listening, so the characters screen
/// holding the worker showed a dubbing session on Live. A state with no
/// session — the idle `ld_stop` announces — belongs to everyone.
EngineEvent? fromNativeEvent(Map<String, Object?> event, {PipelineSession? session}) =>
    switch (event['type']) {
      'state' => SessionStateChanged(
        status: switch (event['state']) {
          'listening' => PipelineStatus.listening,
          'starting' => PipelineStatus.starting,
          _ => PipelineStatus.idle,
        },
        session: session,
      ),
      'hotkey' => switch (HotkeyAction.named(event['action'])) {
        final action? => HotkeyPressed(action),
        // A key this build does not know: nothing to press.
        null => null,
      },
      // Windows has no text recognition for the language the text is read in.
      'ocrLanguageMissing' => EngineFailed(
        LoreDubFailure(FailureCode.ocrLanguageMissing, detail: event['language'] as String?),
      ),
      // Windows refused a combination: another program already holds it.
      'hotkeyTaken' => EngineFailed(
        LoreDubFailure(FailureCode.hotkeyTaken, detail: event['action'] as String?),
      ),
      'error' => EngineFailed(
        LoreDubFailure(FailureCode.captureFailed, detail: event['message'] as String?),
      ),
      _ => null,
    };

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

  // Eight tries at a value that grows between the size query and the copy
  // is a library that is not going to settle. Raised as a failure rather
  // than a `FormatException`, which the banner printed as it came.
  throw const LoreDubFailure(
    FailureCode.nativeCallFailed,
    detail: 'a native value kept changing while it was being read',
  );
}

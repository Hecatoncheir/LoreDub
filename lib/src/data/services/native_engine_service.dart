// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:collection';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

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
import '../../domain/voice_files.dart';
import 'local_inference_service.dart';
import 'phrase_queue.dart';
import 'playback_scheduler.dart';
import 'worker_arguments.dart';
import 'voice_take.dart';
import 'game_ducker.dart';
import 'native_bridge.dart';
import 'engine_session.dart';
import 'phrase_processor.dart';

/// Where the work directory is: what a start sweeps of stale audio, and what
/// the capture cuts the game's sound into.
typedef WorkDirectoryProvider = Future<Directory> Function();

class NativeEngineService {
  NativeEngineService({
    LocalInferenceService? inference,
    this._native = const NativeBridge(),
    WorkDirectoryProvider? workDirectory,
  }) : _inference = inference ?? LocalInferenceService(),
       _workDirectory = workDirectory ?? LocalInferenceService.createWorkDirectory {
    _inference.onStartupProgress = (value, stage) =>
        _events.add(StartupProgressed(value: value, stage: stage, session: _session));
    _inference.onWorkerLost = _onWorkerLost;
    _playback.onSpeaking = _ducker.speaking;
  }

  final _events = StreamController<EngineEvent>.broadcast();
  final LocalInferenceService _inference;
  final NativeBridge _native;
  final WorkDirectoryProvider _workDirectory;
  Timer? _pollTimer;
  late final _phrases = PhraseQueue(process: _processor.process);

  /// What becomes of each phrase, in the run that is up.
  late final _processor = PhraseProcessor(
    _inference,
    run: () => _run,
    emit: _events.add,
    take: _take,
    voice: (wavePath, {speaker}) {
      // Kept after it has sounded, so the player can hear the line again
      // from the transcript rather than wait for the game to say it twice.
      _keepSpoken(wavePath);
      _playback.add(wavePath, speaker: speaker);
    },
    waiting: () => _playback.waiting,
    releaseVoiceHeard: _releaseVoiceHeard,
    reportFailure: _reportFailure,
    discard: _deleteIfPresent,
  );

  /// How far the game is turned down, for the session or for a line.
  late final _ducker = GameDucker(
    setVolume: _native.setProcessVolume,
    restore: _native.restoreProcessVolumes,
  );

  /// Playback runs beside recognition instead of inside it. Voicing a reply
  /// takes as long as the reply itself, and holding the pipeline for that
  /// would put every later phrase further behind the game.
  late final _playback = PlaybackScheduler(play: _playQueued);

  /// The run of the engine under way, from its start to its stop; null
  /// while the engine rests. See [EngineSession].
  EngineSession? _run;

  /// Which session is running, or null while the engine rests.
  ///
  /// The engine serves the dubbing screens and the characters screen in
  /// turn, and what a captured segment is for depends on which of them holds
  /// it: recognized and voiced for live dubbing, measured for a card on the
  /// characters screen, only placed among the voices of a scene.
  PipelineSession? get _session => _run?.kind;

  /// What the running session was started with, once it is up.
  SessionConfig? get _active => (_run?.running ?? false) ? _run!.config : null;

  /// Whether the session rests.
  bool get _paused => _run?.paused ?? false;

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

  /// The take a card is recorded from. Between takes what the game says is
  /// thrown away.
  late final _take = VoiceTake(hold: _native.holdTake, discard: _deleteIfPresent);

  Stream<EngineEvent> get events => _events.stream;
  bool get processLoopbackSupported => _native.processLoopbackSupported;

  Future<List<GameProcess>> listProcesses() async {
    final json = _native.processesJson();
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
      MonitorLayout.fromJson(jsonDecode(_native.monitorsJson()) as List<Object?>);

  /// What the machine's graphics adapters and GPU drivers offer.
  ///
  /// Only the hardware half is filled in: whether the runtime for a backend
  /// has been downloaded is a question for the storage service.
  Future<ComputeAvailability> probeGraphics() async {
    final json = _native.graphicsJson();
    return ComputeAvailability.fromProbeJson(jsonDecode(json) as Map<String, Object?>);
  }

  /// Brings the worker up with what [plan] names, as much of it as [load]
  /// says.
  Future<void> _load(
    WorkerPlan plan, {
    bool requiresWhisper = false,
    WorkerLoad load = WorkerLoad.full,
  }) => _inference.start(plan, requiresWhisper: requiresWhisper, load: load);

  Future<void> start(LiveSessionConfig config) => _startSession(config, (start) async {
    _playback.maxVoices = config.lines.overlapVoices ? overlappingVoices : 1;
    await _removeStaleAudio(start);
    await _bringUpWorker(start, () => _load(config.worker, requiresWhisper: true));
    _reportWorkerUp(start, {
      'translation': _inference.translationBackend,
      'speech': _inference.speechBackend,
      'voiceConversion': _inference.voiceConversionBackend,
    });
    _beginCapture(start, config, captureDirectory: await _captureDirectory(start));
    _ducker.begin(config);
  });

  /// Loads the translator and the voice for the screen session, and starts
  /// the capture that reads the subtitle frame.
  ///
  /// One session answers for both halves of the screen: what the frame
  /// gains as the game writes in it, and what the player picks out by hand
  /// while holding the snapshot key. Whisper takes no part in either --
  /// nothing here is heard -- so it is ready in seconds.
  Future<void> startScreenText(ScreenSessionConfig config) => _startSession(config, (start) async {
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
    _ducker.begin(config);
  });

  /// Loads the speech model and the converter, and nothing else: the
  /// characters screen plays a sample of a card's voice with them. Neither
  /// whisper nor the translator is wanted — the line is one the application
  /// wrote — so the screen waits seconds rather than a minute.
  Future<void> startPreview(PreviewSessionConfig config) => _startSession(config, (start) async {
    await _bringUpWorker(start, () => _load(config.worker, load: WorkerLoad.speechOnly));
    _listenWithoutCapture(start, config);
  });

  /// Loads the converter and nothing else, with no capture at all: the
  /// files a card is built from are already on disk, and there is no game
  /// to listen to. The screen waits seconds rather than a minute.
  Future<void> startVoiceFiles(VoiceFilesSessionConfig config) =>
      _startSession(config, (start) async {
        _take.reset();
        await _bringUpWorker(start, () => _load(config.worker, load: WorkerLoad.embedOnly));
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
      final milliseconds = await Isolate.run(() => NativeBridge.decodeAudio(source, target));
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
        _take.reset();
        await _removeStaleAudio(start);
        await _bringUpWorker(start, () => _load(config.worker, load: WorkerLoad.embedOnly));
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
    await _bringUpWorker(start, () => _load(config.worker, load: WorkerLoad.embedOnly));
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
    _run = EngineSession(config);
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
    _run!.running = true;
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
    _run!.running = true;
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

  /// Opens or closes the take a card is recorded from. Closing it waits for
  /// what was recorded to be measured.
  Future<void> setRecordingVoice({required bool recording}) async {
    if (recording) return _take.open();
    await _take.close();
  }

  /// Plays a file to its end, outside the dubbing's own queue: a clip the
  /// player asked to hear is not a line of a scene.
  Future<void> playWave(String wavePath) => _playInIsolate(wavePath);

  /// Ends whatever is sounding. A card's recording may run for three
  /// minutes, and the button that started it is the one that stops it.
  void stopWave() => _native.stopWave();

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
    final run = _run;
    if (run != null) run.config = run.config.withAsHeard(value);
    await _inference.readAsHeard(value);
  }

  Future<void> stop() async {
    // First, and before anything here can fail: whichever start is still in
    // one of its waits is no longer wanted, and finds that out when it comes
    // back from it.
    _starts++;
    // A take left open belongs to a session that is ending.
    _take.abandon();
    // Cleared first: segments captured moments ago are still travelling
    // through the queue, and failing them is expected once the user stops.
    // Cleared before ld_stop as well, so the idle it announces belongs to no
    // session in particular and puts every screen that was showing one back
    // to rest.
    final ended = _run;
    _run = null;
    if (ended?.voiceHeard case final heard?) unawaited(_deleteIfPresent(heard));
    try {
      // ld_stop drops the hotkeys too; nothing is left for them to pause.
      _throwIfError(_native.stop());
      _pollEvents();
    } finally {
      // Whatever the library answered, the session is over here: a stop that
      // failed half-way left the poll running and the worker up for nobody.
      _endSessionHere();
      await _endWorker();
    }
  }

  /// What a stop clears on this side of the library, whatever the library
  /// said about its own.
  void _endSessionHere() {
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
    // The game gets its own volume back, whichever duck took it.
    _ducker.end();
  }

  /// Rests or wakes the running session without tearing it down, so the
  /// worker keeps its models and resuming costs no startup.
  void setPaused(bool paused) {
    final run = _run;
    if (run == null || !run.running) return;
    run.paused = paused;
    _throwIfError(_native.setPaused(paused: paused));
    if (!paused) return _ducker.resume();
    // Nothing heard before the pause is voiced after it.
    for (final phrase in _phrases.clear()) {
      final wavePath = phrase.wavePath;
      if (wavePath != null) unawaited(_deleteIfPresent(wavePath));
    }
    for (final wavePath in _playback.clear()) {
      unawaited(_deleteIfPresent(wavePath));
    }
    // The game plays at its own volume while dubbing rests.
    _ducker.rest();
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
    });
    _throwIfError(_native.setHotkeys(config));
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
    });
    _throwIfError(_native.showFrame(config));
  }

  /// Takes that frame off the screen. Drawing nothing is no error.
  void hideFrame() => _throwIfError(_native.hideFrame());

  /// Reads the lines that follow in [voice]. The session keeps it too, so
  /// a line that asks what this session was started with is answered with
  /// the voice actually in use.
  Future<void> useVoice(String voice) async {
    final run = _run;
    if (run == null || !run.running || run.config.worker.speaker == voice) return;
    run.config = run.config.withSpeaker(voice);
    await _inference.useVoice(voice);
  }

  /// Takes what the native side has gathered since the last tick — at most a
  /// handful, so one slow turn cannot hold the interface — and gives each
  /// event to the part that knows what to do with it.
  void _pollEvents() {
    for (var index = 0; index < 16; index++) {
      final json = readNativeUtf8String(
        _native.pollEvent,
        emptyAllowed: true,
        throwIfError: _throwIfError,
      );
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

  /// Keeps [wavePath] as the voice of the moment and lets the one before it
  /// go, unless a line still waiting is to be read in it.
  void _rememberVoiceHeard(String wavePath) {
    final run = _run!;
    final before = run.voiceHeard;
    run.voiceHeard = wavePath;
    if (before != null && before != wavePath && !run.voicesInUse.contains(before)) {
      unawaited(_deleteIfPresent(before));
    }
  }

  /// Lets go of the voice a line was read in, now that it has been.
  Future<void> _releaseVoiceHeard(String? wavePath) async {
    if (wavePath == null) return;
    final run = _run;
    run?.voicesInUse.remove(wavePath);
    if (wavePath != run?.voiceHeard) await _deleteIfPresent(wavePath);
  }

  /// Whether captured sound is wanted at all right now.
  bool get _listening => _active != null && !_paused;

  /// The characters screen holds the capture open between takes, and what it
  /// hears then belongs to nobody.
  bool get _betweenRecordings => _session == PipelineSession.characters && !_take.recording;

  /// Subtitles read off the screen: only what the line gained is voiced.
  void _onScreenText(String text) {
    if (!_listening) return;
    final run = _run!;
    final fresh = freshOcrText(run.previousOcrText, text);
    run.previousOcrText = text;
    if (fresh == null) return;
    // The voice heard as the line appeared, where the session is following
    // them: held until the line has been read in it.
    final heard = run.voiceHeard;
    if (heard != null) run.voicesInUse.add(heard);
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
    final run = _run!;
    run.previousOcrText = null;
    run.config = run.config.withRegion(region);
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
  static Future<void> _playInIsolate(String wavePath) =>
      Isolate.run(() => NativeBridge.playWave(wavePath));

  static Future<void> _deleteIfPresent(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Temporary audio cleanup is best effort.
    }
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

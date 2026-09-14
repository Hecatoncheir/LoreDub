// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as path;

import '../../../data/repositories/app_repository.dart';
import '../../../data/repositories/model_repository.dart';
import '../../../domain/app_settings.dart';
import '../../../domain/ocr_region.dart';
import '../../../domain/compute_device.dart';
import '../../../domain/game_process.dart';
import '../../../domain/model_package.dart';
import '../../../domain/model_selection.dart';
import '../../../domain/pipeline_state.dart';
import 'downloads_cubit.dart';
import 'settings_cubit.dart';
import 'shell_cubit.dart';

/// The running session: what it is doing, what it heard, and what it chose
/// to run on.
class LivePipelineState {
  const LivePipelineState({
    this.status = PipelineStatus.idle,
    this.transcript = const [],
    this.speakers = const [],
    this.processes = const [],
    this.selectedProcess,
    this.startupProgress,
    this.startupStage = '',
    this.detectedLanguage,
    this.spokenVoice,
    this.activeBackends = const {},
    this.session = PipelineSession.live,
    this.snapshots = const [],
    this.snapshotReading = false,
    this.snapshotMissed = false,
    this.frameMissed = false,
  });

  final PipelineStatus status;
  final List<TranscriptEntry> transcript;
  final List<GameProcess> processes;
  final GameProcess? selectedProcess;

  /// The voices this session has heard, in the order they first spoke, so
  /// the player can give any of them a character's voice.
  final List<SceneSpeaker> speakers;

  /// How far the pipeline is through starting, and what it is doing.
  final double? startupProgress;
  final String startupStage;

  /// The language auto-detection settled on, once whisper has reported it.
  final String? detectedLanguage;

  /// The voice the running session last read a line in, once it has.
  final String? spokenVoice;

  /// What a running pipeline reported it actually settled on, which can
  /// differ from the request when a driver turns out to be unusable.
  final Map<ComputeStage, ComputeBackend> activeBackends;

  /// Which session [status] describes. Meaningless while idle.
  final PipelineSession session;

  /// What the player selected and had translated, newest first. Kept apart
  /// from [transcript], which follows the running capture.
  final List<TranscriptEntry> snapshots;

  /// Set from the moment a selection is let go until its translation, or
  /// the news that it held no text, arrives.
  final bool snapshotReading;

  /// Whether the last selection held no text Windows could read.
  final bool snapshotMissed;

  /// Whether the last frame drawn over the game missed its window, so the
  /// subtitles go on being read where they were.
  final bool frameMissed;

  /// A paused session is still a session: its settings stay locked and its
  /// models loaded.
  bool get running =>
      status == PipelineStatus.starting ||
      status == PipelineStatus.listening ||
      status == PipelineStatus.paused;

  /// Live dubbing is up, starting or resting.
  bool get liveRunning => running && session == PipelineSession.live;

  /// The snapshot session is up and waiting for a selection.
  bool get screenRunning => session == PipelineSession.screen && status == PipelineStatus.listening;

  /// The scene session is up, placing the voices of the game without dubbing
  /// a word of it.
  bool get sceneRunning => session == PipelineSession.scene && running;

  /// The reported devices as a value that can be compared, so the compute
  /// card can be held still through everything else the session reports.
  String get backendSignature =>
      [for (final entry in activeBackends.entries) '${entry.key.name}:${entry.value.name}'].join();

  /// What a stage will run on: the live answer while the pipeline is up, the
  /// resolved intention otherwise.
  ComputeBackend backendFor(
    ComputeStage stage,
    AppSettings settings,
    ComputeAvailability availability,
  ) => activeBackends[stage] ?? settings.backendFor(stage, availability);

  /// Neither a running snapshot session nor one placing the voices of the
  /// scene stands in the way: starting live dubbing takes the worker over.
  bool canStart(ModelSelection selection, {required bool initializing}) =>
      !initializing &&
      (status == PipelineStatus.idle || screenRunning || sceneRunning) &&
      (!selection.requiresProcess || selectedProcess != null) &&
      // Taken apart on the graph, the pipeline has nothing to work on.
      selection.settings.captureRouted &&
      selection.requiredModelsInstalled;

  /// The scene session needs the converter, a bank to keep the voices it
  /// founds in, and — like dubbing — a game to listen to.
  bool canStartScene(ModelSelection selection, {required bool initializing}) =>
      !initializing &&
      (status == PipelineStatus.idle || sceneRunning) &&
      (!selection.requiresProcess || selectedProcess != null) &&
      selection.tracksSpeakers;

  /// The screen session needs its pair of models, a key to select with,
  /// and -- unless the whole screen is what it reads -- the game whose
  /// window the subtitle frame is taken out of.
  bool canStartScreen(ModelSelection selection, {required bool initializing}) =>
      !initializing &&
      status == PipelineStatus.idle &&
      (selection.settings.readsWholeScreen || selectedProcess != null) &&
      selection.screenModelsInstalled &&
      selection.settings.snapshotHotkey != null;

  LivePipelineState copyWith({
    PipelineStatus? status,
    List<TranscriptEntry>? transcript,
    List<SceneSpeaker>? speakers,
    List<GameProcess>? processes,
    GameProcess? selectedProcess,
    bool clearSelectedProcess = false,
    double? startupProgress,
    bool clearStartupProgress = false,
    String? startupStage,
    String? detectedLanguage,
    bool clearDetectedLanguage = false,
    String? spokenVoice,
    bool clearSpokenVoice = false,
    Map<ComputeStage, ComputeBackend>? activeBackends,
    PipelineSession? session,
    List<TranscriptEntry>? snapshots,
    bool? snapshotReading,
    bool? snapshotMissed,
    bool? frameMissed,
  }) => LivePipelineState(
    status: status ?? this.status,
    transcript: transcript ?? this.transcript,
    speakers: speakers ?? this.speakers,
    processes: processes ?? this.processes,
    selectedProcess: clearSelectedProcess ? null : selectedProcess ?? this.selectedProcess,
    startupProgress: clearStartupProgress ? null : startupProgress ?? this.startupProgress,
    startupStage: startupStage ?? this.startupStage,
    detectedLanguage: clearDetectedLanguage ? null : detectedLanguage ?? this.detectedLanguage,
    spokenVoice: clearSpokenVoice ? null : spokenVoice ?? this.spokenVoice,
    activeBackends: activeBackends ?? this.activeBackends,
    session: session ?? this.session,
    snapshots: snapshots ?? this.snapshots,
    snapshotReading: snapshotReading ?? this.snapshotReading,
    snapshotMissed: snapshotMissed ?? this.snapshotMissed,
    frameMissed: frameMissed ?? this.frameMissed,
  );
}

class PipelineCubit extends Cubit<LivePipelineState> {
  PipelineCubit(
    this._appRepository,
    this._modelRepository,
    this._settings,
    this._downloads,
    this._errors, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const LivePipelineState());

  /// How long after a start a second press is taken for the rest of a
  /// double-click. Windows counts clicks as double within 500 ms by default.
  static const doubleClickGrace = Duration(milliseconds: 800);

  final AppRepository _appRepository;
  final ModelRepository _modelRepository;
  final SettingsCubit _settings;
  final DownloadsCubit _downloads;
  final FailureSink _errors;
  final DateTime Function() _clock;
  StreamSubscription<Map<String, Object?>>? _events;

  /// Ends the session another screen holds, so that starting one here takes
  /// the worker over rather than colliding with it. The characters screen is
  /// the one screen that keeps a session of its own; [DashboardCubits] wires
  /// this up, so neither cubit has to know the other.
  Future<void> Function()? releaseWorker;

  /// When the last start was asked for. The button that starts the pipeline
  /// also cancels a start in progress, so without this a double-click would
  /// start and cancel at once and leave "Stopped" with nothing to explain it.
  DateTime? _startRequestedAt;

  ModelSelection get _selection =>
      ModelSelection(models: _downloads.state.models, settings: _settings.settings);

  void listen() => _events = _appRepository.events.listen(_handleEvent);

  Future<void> loadProcesses() async {
    final processes = await _appRepository.listProcesses();
    if (isClosed) return;
    emit(state.copyWith(processes: processes));
  }

  void selectProcess(GameProcess? value) =>
      emit(state.copyWith(selectedProcess: value, clearSelectedProcess: value == null));

  Future<void> refreshProcesses() async {
    final processes = await _appRepository.listProcesses();
    if (isClosed) return;
    final matches = processes.where((process) => process.pid == state.selectedProcess?.pid);
    emit(
      state.copyWith(
        processes: processes,
        selectedProcess: matches.firstOrNull,
        clearSelectedProcess: matches.isEmpty,
      ),
    );
  }

  Future<void> toggle({required bool initializing}) async {
    if (_pressedTwice) return;
    _errors.report(null);
    if (state.liveRunning) return stop();
    final selection = _selection;
    if (!state.canStart(selection, initializing: initializing)) return;
    // The snapshot session holds the worker loaded without whisper, so live
    // dubbing takes it over by starting afresh.
    if (state.running) {
      await stop();
      if (isClosed || state.status != PipelineStatus.idle) return;
    }
    _startRequestedAt = _clock();
    // The characters screen holds the worker with no whisper in it, the way
    // a snapshot session does; starting here takes it over.
    await releaseWorker?.call();
    if (isClosed) return;
    emit(
      state.copyWith(
        status: PipelineStatus.starting,
        session: PipelineSession.live,
        clearStartupProgress: true,
        startupStage: '',
        clearDetectedLanguage: true,
        clearSpokenVoice: true,
        // Whoever spoke in the last session is not in this one yet. Who
        // reads whom is not kept here at all: it is the graph's, and it is
        // in the cards.
        speakers: const [],
      ),
    );
    await _startLive(selection);
  }

  /// Whether the button was pressed again while the first press was still
  /// being answered. Starting takes minutes to show anything, and a second
  /// press would start a second session over the first.
  bool get _pressedTwice {
    if (state.status != PipelineStatus.starting) return false;
    final startedAt = _startRequestedAt;
    return startedAt != null && _clock().difference(startedAt) < doubleClickGrace;
  }

  /// Hands the engine everything one live session needs.
  Future<void> _startLive(ModelSelection selection) async {
    try {
      final settings = _settings.settings;
      final translation = selection.forTargetLanguage(ModelKind.translation)!.model;
      final speech = selection.forTargetLanguage(ModelKind.speech)!.model;
      await _appRepository.start(
        process: selection.requiresProcess ? state.selectedProcess : null,
        settings: settings,
        modelDirectories: await _modelDirectories(selection),
        speaker: selection.voice,
        translationPrefix: translation.translationPrefix ?? '',
        translateSpeech: selection.recognitionTranslatesSpeech,
        followSpeaker: selection.followsSpeaker,
        // The converter may be loaded only to hear who is speaking.
        revoice: selection.clonesVoice,
        maleVoices: speech.voicesOf(VoiceGender.male),
        femaleVoices: speech.voicesOf(VoiceGender.female),
        recognitionBackend: _backendFor(ComputeStage.recognition),
        translationBackend: _backendFor(ComputeStage.translation),
        voiceConversionBackend: _backendFor(ComputeStage.voiceConversion),
        runtimeDirectory: _downloads.state.runtimeDirectoryPath,
        // Kept per game, so one game's cast does not answer for another's.
        voiceBank: selection.keepsVoiceBank
            ? await _appRepository.voiceBankFileFor(state.selectedProcess?.name ?? '')
            : null,
      );
    } catch (exception) {
      if (isClosed) return;
      emit(state.copyWith(status: PipelineStatus.error));
      _errors.report(exception);
    }
  }

  /// Where each model this session runs on actually sits. Whisper and the
  /// speech model are named by file, the other two by directory.
  Future<Map<String, String>> _modelDirectories(ModelSelection selection) async {
    final recognition = selection.recognition!.model;
    final translation = selection.forTargetLanguage(ModelKind.translation)!.model;
    final speech = selection.forTargetLanguage(ModelKind.speech)!.model;
    return {
      'whisper': path.join(
        await _modelRepository.directoryFor(recognition),
        recognition.primaryFileName,
      ),
      'translation': await _modelRepository.directoryFor(translation),
      'speech': path.join(
        await _modelRepository.directoryFor(speech),
        speech.primaryFileName,
      ),
      if (selection.needsVoiceConverter)
        'converter': await _modelRepository.directoryFor(selection.voiceConverter!.model),
    };
  }

  /// Where [stage] runs, given what this machine turned out to have.
  ComputeBackend _backendFor(ComputeStage stage) =>
      _settings.settings.backendFor(stage, _downloads.state.availability);

  /// Starts or ends the screen session: the subtitle frame is read while it
  /// runs, and the snapshot key picks anything else off the screen by hand.
  Future<void> toggleScreenText({required bool initializing}) async {
    if (_pressedTwice) return;
    _errors.report(null);
    if (state.running) {
      // Live dubbing is ended from its own screen.
      if (state.session == PipelineSession.screen) await stop();
      return;
    }
    final selection = _selection;
    if (!state.canStartScreen(selection, initializing: initializing)) return;
    _startRequestedAt = _clock();
    // The worker the characters screen holds has neither the translator nor
    // the voice loaded, so this session starts afresh over it.
    await releaseWorker?.call();
    if (isClosed) return;
    emit(
      state.copyWith(
        status: PipelineStatus.starting,
        session: PipelineSession.screen,
        clearStartupProgress: true,
        startupStage: '',
        clearSpokenVoice: true,
        snapshotReading: false,
        snapshotMissed: false,
        frameMissed: false,
        // The list under the frame is this session's, not the last one's.
        transcript: const [],
      ),
    );
    try {
      final settings = _settings.settings;
      final translation = selection.forTargetLanguage(ModelKind.translation)!.model;
      final speech = selection.forTargetLanguage(ModelKind.speech)!.model;
      final speechDirectory = await _modelRepository.directoryFor(speech);
      await _appRepository.startScreenText(
        process: state.selectedProcess,
        settings: settings,
        modelDirectories: {
          'translation': await _modelRepository.directoryFor(translation),
          'speech': path.join(speechDirectory, speech.primaryFileName),
        },
        // A selected line has no audio to follow the speaker by.
        speaker: selection.voice,
        translationPrefix: translation.translationPrefix ?? '',
        translationBackend: _backendFor(ComputeStage.translation),
        runtimeDirectory: _downloads.state.runtimeDirectoryPath,
      );
    } catch (exception) {
      if (isClosed) return;
      emit(state.copyWith(status: PipelineStatus.error));
      _errors.report(exception);
    }
  }

  /// Starts or ends the session that places the voices of the scene: the
  /// game's audio through the converter, with nothing translated or voiced.
  ///
  /// It is what the replacements are made against before dubbing runs — the
  /// voices it meets join the game's bank under the numbers the dubbing
  /// session will know them by — and it is ready in seconds, since neither
  /// whisper nor the translator is loaded.
  Future<void> toggleSceneVoices({required bool initializing}) async {
    if (_pressedTwice) return;
    _errors.report(null);
    if (state.running) {
      // Live dubbing and the snapshot session are ended where they started.
      if (state.session == PipelineSession.scene) await stop();
      return;
    }
    final selection = _selection;
    if (!state.canStartScene(selection, initializing: initializing)) return;
    _startRequestedAt = _clock();
    // Both sessions listen through the converter, but only one may hold the
    // worker; the one the characters screen started gives way.
    await releaseWorker?.call();
    if (isClosed) return;
    emit(
      state.copyWith(
        status: PipelineStatus.starting,
        session: PipelineSession.scene,
        clearStartupProgress: true,
        startupStage: '',
        speakers: const [],
      ),
    );
    try {
      final settings = _settings.settings;
      await _appRepository.startSceneVoices(
        process: selection.requiresProcess ? state.selectedProcess : null,
        settings: settings,
        converterDirectory: await _modelRepository.directoryFor(
          selection.voiceConverter!.model,
        ),
        converterBackend: _backendFor(ComputeStage.voiceConversion),
        runtimeDirectory: _downloads.state.runtimeDirectoryPath,
        // The same bank the dubbing session reads, so a voice met now is
        // the same voice then.
        voiceBank: await _appRepository.voiceBankFileFor(_game),
      );
    } catch (exception) {
      if (isClosed) return;
      emit(state.copyWith(status: PipelineStatus.error));
      _errors.report(exception);
    }
  }

  /// Ends the session, paused or not, and gives the game its volume back.
  Future<void> stop() async {
    if (!state.running) return;
    _errors.report(null);
    emit(state.copyWith(status: PipelineStatus.stopping));
    var status = PipelineStatus.idle;
    try {
      await _appRepository.stop();
    } catch (exception) {
      status = PipelineStatus.error;
      _errors.report(exception);
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        status: status,
        clearStartupProgress: true,
        startupStage: '',
        // The detection, the devices and the voice belonged to the session
        // that just ended.
        clearDetectedLanguage: true,
        clearSpokenVoice: true,
        activeBackends: const {},
        snapshotReading: false,
      ),
    );
    // The worker has written its last voices by now.
    unawaited(_settings.refreshVoiceBank());
  }

  /// Rests a listening session without tearing it down: the models stay
  /// loaded, so resuming is instant rather than another minute of startup.
  Future<void> pause() async {
    if (state.status != PipelineStatus.listening || !state.liveRunning) return;
    try {
      await _appRepository.pause();
      if (!isClosed) emit(state.copyWith(status: PipelineStatus.paused));
    } catch (exception) {
      _errors.report(exception);
    }
  }

  Future<void> resume() async {
    if (state.status != PipelineStatus.paused) return;
    try {
      await _appRepository.resume();
      if (!isClosed) emit(state.copyWith(status: PipelineStatus.listening));
    } catch (exception) {
      _errors.report(exception);
    }
  }

  /// The game the per-game files are kept under: its executable, or the one
  /// name the whole default output shares.
  String get _game => state.selectedProcess?.name ?? '';

  /// The scene list with this voice in it: one heard before keeps its place
  /// and shows what it just said, a new one joins the end.
  List<SceneSpeaker> _withSpeaker(String? key, {String line = '', double seconds = 0}) {
    if (key == null || key.isEmpty) return state.speakers;
    final at = state.speakers.indexWhere((speaker) => speaker.key == key);
    if (at < 0) {
      return [...state.speakers, SceneSpeaker(key: key, line: line, seconds: seconds)];
    }
    return [
      for (final speaker in state.speakers)
        if (speaker.key == key) speaker.heard(line: line, seconds: seconds) else speaker,
    ];
  }

  /// Empties the transcript. The pipeline is untouched: a running session
  /// keeps appending to the now-clear list.
  void clearTranscript() {
    if (state.transcript.isEmpty) return;
    emit(state.copyWith(transcript: const []));
  }

  /// Empties the list of selections, leaving the session alone.
  void clearSnapshots() {
    if (state.snapshots.isEmpty) return;
    emit(state.copyWith(snapshots: const []));
  }

  /// Hands one engine event to the part of the state it changes.
  ///
  /// The switch only names the handler: each kind of event is a method of a
  /// few lines below, so reading one of them never means reading the rest.
  void _handleEvent(Map<String, Object?> event) {
    switch (event['type']) {
      case 'state':
        _onSessionState(event);
      case 'transcript':
        _onTranscript(event);
      case 'sceneVoice':
        _onSceneVoice(event);
      case 'snapshotReading':
        emit(state.copyWith(snapshotReading: true, snapshotMissed: false));
      case 'snapshot':
        _onSnapshot(event);
      case 'subtitleFrame':
        _onSubtitleFrame(event);
      case 'startup':
        _onStartup(event);
      case 'language':
        _onDetectedLanguage(event);
      case 'voice':
        _onSpokenVoice(event);
      case 'voiceBank':
        // The event carries this game's count; the settings show all games.
        unawaited(_settings.refreshVoiceBank());
      case 'backend':
        _onBackend(event);
      case 'hotkey':
        _onHotkey(event);
      case 'error':
        _onError(event);
    }
  }

  /// The player redrew the subtitle frame over the running game.
  ///
  /// The capture is already reading the new one; what is kept here is the
  /// frame itself, so the picker on the screen shows where the reading
  /// moved to and the next session starts in the same place. A selection
  /// that missed the game's window changes nothing and says so.
  void _onSubtitleFrame(Map<String, Object?> event) {
    if (event['region'] case final OcrRegion region) {
      emit(state.copyWith(frameMissed: false));
      unawaited(_settings.update(_settings.settings.copyWith(ocrRegion: region)));
      return;
    }
    emit(state.copyWith(frameMissed: true));
  }

  /// The engine has started, come up or come to rest.
  void _onSessionState(Map<String, Object?> event) {
    // The engine serves the characters screen in its turn, and that session
    // is not this screen's to show. An event naming no session is the engine
    // coming to rest, which ends whatever was running.
    if (event['session'] case final String session when session != state.session.name) {
      return;
    }
    final status = switch (event['state']) {
      'ready' || 'listening' => PipelineStatus.listening,
      'starting' => PipelineStatus.starting,
      _ => PipelineStatus.idle,
    };
    emit(
      state.copyWith(
        status: status,
        clearStartupProgress: status != PipelineStatus.starting,
        startupStage: status == PipelineStatus.starting ? null : '',
      ),
    );
  }

  /// One dubbed line, from the capture or from a selection.
  void _onTranscript(Map<String, Object?> event) {
    final entry = TranscriptEntry(
      original: event['original'] as String? ?? '',
      english: event['english'] as String? ?? '',
      translated: event['translated'] as String? ?? '',
      latency: Duration(milliseconds: event['latencyMs'] as int? ?? 0),
      speaker: event['speaker'] as String?,
    );
    // A selection answers the player's request, not the running capture, so
    // it has a list of its own.
    if (event['snapshot'] == true) {
      emit(
        state.copyWith(
          snapshots: [entry, ...state.snapshots.take(49)],
          snapshotReading: false,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        transcript: [entry, ...state.transcript.take(49)],
        speakers: _withSpeaker(
          entry.speaker,
          line: entry.translated.trim().isEmpty ? entry.original : entry.translated,
        ),
      ),
    );
  }

  /// A voice placed before the dubbing runs: no words, only who spoke.
  void _onSceneVoice(Map<String, Object?> event) {
    emit(
      state.copyWith(
        speakers: _withSpeaker(
          event['speaker'] as String?,
          seconds: (event['seconds'] as num?)?.toDouble() ?? 0,
        ),
      ),
    );
  }

  /// What the screen selection was read as, or that nothing was read.
  void _onSnapshot(Map<String, Object?> event) {
    // Text that was found stays in reading until its translation lands.
    if ((event['text'] as String? ?? '').isNotEmpty) return;
    emit(state.copyWith(snapshotReading: false, snapshotMissed: event['failed'] != true));
  }

  /// How far the worker is through its startup.
  void _onStartup(Map<String, Object?> event) {
    emit(
      state.copyWith(
        startupProgress: (event['value'] as num?)?.toDouble(),
        clearStartupProgress: event['value'] == null,
        startupStage: event['stage'] as String? ?? '',
      ),
    );
  }

  /// The language whisper settled on, once it has settled on one.
  void _onDetectedLanguage(Map<String, Object?> event) {
    final code = event['code'] as String?;
    emit(state.copyWith(detectedLanguage: code, clearDetectedLanguage: code == null));
  }

  /// The voice the last line was read in.
  void _onSpokenVoice(Map<String, Object?> event) {
    final name = event['name'] as String?;
    emit(state.copyWith(spokenVoice: name, clearSpokenVoice: name == null));
  }

  /// Where a stage actually ended up running, which is not always what it
  /// was asked for. A stage or a backend this build does not know is left.
  void _onBackend(Map<String, Object?> event) {
    final stage = _valueNamed(ComputeStage.values, event['stage']);
    final backend = _valueNamed(ComputeBackend.values, event['backend']);
    if (stage == null || backend == null) return;
    emit(state.copyWith(activeBackends: {...state.activeBackends, stage: backend}));
  }

  /// A system-wide combination, pressed from inside the game.
  void _onHotkey(Map<String, Object?> event) {
    switch (event['action']) {
      case 'pause':
        unawaited(pause());
      case 'resume':
        unawaited(resume());
    }
  }

  /// Something went wrong with one phrase.
  ///
  /// A phrase failing does not stop the capture, so the pipeline keeps its
  /// state and the controls stay usable. Marking the session as failed here
  /// used to leave it stuck: neither startable nor stoppable. An event
  /// without a failure has nothing to show, and reporting null would clear a
  /// banner raised a moment earlier.
  void _onError(Map<String, Object?> event) {
    // Whatever failed, a selection still waiting will not be answered.
    if (state.snapshotReading) emit(state.copyWith(snapshotReading: false));
    if (event['failure'] case final failure?) _errors.report(failure);
  }

  /// The enum value written as [name], or null when nothing is.
  static T? _valueNamed<T extends Enum>(List<T> values, Object? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  /// Stages a state a widget test wants to render without starting anything.
  @visibleForTesting
  void seed(LivePipelineState value) => emit(value);

  @override
  Future<void> close() {
    _events?.cancel();
    _appRepository.dispose();
    return super.close();
  }
}

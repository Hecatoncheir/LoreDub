// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../../domain/screen_reading.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as path;

import '../../../data/repositories/install_repository.dart';
import '../../../data/repositories/sources_repository.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../data/repositories/model_repository.dart';
import '../../../domain/app_settings.dart';
import '../../../domain/compute_device.dart';
import '../../../domain/engine_event.dart';
import '../../../domain/failure.dart';
import '../../../domain/game_process.dart';
import '../../../domain/model_package.dart';
import '../../../domain/model_selection.dart';
import '../../../domain/pipeline_state.dart';
import '../../../domain/session_coordinator.dart';
import '../../../data/repositories/settings_repository.dart';
import 'shell_cubit.dart';

/// The running session: what it is doing, what it heard, and what it chose
/// to run on.
class LivePipelineState extends Equatable {
  const LivePipelineState({
    this.status = PipelineStatus.idle,
    this.startupProgress,
    this.startupStage = '',
    this.detectedLanguage,
    this.spokenVoice,
    this.activeBackends = const {},
    this.session = PipelineSession.live,
    this.screenReading = ScreenReading.both,
    this.frameMissed = false,
  });

  final PipelineStatus status;

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

  /// What the running session of the Screen page reads. Meaningless unless
  /// [session] is `PipelineSession.screen`: it is what tells the three
  /// buttons of that page which of them is the one running.
  final ScreenReading screenReading;

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

  /// A live session up and answering to pause or stop, which is when the
  /// start button gives its place to the session's two controls.
  bool get liveUp =>
      session == PipelineSession.live &&
      (status == PipelineStatus.listening || status == PipelineStatus.paused);

  /// A live session still loading its models.
  bool get liveStarting => session == PipelineSession.live && status == PipelineStatus.starting;

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
  ///
  /// [process] is the game named, which is not this state's: every screen
  /// shares it (`SourcesRepository`).
  bool canStart(
    ModelSelection selection, {
    required bool initializing,
    required GameProcess? process,
  }) =>
      !initializing &&
      (status == PipelineStatus.idle || screenRunning || sceneRunning) &&
      (!selection.requiresProcess || process != null) &&
      // Taken apart on the graph, the pipeline has nothing to work on.
      selection.settings.captureRouted &&
      selection.requiredModelsInstalled;

  /// The scene session needs the converter, a bank to keep the voices it
  /// founds in, and — like dubbing — a game to listen to.
  bool canStartScene(
    ModelSelection selection, {
    required bool initializing,
    required GameProcess? process,
  }) =>
      !initializing &&
      (status == PipelineStatus.idle || sceneRunning) &&
      (!selection.requiresProcess || process != null) &&
      selection.tracksSpeakers;

  /// The screen session needs its pair of models, and then what the
  /// reading itself asks for: a key to pick a snippet out with, and -- for
  /// the frame, unless the whole screen is what it reads -- the game whose
  /// window it is taken out of.
  ///
  /// A session of another reading is no obstacle: pressing the button of
  /// one ends the other and starts this one.
  bool canStartScreen(
    ModelSelection selection, {
    required bool initializing,
    required GameProcess? process,
    ScreenReading reading = ScreenReading.both,
  }) =>
      !initializing &&
      (status == PipelineStatus.idle || screenRunning) &&
      selection.screenModelsInstalled &&
      (!reading.readsSubtitles || selection.settings.readsWholeScreen || process != null) &&
      (!reading.readsSnippets || selection.settings.snapshotHotkey != null);

  LivePipelineState copyWith({
    PipelineStatus? status,
    double? startupProgress,
    bool clearStartupProgress = false,
    String? startupStage,
    String? detectedLanguage,
    bool clearDetectedLanguage = false,
    String? spokenVoice,
    bool clearSpokenVoice = false,
    Map<ComputeStage, ComputeBackend>? activeBackends,
    PipelineSession? session,
    ScreenReading? screenReading,
    bool? frameMissed,
  }) => LivePipelineState(
    status: status ?? this.status,
    startupProgress: clearStartupProgress ? null : startupProgress ?? this.startupProgress,
    startupStage: startupStage ?? this.startupStage,
    detectedLanguage: clearDetectedLanguage ? null : detectedLanguage ?? this.detectedLanguage,
    spokenVoice: clearSpokenVoice ? null : spokenVoice ?? this.spokenVoice,
    activeBackends: activeBackends ?? this.activeBackends,
    session: session ?? this.session,
    screenReading: screenReading ?? this.screenReading,
    frameMissed: frameMissed ?? this.frameMissed,
  );

  @override
  List<Object?> get props => [
    status,
    startupProgress,
    startupStage,
    detectedLanguage,
    spokenVoice,
    activeBackends,
    session,
    screenReading,
    frameMissed,
  ];
}

class PipelineCubit extends Cubit<LivePipelineState> {
  PipelineCubit(
    this._appRepository,
    this._modelRepository,
    this._settings,
    this._downloads,
    this._sources,
    this._errors,
    this._sessions, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const LivePipelineState()) {
    // What is drawn over the game is made of the settings, so it follows
    // them from here rather than being called by whoever wrote one.
    _written = _settings.changes.listen((_) {
      followFrameOverlay();
      unawaited(_followVoice());
    });
    // The frame is drawn over the game, so naming another one -- here or
    // on any other screen -- moves it.
    _picked = _sources.changes
        .map((sources) => sources.selected)
        .distinct()
        .listen((_) => followFrameOverlay());
  }

  /// How long after a start a second press is taken for the rest of a
  /// double-click. Windows counts clicks as double within 500 ms by default.
  static const doubleClickGrace = Duration(milliseconds: 800);

  final AppRepository _appRepository;
  final ModelRepository _modelRepository;
  final SettingsRepository _settings;
  final InstallRepository _downloads;
  final SourcesRepository _sources;
  final FailureSink _errors;
  final SessionCoordinator _sessions;
  final DateTime Function() _clock;
  StreamSubscription<EngineEvent>? _events;
  StreamSubscription<AppSettings>? _written;
  StreamSubscription<GameProcess?>? _picked;

  /// The game every screen listens to.
  GameProcess? get _process => _sources.sources.selected;

  /// When the last start was asked for. The button that starts the pipeline
  /// also cancels a start in progress, so without this a double-click would
  /// start and cancel at once and leave "Stopped" with nothing to explain it.
  DateTime? _startRequestedAt;

  /// What the settings and the downloads together say a session will use.
  /// Read from the graph as well, which asks it what a link would change.
  ModelSelection get selection =>
      ModelSelection(models: _downloads.parts.models, settings: _settings.settings);

  void listen() => _events = _appRepository.events.listen(_handleEvent);

  Future<void> toggle({required bool initializing}) async {
    if (_pressedTwice) return;
    _errors.report(null);
    if (state.liveRunning) return stop();
    final selection = this.selection;
    if (!state.canStart(selection, initializing: initializing, process: _process)) return;
    // The snapshot session holds the worker loaded without whisper, so live
    // dubbing takes it over by starting afresh.
    if (state.running) {
      await stop();
      if (isClosed || state.status != PipelineStatus.idle) return;
    }
    _startRequestedAt = _clock();
    // The characters screen holds the worker with no whisper in it, the way
    // a snapshot session does; starting here takes it over.
    await _sessions.makeRoomForDubbing();
    if (isClosed) return;
    emit(
      state.copyWith(
        status: PipelineStatus.starting,
        session: PipelineSession.live,
        clearStartupProgress: true,
        startupStage: '',
        clearDetectedLanguage: true,
        clearSpokenVoice: true,
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
      // Dubbing into English has no translator to carry a target token.
      final translation = selection.translates
          ? selection.forTargetLanguage(ModelKind.translation)!.model
          : null;
      final speech = selection.forTargetLanguage(ModelKind.speech)!.model;
      await _appRepository.start(
        process: selection.requiresProcess ? _process : null,
        settings: settings,
        modelDirectories: await _modelDirectories(selection),
        speaker: selection.voice,
        translationPrefix: translation?.translationPrefix ?? '',
        translateSpeech: selection.recognitionTranslatesSpeech,
        followSpeaker: selection.followsSpeaker,
        // The converter may be loaded only to hear who is speaking.
        revoice: selection.clonesVoice,
        maleVoices: speech.voicesOf(VoiceGender.male),
        femaleVoices: speech.voicesOf(VoiceGender.female),
        recognitionBackend: _backendFor(ComputeStage.recognition),
        translationBackend: _backendFor(ComputeStage.translation),
        speechBackend: _backendFor(ComputeStage.speech),
        voiceConversionBackend: _backendFor(ComputeStage.voiceConversion),
        runtimeDirectory: _downloads.parts.runtimeDirectory,
        // Kept per game, so one game's cast does not answer for another's.
        voiceBank: selection.keepsVoiceBank
            ? await _appRepository.voiceBankFileFor(_process?.name ?? '')
            : null,
      );
    } catch (exception) {
      _onStartFailed(exception);
    }
  }

  /// A start that did not come up.
  ///
  /// One that was stopped is no failure: the button that starts a session
  /// also cancels a start in progress, and the start then ends the way it
  /// was asked to, with nothing to report.
  void _onStartFailed(Object exception) {
    if (isClosed) return;
    if (isPipelineStopped(exception)) return _onStartStopped();
    emit(state.copyWith(status: PipelineStatus.error));
    _errors.report(exception);
  }

  /// Stopped from this screen, the status has moved on already — [stop]
  /// says `stopping` before it waits for anything. Still `starting`, the
  /// worker was taken by another screen, which stops nothing here and tells
  /// this one nothing, so the start would go on looking alive for good.
  void _onStartStopped() {
    if (state.status != PipelineStatus.starting) return;
    emit(
      state.copyWith(status: PipelineStatus.idle, clearStartupProgress: true, startupStage: ''),
    );
  }

  /// Where each model this session runs on actually sits. Whisper and the
  /// speech model are named by file, the other two by directory.
  Future<Map<String, String>> _modelDirectories(ModelSelection selection) async {
    final recognition = selection.recognition!.model;
    // Dubbing into English names no translator: the session runs without one.
    final translation = selection.translates
        ? selection.forTargetLanguage(ModelKind.translation)!.model
        : null;
    final speech = selection.forTargetLanguage(ModelKind.speech)!.model;
    return {
      'whisper': path.join(
        await _modelRepository.directoryFor(recognition),
        recognition.primaryFileName,
      ),
      if (translation != null) 'translation': await _modelRepository.directoryFor(translation),
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
      _settings.settings.backendFor(stage, _downloads.parts.availability);

  /// Starts or ends a session of the Screen page, reading what [reading]
  /// says: the frame, the key, or both.
  ///
  /// The button of the reading that is running ends it; the button of
  /// another ends it and starts its own, since one engine serves the three
  /// and only what it captures differs.
  Future<void> toggleScreenText({
    required bool initializing,
    ScreenReading reading = ScreenReading.both,
  }) async {
    if (_pressedTwice) return;
    _errors.report(null);
    if (state.running) {
      // Live dubbing is ended from its own screen.
      if (state.session != PipelineSession.screen) return;
      final wasReading = state.screenReading;
      await stop();
      if (wasReading == reading || isClosed) return;
    }
    final selection = this.selection;
    final ready = state.canStartScreen(
      selection,
      initializing: initializing,
      process: _process,
      reading: reading,
    );
    if (!ready) return;
    _startRequestedAt = _clock();
    // The worker the characters screen holds has neither the translator nor
    // the voice loaded, so this session starts afresh over it.
    await _sessions.makeRoomForDubbing();
    if (isClosed) return;
    emit(
      state.copyWith(
        status: PipelineStatus.starting,
        session: PipelineSession.screen,
        screenReading: reading,
        clearStartupProgress: true,
        startupStage: '',
        clearSpokenVoice: true,
        frameMissed: false,
      ),
    );
    try {
      final settings = _settings.settings;
      // Read into English, there is nothing to translate: the same session
      // without Marian in it.
      final translation = selection.translates
          ? selection.forTargetLanguage(ModelKind.translation)!.model
          : null;
      final speech = selection.forTargetLanguage(ModelKind.speech)!.model;
      final speechDirectory = await _modelRepository.directoryFor(speech);
      // The voices behind the subtitles are followed only where the frame
      // is read at all, and only with the converter to hear them by.
      final converter = selection.voiceConverter;
      final hearsVoices =
          reading.readsSubtitles && settings.screenVoices && (converter?.installed ?? false);
      await _appRepository.startScreenText(
        reading: reading,
        hearsVoices: hearsVoices,
        // The same bank the dubbing session keeps, so a character met
        // while the subtitles are read is met again when it runs.
        voiceBank: hearsVoices ? await _appRepository.voiceBankFileFor(_game) : null,
        process: _process,
        settings: settings,
        modelDirectories: {
          if (translation != null) 'translation': await _modelRepository.directoryFor(translation),
          'speech': path.join(speechDirectory, speech.primaryFileName),
          if (hearsVoices) 'converter': await _modelRepository.directoryFor(converter!.model),
        },
        // What a line is read in where nothing was heard saying it: a
        // selected line has no sound of its own to follow a speaker by.
        speaker: selection.voice,
        translationPrefix: translation?.translationPrefix ?? '',
        translationBackend: _backendFor(ComputeStage.translation),
        speechBackend: _backendFor(ComputeStage.speech),
        converterBackend: _backendFor(ComputeStage.voiceConversion),
        runtimeDirectory: _downloads.parts.runtimeDirectory,
      );
    } catch (exception) {
      _onStartFailed(exception);
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
    final selection = this.selection;
    if (!state.canStartScene(selection, initializing: initializing, process: _process)) return;
    _startRequestedAt = _clock();
    // Both sessions listen through the converter, but only one may hold the
    // worker; the one the characters screen started gives way.
    await _sessions.makeRoomForDubbing();
    if (isClosed) return;
    emit(
      state.copyWith(
        status: PipelineStatus.starting,
        session: PipelineSession.scene,
        clearStartupProgress: true,
        startupStage: '',
      ),
    );
    try {
      final settings = _settings.settings;
      await _appRepository.startSceneVoices(
        process: selection.requiresProcess ? _process : null,
        settings: settings,
        converterDirectory: await _modelRepository.directoryFor(
          selection.voiceConverter!.model,
        ),
        converterBackend: _backendFor(ComputeStage.voiceConversion),
        runtimeDirectory: _downloads.parts.runtimeDirectory,
        // The same bank the dubbing session reads, so a voice met now is
        // the same voice then.
        voiceBank: await _appRepository.voiceBankFileFor(_game),
      );
    } catch (exception) {
      _onStartFailed(exception);
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
      ),
    );
    // The stop dropped every key the session held, the one that shows
    // the frame among them: it is the player's, not the session's.
    followFrameOverlay();
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
  String get _game => _process?.name ?? '';

  /// Hands one engine event to the part of the state it changes.
  ///
  /// The switch only names the handler: each kind of event is a method of a
  /// few lines below, so reading one of them never means reading the rest.
  /// [EngineEvent] is sealed, so a kind nobody answers is named by the
  /// analyzer rather than passed over at runtime.
  void _handleEvent(EngineEvent event) {
    switch (event) {
      case SessionStateChanged():
        _onSessionState(event);
      // The lists are `TranscriptBloc`'s, which hears the engine itself.
      case LineDubbed() || SceneVoiceHeard() || SnapshotReading() || SnapshotRead():
        break;
      case SubtitleFrameMoved():
        _onSubtitleFrame(event);
      case StartupProgressed():
        _onStartup(event);
      case LanguageDetected():
        emit(
          state.copyWith(
            detectedLanguage: event.code,
            clearDetectedLanguage: event.code == null,
          ),
        );
      case VoiceSpoken():
        emit(state.copyWith(spokenVoice: event.name, clearSpokenVoice: event.name == null));
      // The count beside the switch is the settings screen's, and it
      // follows the engine itself.
      case VoiceBankGrew():
        break;
      case BackendSettled():
        emit(
          state.copyWith(activeBackends: {...state.activeBackends, event.stage: event.backend}),
        );
      case HotkeyPressed():
        _onHotkey(event.action);
      case EngineFailed():
        _onError(event);
      // The cast screen's, and nothing to this one.
      case CharacterVoiceMeasured():
        break;
    }
  }

  /// The player redrew the subtitle frame over the running game.
  ///
  /// The capture is already reading the new one; what is kept here is the
  /// frame itself, so the picker on the screen shows where the reading
  /// moved to and the next session starts in the same place. A selection
  /// that missed the game's window changes nothing and says so.
  void _onSubtitleFrame(SubtitleFrameMoved event) {
    if (event.region case final region?) {
      emit(state.copyWith(frameMissed: false));
      unawaited(_settings.save(_settings.settings.copyWith(ocrRegion: region)));
      return;
    }
    emit(state.copyWith(frameMissed: true));
  }

  /// The engine has started, come up or come to rest.
  void _onSessionState(SessionStateChanged event) {
    // The engine serves the characters screen in its turn, and that session
    // is not this screen's to show. An event naming no session is the engine
    // coming to rest, which ends whatever was running.
    if (!event.concerns(state.session)) return;
    final status = event.status;
    emit(
      state.copyWith(
        status: status,
        clearStartupProgress: status != PipelineStatus.starting,
        startupStage: status == PipelineStatus.starting ? null : '',
      ),
    );
  }

  /// How far the worker is through its startup.
  void _onStartup(StartupProgressed event) {
    emit(
      state.copyWith(
        startupProgress: event.value,
        clearStartupProgress: event.value == null,
        startupStage: event.stage,
      ),
    );
  }

  /// A system-wide combination, pressed from inside the game.
  void _onHotkey(HotkeyAction action) {
    switch (action) {
      case HotkeyAction.pause:
        unawaited(pause());
      case HotkeyAction.resume:
        unawaited(resume());
      case HotkeyAction.frameOverlay:
        unawaited(_toggleFrameOverlay());
      // Held rather than pressed: the native side answers them itself.
      case HotkeyAction.snapshot || HotkeyAction.frame:
        break;
    }
  }

  /// Shows the frame over the game or takes it off, which is what the key
  /// for it asks for. It is a setting rather than a session's state: the
  /// switch on the Screen page and the key are two ways to the same thing.
  Future<void> _toggleFrameOverlay() async {
    final settings = _settings.settings;
    await _settings.save(settings.copyWith(showFrameOverlay: !settings.showFrameOverlay));
  }

  /// The voice picked while a session runs reaches the worker rather than
  /// waiting for the next start: the player hears the next line in it.
  Future<void> _followVoice() async {
    final voice = _settings.settings.voice;
    if (!state.running || voice.isEmpty || voice == _voiceTold) return;
    _voiceTold = voice;
    try {
      await _appRepository.useVoice(voice);
    } catch (exception) {
      _errors.report(exception);
    }
  }

  /// The voice the running worker was last told to read in.
  String? _voiceTold;

  /// Puts what is drawn over the game in step with the settings: the frame
  /// where the reading will look, over the game that was chosen, and the
  /// key that shows and hides it registered while nothing else holds the
  /// keys.
  ///
  /// Called whenever any of those change: a setting written, which the
  /// repository's stream brings here, or a game chosen and a session
  /// started or ended, which are this cubit's own.
  void followFrameOverlay() {
    final settings = _settings.settings;
    final processId = settings.readsWholeScreen ? 0 : _process?.pid ?? 0;
    // Over a window there has to be a window: with no game named there is
    // nothing to draw the frame on.
    final drawable = settings.readsWholeScreen || processId != 0;
    try {
      if (settings.showFrameOverlay && drawable) {
        _appRepository.showFrameOverlay(processId: processId, region: settings.ocrRegion);
      } else {
        _appRepository.hideFrameOverlay();
      }
      // A running session registered the keys itself, its own among them.
      if (!state.running) _appRepository.setIdleHotkeys(settings);
    } catch (exception) {
      _errors.report(exception);
    }
  }

  /// Something went wrong with one phrase.
  ///
  /// A phrase failing does not stop the capture, so the pipeline keeps its
  /// state and the controls stay usable. Marking the session as failed here
  /// used to leave it stuck: neither startable nor stoppable. An event
  /// without a failure has nothing to show, and reporting null would clear a
  /// banner raised a moment earlier.
  void _onError(EngineFailed event) => _errors.report(event.failure);

  /// Every state this screen moves to is told to the coordinator, which
  /// is where the other screens learn whether the engine is theirs to use
  /// and the canvas what to draw locked.
  @override
  void onChange(Change<LivePipelineState> change) {
    super.onChange(change);
    final now = change.nextState;
    _sessions.reportPipeline(
      status: now.status,
      session: now.session,
      backends: now.activeBackends,
    );
  }

  /// Stages a state a widget test wants to render without starting anything.
  @visibleForTesting
  void seed(LivePipelineState value) => emit(value);

  @override
  Future<void> close() {
    unawaited(_written?.cancel());
    unawaited(_picked?.cancel());
    // The repository is shared with every other cubit: whoever made it
    // disposes of it, once they are all closed.
    _events?.cancel();
    return super.close();
  }
}

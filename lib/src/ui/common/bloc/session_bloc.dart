// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../../domain/screen_reading.dart';

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as path;

import '../../../data/repositories/install_repository.dart';
import '../../../data/repositories/sources_repository.dart';
import '../../../data/repositories/session_repository.dart';
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
import '../../shell/bloc/failure_cubit.dart';
import '../../../data/repositories/voice_bank_repository.dart';
import '../../../domain/session_config.dart';

part 'session_event.dart';
part 'session_state.dart';

/// The dubbing screens' session, as a sequence of what was asked of it and
/// what the engine answered.
///
/// It was `PipelineCubit`, whose `_handleEvent` was a table of events
/// written by hand; the player's requests and the engine's answers are now
/// events of one kind, and the state journal sees both. What the session
/// said -- the transcript, the voices of the scene, the snippets -- is
/// `TranscriptBloc`'s, and the game is `SourcesBloc`'s.
class SessionBloc extends Bloc<SessionEvent, SessionState> {
  SessionBloc(
    this._session,
    this._modelRepository,
    this._settings,
    this._downloads,
    this._sources,
    this._errors,
    this._sessions,
    this._voiceBank, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const SessionState()) {
    on<SessionToggle>(
      (event, emit) => switch (event) {
        LiveToggled() => _onLiveToggled(event, emit),
        ScreenToggled() => _onScreenToggled(event, emit),
        SceneToggled() => _onSceneToggled(event, emit),
      },
      transformer: _ignoringDoubleClicks,
    );
    on<SessionStopped>((event, emit) => _stop(emit));
    on<SessionPaused>(_onPaused);
    on<SessionResumed>(_onResumed);
    on<EngineFollowed>(
      (event, emit) => _events ??= _session.events.listen((said) => add(_EngineSaid(said))),
    );
    // In the order the engine said it. The handler is synchronous today, so
    // this changes nothing yet; it is what keeps it true if it ever waits.
    on<_EngineSaid>(_onEngine, transformer: sequential());
    // What is drawn over the game is made of the settings, so it follows
    // them from here rather than being called by whoever wrote one.
    _written = _settings.changes.listen((_) {
      _followFrameOverlay();
      unawaited(_followVoice());
    });
    // The frame is drawn over the game, so naming another one -- here or
    // on any other screen -- moves it.
    _picked = _sources.changes
        .map((sources) => sources.selected)
        .distinct()
        .listen((_) => _followFrameOverlay());
  }

  /// How long after a start a second press is taken for the rest of a
  /// double-click. Windows counts clicks as double within 500 ms by default.
  static const doubleClickGrace = Duration(milliseconds: 800);

  final SessionRepository _session;
  final ModelRepository _modelRepository;
  final SettingsRepository _settings;
  final InstallRepository _downloads;
  final SourcesRepository _sources;
  final FailureSink _errors;
  final SessionCoordinator _sessions;

  /// The file each game's voices are kept in, which a session is handed.
  final VoiceBankRepository _voiceBank;
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
  ModelSelection get _selection =>
      ModelSelection(models: _downloads.parts.models, settings: _settings.settings);

  Future<void> _onLiveToggled(LiveToggled event, Emitter<SessionState> emit) async {
    final initializing = event.initializing;
    _errors.report(null);
    if (state.liveRunning) return _stop(emit);
    final selection = _selection;
    if (!state.canStart(selection, initializing: initializing, process: _process)) return;
    // The snapshot session holds the worker loaded without whisper, so live
    // dubbing takes it over by starting afresh.
    if (state.running) {
      await _stop(emit);
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
    await _startLive(selection, emit);
  }

  /// The presses of the start buttons, less the second press of a
  /// double-click, each answered as it comes.
  ///
  /// Not `droppable()`, which would drop every press while one is being
  /// answered: the button that starts a session also cancels a start, and
  /// a start is minutes long. Concurrent, as a cubit's methods were: a
  /// cancel has to be answered while the start it cancels is still waiting.
  Stream<SessionToggle> _ignoringDoubleClicks(
    Stream<SessionToggle> presses,
    EventMapper<SessionToggle> answer,
  ) => concurrent<SessionToggle>()(presses.where((_) => !_pressedTwice), answer);

  /// Whether the button was pressed again while the first press was still
  /// being answered. Starting takes minutes to show anything, and a second
  /// press would start a second session over the first.
  bool get _pressedTwice {
    if (state.status != PipelineStatus.starting) return false;
    final startedAt = _startRequestedAt;
    return startedAt != null && _clock().difference(startedAt) < doubleClickGrace;
  }

  /// Hands the engine everything one live session needs.
  Future<void> _startLive(ModelSelection selection, Emitter<SessionState> emit) async {
    try {
      final settings = _settings.settings;
      // Dubbing into English has no translator to carry a target token.
      final translation = selection.translates
          ? selection.forTargetLanguage(ModelKind.translation)!.model
          : null;
      final speech = selection.forTargetLanguage(ModelKind.speech)!.model;
      await _session.start(
        process: selection.requiresProcess ? _process : null,
        settings: settings,
        // Whisper is asked for English where Marian will read it, and for
        // what it heard where a language model will.
        translateSpeech: selection.whisperTranslates,
        worker: WorkerPlan.under(
          settings,
          runtimeDirectory: _downloads.parts.runtimeDirectory,
          models: await _modelPaths(selection),
          backends: _backends,
          speaker: selection.voice,
          sourceLanguage: settings.effectiveSourceLanguage,
          translationPrefix: translation?.translationPrefix ?? '',
          languageModel: translation?.languageModel ?? false,
          chatTemplate: translation?.chatTemplate ?? '',
          followSpeaker: selection.followsSpeaker,
          // The converter may be loaded only to hear who is speaking.
          revoice: selection.clonesVoice,
          // The dubbing language's voices alone: a package reading several
          // languages would otherwise lend a Russian line an English voice.
          maleVoices: speech.voicesOf(VoiceGender.male, language: settings.targetLanguage),
          femaleVoices: speech.voicesOf(VoiceGender.female, language: settings.targetLanguage),
          // Kept per game, so one game's cast does not answer for another's.
          voiceBank: selection.keepsVoiceBank
              ? await _voiceBank.fileFor(_process?.name ?? '')
              : null,
        ),
      );
    } catch (exception) {
      _onStartFailed(exception, emit);
    }
  }

  /// A start that did not come up.
  ///
  /// One that was stopped is no failure: the button that starts a session
  /// also cancels a start in progress, and the start then ends the way it
  /// was asked to, with nothing to report.
  void _onStartFailed(Object exception, Emitter<SessionState> emit) {
    if (isClosed) return;
    if (isPipelineStopped(exception)) return _onStartStopped(emit);
    emit(state.copyWith(status: PipelineStatus.error));
    _errors.report(exception);
  }

  /// Stopped from this screen, the status has moved on already — [stop]
  /// says `stopping` before it waits for anything. Still `starting`, the
  /// worker was taken by another screen, which stops nothing here and tells
  /// this one nothing, so the start would go on looking alive for good.
  void _onStartStopped(Emitter<SessionState> emit) {
    if (state.status != PipelineStatus.starting) return;
    emit(
      state.copyWith(status: PipelineStatus.idle, clearStartupProgress: true, startupStage: ''),
    );
  }

  /// Where each model this session runs on actually sits. Whisper and the
  /// speech model are named by file, the other two by directory.
  Future<ModelPaths> _modelPaths(ModelSelection selection) async {
    final recognition = selection.recognition!.model;
    // Dubbing into English names no translator: the session runs without one.
    final translation = selection.translates
        ? selection.forTargetLanguage(ModelKind.translation)!.model
        : null;
    final speech = selection.forTargetLanguage(ModelKind.speech)!.model;
    return ModelPaths(
      whisper: path.join(
        await _modelRepository.directoryFor(recognition),
        recognition.primaryFileName,
      ),
      translation: translation == null ? null : await _modelRepository.directoryFor(translation),
      speech: path.join(await _modelRepository.directoryFor(speech), speech.primaryFileName),
      converter: selection.needsVoiceConverter
          ? await _modelRepository.directoryFor(selection.voiceConverter!.model)
          : null,
    );
  }

  /// Where each stage runs, given what this machine turned out to have.
  StageBackends get _backends =>
      StageBackends.resolved(_settings.settings, _downloads.parts.availability);

  /// Starts or ends a session of the Screen page, reading what [reading]
  /// says: the frame, the key, or both.
  ///
  /// The button of the reading that is running ends it; the button of
  /// another ends it and starts its own, since one engine serves the three
  /// and only what it captures differs.
  Future<void> _onScreenToggled(ScreenToggled event, Emitter<SessionState> emit) async {
    final (initializing, reading) = (event.initializing, event.reading);
    _errors.report(null);
    if (state.running) {
      // Live dubbing is ended from its own screen.
      if (state.session != PipelineSession.screen) return;
      final wasReading = state.screenReading;
      await _stop(emit);
      if (wasReading == reading || isClosed) return;
    }
    final selection = _selection;
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
      // Text in the language it is voiced in -- English into English, or the
      // dubbing language itself -- has nothing to translate: the same
      // session without Marian in it.
      final translation = selection.screenTranslates
          ? selection.forTargetLanguage(ModelKind.translation)!.model
          : null;
      final speech = selection.forTargetLanguage(ModelKind.speech)!.model;
      final speechDirectory = await _modelRepository.directoryFor(speech);
      // The voices behind the subtitles are followed only where the frame
      // is read at all, and only with the converter to hear them by.
      final converter = selection.voiceConverter;
      final hearsVoices =
          reading.readsSubtitles && settings.screenVoices && (converter?.installed ?? false);
      await _session.startScreenText(
        reading: reading,
        hearsVoices: hearsVoices,
        process: _process,
        settings: settings,
        worker: WorkerPlan.under(
          settings,
          runtimeDirectory: _downloads.parts.runtimeDirectory,
          models: ModelPaths(
            translation: translation == null
                ? null
                : await _modelRepository.directoryFor(translation),
            speech: path.join(speechDirectory, speech.primaryFileName),
            converter: hearsVoices ? await _modelRepository.directoryFor(converter!.model) : null,
          ),
          backends: _backends,
          // What a line is read in where nothing was heard saying it: a
          // selected line has no sound of its own to follow a speaker by.
          speaker: selection.voice,
          translationPrefix: translation?.translationPrefix ?? '',
          languageModel: translation?.languageModel ?? false,
          chatTemplate: translation?.chatTemplate ?? '',
          // The voices are carried over the reading where they are heard.
          revoice: hearsVoices,
          // The same bank the dubbing session keeps, so a character met
          // while the subtitles are read is met again when it runs.
          voiceBank: hearsVoices ? await _voiceBank.fileFor(_game) : null,
        ),
      );
    } catch (exception) {
      _onStartFailed(exception, emit);
    }
  }

  /// Starts or ends the session that places the voices of the scene: the
  /// game's audio through the converter, with nothing translated or voiced.
  ///
  /// It is what the replacements are made against before dubbing runs — the
  /// voices it meets join the game's bank under the numbers the dubbing
  /// session will know them by — and it is ready in seconds, since neither
  /// whisper nor the translator is loaded.
  Future<void> _onSceneToggled(SceneToggled event, Emitter<SessionState> emit) async {
    final initializing = event.initializing;
    _errors.report(null);
    if (state.running) {
      // Live dubbing and the snapshot session are ended where they started.
      if (state.session == PipelineSession.scene) await _stop(emit);
      return;
    }
    final selection = _selection;
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
      await _session.startSceneVoices(
        process: selection.requiresProcess ? _process : null,
        settings: settings,
        worker: WorkerPlan.under(
          settings,
          runtimeDirectory: _downloads.parts.runtimeDirectory,
          models: ModelPaths(
            converter: await _modelRepository.directoryFor(selection.voiceConverter!.model),
          ),
          backends: _backends,
          // The same bank the dubbing session reads, so a voice met now is
          // the same voice then.
          voiceBank: await _voiceBank.fileFor(_game),
        ),
      );
    } catch (exception) {
      _onStartFailed(exception, emit);
    }
  }

  /// Ends the session, paused or not, and gives the game its volume back.
  Future<void> _stop(Emitter<SessionState> emit) async {
    if (!state.running) return;
    _errors.report(null);
    emit(state.copyWith(status: PipelineStatus.stopping));
    var status = PipelineStatus.idle;
    try {
      await _session.stop();
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
    _followFrameOverlay();
  }

  /// Rests a listening session without tearing it down: the models stay
  /// loaded, so resuming is instant rather than another minute of startup.
  Future<void> _onPaused(SessionPaused event, Emitter<SessionState> emit) async {
    if (state.status != PipelineStatus.listening || !state.liveRunning) return;
    try {
      await _session.pause();
      if (!isClosed) emit(state.copyWith(status: PipelineStatus.paused));
    } catch (exception) {
      _errors.report(exception);
    }
  }

  Future<void> _onResumed(SessionResumed event, Emitter<SessionState> emit) async {
    if (state.status != PipelineStatus.paused) return;
    try {
      await _session.resume();
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
  void _onEngine(_EngineSaid said, Emitter<SessionState> emit) {
    final event = said.event;
    switch (event) {
      case SessionStateChanged():
        _onSessionState(event, emit);
      // The lists are `TranscriptBloc`'s, which hears the engine itself.
      case LineDubbed() || SceneVoiceHeard() || SnapshotReading() || SnapshotRead():
        break;
      case SubtitleFrameMoved():
        _onSubtitleFrame(event, emit);
      case StartupProgressed():
        _onStartup(event, emit);
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
  void _onSubtitleFrame(SubtitleFrameMoved event, Emitter<SessionState> emit) {
    if (event.region case final region?) {
      emit(state.copyWith(frameMissed: false));
      unawaited(_settings.save(_settings.settings.copyWith(ocrRegion: region)));
      return;
    }
    emit(state.copyWith(frameMissed: true));
  }

  /// The engine has started, come up or come to rest.
  void _onSessionState(SessionStateChanged event, Emitter<SessionState> emit) {
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
  void _onStartup(StartupProgressed event, Emitter<SessionState> emit) {
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
        add(const SessionPaused());
      case HotkeyAction.resume:
        add(const SessionResumed());
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
      await _session.useVoice(voice);
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
  void _followFrameOverlay() {
    final settings = _settings.settings;
    final processId = settings.readsWholeScreen ? 0 : _process?.pid ?? 0;
    // Over a window there has to be a window: with no game named there is
    // nothing to draw the frame on.
    final drawable = settings.readsWholeScreen || processId != 0;
    try {
      if (settings.showFrameOverlay && drawable) {
        _session.showFrameOverlay(processId: processId, region: settings.ocrRegion);
      } else {
        _session.hideFrameOverlay();
      }
      // A running session registered the keys itself, its own among them.
      if (!state.running) _session.setIdleHotkeys(settings);
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
  void onChange(Change<SessionState> change) {
    super.onChange(change);
    final now = change.nextState;
    _sessions.reportPipeline(
      status: now.status,
      session: now.session,
      backends: now.activeBackends,
    );
  }

  @override
  Future<void> close() {
    unawaited(_written?.cancel());
    unawaited(_picked?.cancel());
    // The repository is shared with every other cubit: whoever made it
    // disposes of it, once they are all closed.
    unawaited(_events?.cancel());
    return super.close();
  }
}

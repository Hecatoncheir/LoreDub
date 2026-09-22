// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as path;

import '../../../data/repositories/cast_repository.dart';
import '../../../data/repositories/install_repository.dart';
import '../../../data/repositories/model_repository.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../domain/built_voice.dart';
import '../../../domain/character.dart';
import '../../../domain/engine_event.dart';
import '../../../domain/failure.dart';
import '../../../domain/game_process.dart';
import '../../../domain/model_package.dart';
import '../../../domain/model_selection.dart';
import '../../../domain/pipeline_state.dart';
import '../../../domain/session_coordinator.dart';
import '../../../domain/voice_sample.dart';
import 'failure_cubit.dart';
import '../../../domain/session_config.dart';

/// What a card's record button does when pressed.
enum RecordAction { start, stop }

/// What the characters screen can be doing to a card.
///
/// Several of them go on side by side -- a clip plays while another card
/// records, files are measured while a sample is spoken -- which is why they
/// are not one state of the screen; but each holds one card at a time.
enum CardActivity { recording, playing, previewing, building }

/// What the characters screen is doing with the engine: the session a voice
/// is recorded through, the take, a card measured from files, and what is
/// sounding.
class VoiceCaptureState extends Equatable {
  const VoiceCaptureState({
    this.status = PipelineStatus.idle,
    this.busy = const {},
    this.heardSeconds = 0,
    this.clips = const {},
    this.previewReady = false,
    this.built,
  });

  /// The recording session: idle until the screen starts it, listening once
  /// the converter is loaded and the game's audio is being captured.
  final PipelineStatus status;

  /// The card each activity is under way on: the one whose voice is being
  /// recorded, whose clip is sounding, whose sample is being spoken -- from
  /// the moment it is asked for, which on the first one means waiting for
  /// the speech model -- and whose voice is being measured from files
  /// dropped on it.
  final Map<CardActivity, String> busy;

  /// How much speech the recording has heard, so the card can say whether
  /// there is enough of it yet.
  final double heardSeconds;

  /// The cards that kept the clip their voice was taken from, so it can be
  /// played back. A card imported from someone else's file has the
  /// fingerprint without the audio and is not in here.
  final Set<String> clips;

  /// What came of the last measurement from files, and the card it was
  /// for. The screen's own: the card keeps only the fingerprint.
  final ({String id, BuiltVoice voice})? built;

  /// Whether the speech model is loaded and a sample costs no waiting.
  final bool previewReady;

  /// The card [activity] is under way on, if it is.
  String? cardDoing(CardActivity activity) => busy[activity];

  /// Whether [activity] is under way on [id].
  bool isDoing(CardActivity activity, String id) => busy[activity] == id;

  /// [activity] begun on [id].
  VoiceCaptureState doing(CardActivity activity, String id) =>
      copyWith(busy: {...busy, activity: id});

  /// [activity] over, whichever card it was on.
  VoiceCaptureState done(CardActivity activity) => copyWith(busy: {...busy}..remove(activity));

  bool get running => status == PipelineStatus.starting || status == PipelineStatus.listening;

  bool get recording => busy.containsKey(CardActivity.recording);

  /// Whether a card is being measured from files right now.
  bool get building => busy.containsKey(CardActivity.building);

  /// Whether [id] has a clip of its own to play.
  bool canPlay(String id) => clips.contains(id);

  /// Nothing is played over anything else: one clip or one sample at a time.
  bool get sounding =>
      busy.containsKey(CardActivity.playing) || busy.containsKey(CardActivity.previewing);

  /// Whether [id]'s own clip can be played now: it has one, and nothing
  /// else is sounding.
  bool canPlayClip(String id) => canPlay(id) && !sounding;

  /// Whether a card can be read aloud in the voice the dubbing would give
  /// it. A sample brings up a worker of its own, so it waits for a dubbing
  /// session ([dubbing]) as well as for this screen's own sessions, and it
  /// needs the voice package ([speechInstalled]).
  bool canPreview({required bool dubbing, required bool speechInstalled}) =>
      speechInstalled && !dubbing && !sounding && !running && !building;

  /// What the record button on [id] does now, or null when it does nothing:
  /// only a running session records, and only one card at a time.
  RecordAction? recordActionFor(String id) {
    if (!running) return null;
    if (isDoing(CardActivity.recording, id)) return RecordAction.stop;
    return recording ? null : RecordAction.start;
  }

  /// Whether files dropped on a card are measured into its voice. Like a
  /// sample, it brings up a worker of its own; it needs the converter
  /// ([converterInstalled]) to measure with.
  bool takesFiles({required bool dubbing, required bool converterInstalled}) =>
      converterInstalled && !dubbing && !building && !recording;

  VoiceCaptureState copyWith({
    PipelineStatus? status,
    Map<CardActivity, String>? busy,
    double? heardSeconds,
    Set<String>? clips,
    ({String id, BuiltVoice voice})? built,
    bool clearBuilt = false,
    bool? previewReady,
  }) => VoiceCaptureState(
    status: status ?? this.status,
    busy: busy ?? this.busy,
    heardSeconds: heardSeconds ?? this.heardSeconds,
    clips: clips ?? this.clips,
    built: clearBuilt ? null : built ?? this.built,
    previewReady: previewReady ?? this.previewReady,
  );

  @override
  List<Object?> get props => [status, busy, heardSeconds, clips, built, previewReady];
}

sealed class VoiceCaptureEvent extends Equatable {
  const VoiceCaptureEvent();

  @override
  List<Object?> get props => const [];
}

/// The screen is up: which cards have a clip beside them is read.
final class VoiceCaptureOpened extends VoiceCaptureEvent {
  const VoiceCaptureOpened();
}

/// Starts or ends the session the recordings listen through. [process] is
/// the game to listen to, chosen on the screen.
final class RecordingSessionToggled extends VoiceCaptureEvent {
  const RecordingSessionToggled({required this.initializing, required this.process});

  final bool initializing;
  final GameProcess? process;

  @override
  List<Object?> get props => [initializing, process?.pid];
}

/// Ends the session this screen holds, recording or sample.
final class RecordingSessionEnded extends VoiceCaptureEvent {
  const RecordingSessionEnded();
}

/// Begins measuring what the game says for [id].
final class RecordingStarted extends VoiceCaptureEvent {
  const RecordingStarted(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Closes the take and keeps what it heard as the character's voice.
final class RecordingStopped extends VoiceCaptureEvent {
  const RecordingStopped();
}

/// Measures the voice of [id] from the recordings the player dropped on it.
final class VoiceFilesDropped extends VoiceCaptureEvent {
  const VoiceFilesDropped(this.id, this.paths);

  final String id;
  final List<String> paths;

  @override
  List<Object?> get props => [id, paths];
}

/// Speaks a line in the voice the dubbing would read [id] in.
final class SampleAsked extends VoiceCaptureEvent {
  const SampleAsked(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Plays back what [id] was recorded from.
final class ClipPlayed extends VoiceCaptureEvent {
  const ClipPlayed(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Ends whatever is sounding -- a clip or a sample.
final class SoundStopped extends VoiceCaptureEvent {
  const SoundStopped();
}

final class _EngineSaid extends VoiceCaptureEvent {
  const _EngineSaid(this.event);

  final EngineEvent event;
}

final class _CastChanged extends VoiceCaptureEvent {
  const _CastChanged(this.library);

  final CharacterLibrary library;
}

final class _TakeTicked extends VoiceCaptureEvent {
  const _TakeTicked();
}

/// The characters screen's side of the engine: the session a card's voice
/// is recorded through, a card measured from files, and a sample spoken in
/// the voice the dubbing would give a card.
///
/// It was half of `CharactersCubit`, beside the cards themselves; what a
/// take is measured into is written to the card through `CastRepository`,
/// which is where the cards are read from as well.
class VoiceCaptureBloc extends Bloc<VoiceCaptureEvent, VoiceCaptureState> {
  VoiceCaptureBloc(
    this._session,
    this._modelRepository,
    this._settings,
    this._downloads,
    this._errors,
    this._sessions,
    this._cast, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const VoiceCaptureState()) {
    on<VoiceCaptureOpened>(_onOpened);
    on<RecordingSessionToggled>(_onToggled);
    on<RecordingSessionEnded>((event, emit) => _stopSession(emit));
    on<RecordingStarted>(_onRecordingStarted);
    on<RecordingStopped>((event, emit) => _stopRecording(emit));
    on<VoiceFilesDropped>(_onFilesDropped);
    on<SampleAsked>(_onSampleAsked);
    on<ClipPlayed>(_onClipPlayed);
    on<SoundStopped>((event, emit) {
      if (state.sounding) _session.stopWave();
    });
    on<_EngineSaid>(_onEngine);
    on<_CastChanged>(_onCastChanged);
    on<_TakeTicked>(_onTicked);
    _sessions
      ..cast = _endForDubbing
      ..castHolds = () => state.running || state.previewReady;
    // One engine serves every screen in turn and the same stream reaches
    // them all; this screen picks its own out of it.
    _engine = _session.events.listen((event) => add(_EngineSaid(event)));
    _written = _cast.changes.listen((library) => add(_CastChanged(library)));
  }

  /// A recording keeps the clearest voice it has heard, not the last: a
  /// character founded on a half-word would answer for them ever after.
  static const enoughSeconds = 1.5;

  final SessionRepository _session;
  final ModelRepository _modelRepository;
  final SettingsRepository _settings;
  final InstallRepository _downloads;
  final FailureSink _errors;
  final SessionCoordinator _sessions;
  final CastRepository _cast;
  final DateTime Function() _clock;
  late final StreamSubscription<EngineEvent> _engine;
  late final StreamSubscription<CharacterLibrary> _written;

  /// Whether one of the dubbing screens holds the worker.
  ///
  /// One engine serves one session, and everything this screen starts — the
  /// recording session, a sample, a card measured from files — brings up a
  /// worker of its own. Begun over a session that was dubbing, it took that
  /// session's worker while the capture went on, and every phrase the game
  /// said from then on failed for want of whisper. Live takes the worker
  /// from this screen by asking ([SessionCoordinator.makeRoomForDubbing]);
  /// this screen never takes it back.
  bool get _workerTaken => _sessions.dubbingRuns;

  /// The best fingerprint this recording has heard so far.
  List<double>? _heard;
  String? _heardGender;

  /// The file the clearest line was heard in, which is kept beside the card
  /// so the player can hear back what they recorded.
  String? _heardClip;

  /// How much the take was measured to hold, as the converter read it.
  double _heardSeconds = 0;

  /// The clock the card counts a take by, and the ticks that show it.
  DateTime? _recordingSince;
  Timer? _recordingTicks;

  ModelSelection get _selection =>
      ModelSelection(models: _downloads.parts.models, settings: _settings.settings);

  /// Whether a voice can be recorded at all: the converter is what measures
  /// one, and it is downloaded on the models screen.
  bool get canRecord => _selection.voiceConverter?.installed ?? false;

  /// Whether a sample can be spoken: the speech model of the dubbing
  /// language is what says it.
  bool get canPreview => _selection.forTargetLanguage(ModelKind.speech)?.installed ?? false;

  /// Whether a sample will be spoken in the character's own timbre. Without
  /// «Original voice» the dubbing reads every card in a plain synthesized
  /// voice, and a card that says so spares the player wondering where the
  /// voice they recorded went.
  bool get carriesTimbre => _selection.clonesVoice;

  /// What a dubbing screen asks for to take the worker over: this screen's
  /// session ended, and the call answering once it has.
  Future<void> _endForDubbing() async {
    if (isClosed || (!state.running && !state.previewReady)) return;
    add(const RecordingSessionEnded());
    await stream
        .firstWhere((now) => !now.running && !now.previewReady)
        .then<void>((_) {}, onError: (Object _) {});
  }

  /// The cards with a clip beside them. A directory that cannot be read
  /// costs a play button, not the cast: the cards themselves are elsewhere.
  Future<void> _onOpened(VoiceCaptureOpened event, Emitter<VoiceCaptureState> emit) async {
    try {
      emit(state.copyWith(clips: await _cast.clips()));
    } on Object {
      // No clips to play is the screen as it is for an imported cast.
    }
  }

  Future<void> _onToggled(RecordingSessionToggled event, Emitter<VoiceCaptureState> emit) async {
    if (state.running) return _stopSession(emit);
    if (event.initializing || _workerTaken || !canRecord) return;
    _errors.report(null);
    emit(state.copyWith(status: PipelineStatus.starting));
    try {
      final settings = _settings.settings;
      await _session.startCharacterVoices(
        process: event.process,
        settings: settings,
        worker: await _converterOnly(),
      );
    } catch (exception) {
      // The button that starts the session also stops one still starting,
      // and Live takes the worker over: either ends the start the way it
      // was asked to, and says itself what the screen shows.
      if (isClosed || isPipelineStopped(exception)) return;
      emit(state.copyWith(status: PipelineStatus.error));
      _errors.report(exception);
    }
  }

  Future<void> _stopSession(Emitter<VoiceCaptureState> emit) async {
    _endTicks();
    // Live asks for this too, to take the worker over. Without a session of
    // this screen's there is nothing to end, and stopping the engine would
    // take down the one that is about to start.
    if (!state.running && !state.previewReady) return;
    if (state.recording) await _stopRecording(emit);
    try {
      await _session.stop();
    } catch (exception) {
      _errors.report(exception);
    }
    emit(state.copyWith(status: PipelineStatus.idle, previewReady: false));
  }

  /// The take runs until it is stopped: nothing in the game — a pause, a
  /// line that runs long — ends it, so what the card is measured from is
  /// everything heard in between. Three minutes is the ceiling, since a
  /// recording nobody stopped is a mistake rather than a wish.
  void _onRecordingStarted(RecordingStarted event, Emitter<VoiceCaptureState> emit) {
    if (!state.running || state.recording) return;
    _heard = null;
    _heardGender = null;
    _heardClip = null;
    _heardSeconds = 0;
    unawaited(_session.recordCharacterVoice(recording: true));
    // Nothing is measured until the take is stopped, so the card counts the
    // seconds itself rather than leaving the player without an answer.
    _recordingSince = _clock();
    _recordingTicks?.cancel();
    _recordingTicks = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => add(const _TakeTicked()),
    );
    emit(state.doing(CardActivity.recording, event.id).copyWith(heardSeconds: 0));
  }

  void _onTicked(_TakeTicked event, Emitter<VoiceCaptureState> emit) {
    final since = _recordingSince;
    if (since == null) return;
    emit(state.copyWith(heardSeconds: _clock().difference(since).inMilliseconds / 1000));
  }

  void _endTicks() {
    _recordingTicks?.cancel();
    _recordingTicks = null;
    _recordingSince = null;
  }

  Future<void> _stopRecording(Emitter<VoiceCaptureState> emit) async {
    final id = state.cardDoing(CardActivity.recording);
    if (id == null) return;
    _endTicks();
    // The take is one recording, and it is this call that closes it: what
    // the converter makes of it lands while this waits.
    await _session.recordCharacterVoice(recording: false);
    final heard = _heard;
    final clip = _heardClip;
    var kept = state.clips;
    if (heard != null && clip != null) {
      try {
        await _cast.keepClip(id, clip);
        kept = {...kept, id};
      } catch (exception) {
        // A card without its clip is still a card: only the play button goes.
        kept = {...kept}..remove(id);
        _errors.report(exception);
      }
    }
    emit(state.done(CardActivity.recording).copyWith(clips: kept, heardSeconds: 0));
    if (heard == null) return;
    await _writeVoice(
      id,
      vector: heard,
      gender: _heardGender,
      seconds: _heardSeconds,
    );
  }

  void _onEngine(_EngineSaid said, Emitter<VoiceCaptureState> emit) {
    switch (said.event) {
      case final SessionStateChanged event:
        // The dubbing screens hold the worker in their turn, and a session
        // of theirs is not this screen's to show. An event naming no
        // session is the engine coming to rest, which ends this one too.
        if (!event.concerns(PipelineSession.characters)) return;
        emit(
          state.copyWith(
            status: event.status,
            // Whichever of the two this is, the worker a sample was loaded
            // into is gone: at rest the engine holds none, and the one that
            // records has no speech model in it. Left standing, the next
            // sample skipped the loading and was told there was no worker.
            previewReady: false,
          ),
        );
      case final CharacterVoiceMeasured event:
        _onCharacterVoice(event);
      // The dubbing screens read the rest; this one is only in the stream
      // because the same engine serves them all in turn.
      default:
        break;
    }
  }

  /// What was measured from the take a card is recording.
  void _onCharacterVoice(CharacterVoiceMeasured event) {
    if (!state.recording) return;
    final seconds = event.seconds;
    // The take is one recording, so this is it — unless it holds less speech
    // than a fingerprint can be taken from.
    if (seconds < enoughSeconds) return;
    _heard = event.vector;
    _heardGender = event.gender;
    _heardClip = event.clip;
    // How long the take turned out to hold, which is what the card keeps;
    // the seconds on screen meanwhile are the clock's.
    _heardSeconds = seconds;
  }

  /// A card thrown away takes its clip and its take with it: the take is
  /// closed rather than written to a card that is gone.
  Future<void> _onCastChanged(_CastChanged event, Emitter<VoiceCaptureState> emit) async {
    final ids = {for (final card in event.library.characters) card.id};
    final recordingGone =
        state.cardDoing(CardActivity.recording) != null &&
        !ids.contains(state.cardDoing(CardActivity.recording));
    if (recordingGone) await _stopRecording(emit);
    final clips = state.clips.where(ids.contains).toSet();
    if (clips.length != state.clips.length) emit(state.copyWith(clips: clips));
  }

  /// The files are averaged rather than picked between, which is what makes
  /// a card built this way steadier than one built from a single line, and
  /// what came of it — how many files were used, how well they agreed, which
  /// ones held no voice — is kept in [VoiceCaptureState.built] for the card
  /// to show. The clip the fingerprint stands closest to becomes the one the
  /// card plays back, so what the player hears is a recording they gave it.
  Future<void> _onFilesDropped(VoiceFilesDropped event, Emitter<VoiceCaptureState> emit) async {
    final (id, paths) = (event.id, event.paths);
    if (paths.isEmpty || state.building || state.recording || _workerTaken || !canRecord) return;
    if (!_cast.cast.any((character) => character.id == id)) return;
    _errors.report(null);
    emit(state.doing(CardActivity.building, id).copyWith(clearBuilt: true));
    // A session the player started is theirs to end; one borrowed here to
    // measure files with is put down again when the measuring is over.
    int? borrowed;
    try {
      if (!state.running) borrowed = await _startForFiles();
      final built = await _session.buildVoice(paths);
      final clips = await _keptClips(id, built.anchor);
      emit(state.copyWith(built: (id: id, voice: built), clips: clips));
      await _writeVoice(id, vector: built.vector, gender: built.gender, seconds: built.seconds);
    } catch (exception) {
      // Another screen taking the worker over is no failure of this one.
      if (!isPipelineStopped(exception)) _errors.report(exception);
    } finally {
      if (borrowed != null) await _stopBorrowed(borrowed);
      emit(
        state
            .done(CardActivity.building)
            .copyWith(
              // A start that never came up borrowed nothing, and whatever the
              // screen shows by now was put there by somebody else.
              status: borrowed == null ? state.status : PipelineStatus.idle,
            ),
      );
    }
  }

  /// Loads the converter and nothing else: there is no game to listen to,
  /// and the recordings are already on disk. Answers with the session it
  /// began, which is the one [_stopBorrowed] puts down.
  Future<int> _startForFiles() async => _session.startVoiceFiles(await _converterOnly());

  /// The worker that measures a voice and loads nothing else.
  Future<WorkerPlan> _converterOnly() async => WorkerPlan.under(
    _settings.settings,
    runtimeDirectory: _downloads.parts.runtimeDirectory,
    models: ModelPaths(
      converter: await _modelRepository.directoryFor(_selection.voiceConverter!.model),
    ),
    backends: StageBackends.resolved(_settings.settings, _downloads.parts.availability),
  );

  /// The clips with [anchor] kept as [id]'s. A card without its clip is still
  /// a card — only the play button goes — so a clip that cannot be kept is
  /// reported and passed over.
  Future<Set<String>> _keptClips(String id, String? anchor) async {
    if (anchor == null) return state.clips;
    try {
      await _cast.keepClip(id, anchor);
      return {...state.clips, id};
    } catch (exception) {
      _errors.report(exception);
      return {...state.clips}..remove(id);
    }
  }

  /// Puts down the session borrowed to measure files — that one, and no
  /// other. Live starting meanwhile takes the worker over without a word to
  /// this screen: what the engine holds by now is the dubbing, which a plain
  /// stop used to end.
  Future<void> _stopBorrowed(int session) async {
    try {
      await _session.stopSession(session);
    } catch (exception) {
      _errors.report(exception);
    }
  }

  /// The speech model is loaded for a sample, which the recording session
  /// does without — the first sample waits for that, the ones after it do
  /// not. Recording is the other way round, and so is measuring files, so
  /// neither runs together with a sample.
  Future<void> _onSampleAsked(SampleAsked event, Emitter<VoiceCaptureState> emit) async {
    if (state.sounding || state.running || state.building || _workerTaken || !canPreview) return;
    final cast = _cast.cast;
    final character = cast.where((value) => value.id == event.id).firstOrNull;
    if (character == null) return;
    emit(state.doing(CardActivity.previewing, event.id));
    try {
      final selection = _selection;
      // A card read in another's voice is heard as that other: the sample
      // answers what the dubbing will do, not what the card holds. One hop
      // only, as the worker reads it.
      final read = cast.where((value) => value.id == character.voicedBy).firstOrNull ?? character;
      if (!state.previewReady) {
        await _loadSpeechForPreview();
        emit(state.copyWith(previewReady: true));
      }
      await _session.previewVoice(
        // The line is in the language the voice speaks, which is the one
        // being dubbed into — not the one the interface is in.
        text: voiceSample(_settings.settings.targetLanguage, character.name),
        voice: read.voice ?? selection.voice,
        timbre: selection.clonesVoice ? read.vector : const [],
      );
    } catch (exception) {
      // Another screen taking the worker over is no failure of this one.
      if (!isPipelineStopped(exception)) _errors.report(exception);
    } finally {
      emit(state.done(CardActivity.previewing));
    }
  }

  Future<void> _loadSpeechForPreview() async {
    final selection = _selection;
    final speech = selection.forTargetLanguage(ModelKind.speech)!.model;
    await _session.startVoicePreview(
      WorkerPlan.under(
        _settings.settings,
        runtimeDirectory: _downloads.parts.runtimeDirectory,
        models: ModelPaths(
          speech: path.join(await _modelRepository.directoryFor(speech), speech.primaryFileName),
          converter: selection.needsVoiceConverter
              ? await _modelRepository.directoryFor(selection.voiceConverter!.model)
              : null,
        ),
        backends: StageBackends.resolved(_settings.settings, _downloads.parts.availability),
        speaker: selection.voice,
      ),
    );
  }

  /// Plays back what the card was recorded from, so the player can hear
  /// whether they caught the right character.
  Future<void> _onClipPlayed(ClipPlayed event, Emitter<VoiceCaptureState> emit) async {
    if (state.sounding) return;
    try {
      final clip = await _cast.clipFor(event.id);
      if (clip == null) {
        // The file went missing under us; the button goes with it.
        emit(state.copyWith(clips: {...state.clips}..remove(event.id)));
        return;
      }
      emit(state.doing(CardActivity.playing, event.id));
      await _session.playWave(clip);
    } catch (exception) {
      _errors.report(exception);
    } finally {
      emit(state.done(CardActivity.playing));
    }
  }

  /// Writes what was measured into [id]'s card, through the repository the
  /// cards are read from.
  Future<void> _writeVoice(
    String id, {
    required List<double> vector,
    required String? gender,
    required double seconds,
  }) async {
    try {
      await _cast.save(
        CharacterLibrary(
          characters: [
            for (final character in _cast.cast)
              if (character.id == id)
                character.copyWith(
                  vector: vector,
                  gender: gender,
                  clearGender: gender == null,
                  seconds: seconds,
                )
              else
                character,
          ],
          packs: _cast.library.packs,
        ),
      );
    } catch (exception) {
      _errors.report(exception);
    }
  }

  /// Whether this screen's session is up is told to the coordinator: the
  /// game it records through is shared, and the other screens close their
  /// pickers on it.
  @override
  void onChange(Change<VoiceCaptureState> change) {
    super.onChange(change);
    _sessions.reportCast(running: change.nextState.running);
  }

  @override
  Future<void> close() async {
    _endTicks();
    await _engine.cancel();
    await _written.cancel();
    return super.close();
  }
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/session_repository.dart';
import '../../../domain/engine_activity.dart';
import '../../../domain/engine_event.dart';
import '../../../domain/pipeline_state.dart';
import '../../../domain/session_coordinator.dart';
import '../../shell/bloc/failure_cubit.dart';

/// What the dubbing screens' sessions have said: the lines dubbed, the
/// voices of the scene, and the snippets the player picked out.
class TranscriptState extends Equatable {
  const TranscriptState({
    this.transcript = const [],
    this.speakers = const [],
    this.snapshots = const [],
    this.snapshotReading = false,
    this.snapshotMissed = false,
  });

  /// The lines of the running capture, newest first.
  final List<TranscriptEntry> transcript;

  /// The voices this session has heard, in the order they first spoke.
  final List<SceneSpeaker> speakers;

  /// What the player selected and had translated, newest first. Kept apart
  /// from [transcript], which follows the running capture.
  final List<TranscriptEntry> snapshots;

  /// Set from the moment a selection is let go until its translation, or
  /// the news that it held no text, arrives.
  final bool snapshotReading;

  /// Whether the last selection held no text Windows could read.
  final bool snapshotMissed;

  /// How many lines a list keeps, newest first. The screen's subtitles keep
  /// ten: that area grows with what it holds rather than scrolling inside
  /// itself, so a longer list would push the page down without being read.
  static const linesKept = 50;
  static const subtitlesKept = 10;

  TranscriptState copyWith({
    List<TranscriptEntry>? transcript,
    List<SceneSpeaker>? speakers,
    List<TranscriptEntry>? snapshots,
    bool? snapshotReading,
    bool? snapshotMissed,
  }) => TranscriptState(
    transcript: transcript ?? this.transcript,
    speakers: speakers ?? this.speakers,
    snapshots: snapshots ?? this.snapshots,
    snapshotReading: snapshotReading ?? this.snapshotReading,
    snapshotMissed: snapshotMissed ?? this.snapshotMissed,
  );

  @override
  List<Object?> get props => [transcript, speakers, snapshots, snapshotReading, snapshotMissed];
}

sealed class TranscriptEvent extends Equatable {
  const TranscriptEvent();

  @override
  List<Object?> get props => const [];
}

/// The player emptied the transcript. A running session keeps appending to
/// the now-clear list.
final class TranscriptCleared extends TranscriptEvent {
  const TranscriptCleared();
}

/// The player emptied the list of selections.
final class SnapshotsCleared extends TranscriptEvent {
  const SnapshotsCleared();
}

/// The player asked to hear a line again: one that went by while they were
/// looking at the game rather than at the list.
final class LineSpokenAgain extends TranscriptEvent {
  const LineSpokenAgain(this.entry);

  final TranscriptEntry entry;

  @override
  List<Object?> get props => [entry.english, entry.spoken];
}

final class _EngineSaid extends TranscriptEvent {
  const _EngineSaid(this.event);

  final EngineEvent event;
}

final class _SessionMoved extends TranscriptEvent {
  const _SessionMoved(this.was, this.now);

  final EngineActivity was;
  final EngineActivity now;
}

/// The lists the dubbing screens show, kept apart from the session that
/// fills them.
///
/// They were fields of `PipelineCubit` beside the status, so a line dubbed
/// was a new state of the session and every listener to the session had to
/// say it did not care. The lines come from the engine and nowhere else,
/// and the one thing they need to know of the session -- that one of its
/// kind began, which empties them, and how many lines that kind keeps -- is
/// published by `SessionCoordinator`.
class TranscriptBloc extends Bloc<TranscriptEvent, TranscriptState> {
  TranscriptBloc(this._app, this._sessions, this._errors) : super(const TranscriptState()) {
    // In the order the engine said it: a line and the selection it answers
    // must not land the other way round.
    on<_EngineSaid>((event, emit) => _onEngine(event.event, emit), transformer: sequential());
    on<_SessionMoved>(_onSessionMoved);
    on<TranscriptCleared>((event, emit) => emit(state.copyWith(transcript: const [])));
    on<SnapshotsCleared>((event, emit) => emit(state.copyWith(snapshots: const [])));
    on<LineSpokenAgain>(_onSpokenAgain);
    _engine = _app.events.listen((event) => add(_EngineSaid(event)));
    var was = _sessions.activity;
    _moves = _sessions.changes.listen((now) {
      add(_SessionMoved(was, now));
      was = now;
    });
  }

  final SessionRepository _app;
  final SessionCoordinator _sessions;
  final FailureSink _errors;
  late final StreamSubscription<EngineEvent> _engine;
  late final StreamSubscription<EngineActivity> _moves;

  void _onEngine(EngineEvent event, Emitter<TranscriptState> emit) {
    switch (event) {
      case LineDubbed():
        emit(_withLine(event));
      case SceneVoiceHeard():
        emit(state.copyWith(speakers: _withSpeaker(event.speaker, seconds: event.seconds)));
      case SnapshotReading():
        emit(state.copyWith(snapshotReading: true, snapshotMissed: false));
      case SnapshotRead():
        // Text that was found stays in reading until its translation lands.
        if (event.text.isNotEmpty) return;
        emit(state.copyWith(snapshotReading: false, snapshotMissed: !event.failed));
      // Whatever failed, a selection still waiting will not be answered.
      case EngineFailed():
        emit(state.copyWith(snapshotReading: false));
      // The session's, and nothing to the lists.
      case SessionStateChanged() ||
          StartupProgressed() ||
          LanguageDetected() ||
          VoiceSpoken() ||
          VoiceBankGrew() ||
          BackendSettled() ||
          HotkeyPressed() ||
          SubtitleFrameMoved() ||
          CharacterVoiceMeasured():
        break;
    }
  }

  /// One dubbed line, from the capture or from a selection.
  TranscriptState _withLine(LineDubbed event) {
    final entry = event.line;
    // A selection answers the player's request, not the running capture, so
    // it has a list of its own.
    if (event.snapshot) {
      return state.copyWith(
        snapshots: [entry, ...state.snapshots.take(TranscriptState.linesKept - 1)],
        snapshotReading: false,
      );
    }
    final kept = _sessions.activity.session == PipelineSession.screen
        ? TranscriptState.subtitlesKept
        : TranscriptState.linesKept;
    return state.copyWith(
      transcript: [entry, ...state.transcript.take(kept - 1)],
      speakers: _withSpeaker(
        entry.speaker,
        line: entry.translated.trim().isEmpty ? entry.original : entry.translated,
      ),
    );
  }

  /// A session beginning empties what belonged to the last one, and one
  /// ending leaves no selection waiting to be answered.
  void _onSessionMoved(_SessionMoved event, Emitter<TranscriptState> emit) {
    final (was, now) = (event.was, event.now);
    if (now.status == PipelineStatus.starting && was.status != PipelineStatus.starting) {
      emit(switch (now.session) {
        // The list under the frame is this session's, not the last one's.
        PipelineSession.screen => state.copyWith(
          transcript: const [],
          snapshotReading: false,
          snapshotMissed: false,
        ),
        // Whoever spoke in the last session is not in this one yet. Who
        // reads whom is not kept here at all: it is the graph's, and it is
        // in the cards.
        PipelineSession.live || PipelineSession.scene => state.copyWith(speakers: const []),
        PipelineSession.characters || PipelineSession.preview => state,
      });
    }
    if (was.pipelineRuns && !now.pipelineRuns) emit(state.copyWith(snapshotReading: false));
  }

  Future<void> _onSpokenAgain(LineSpokenAgain event, Emitter<TranscriptState> emit) async {
    final spoken = event.entry.spoken;
    if (spoken == null) return;
    try {
      await _app.speakAgain(spoken);
    } catch (exception) {
      _errors.report(exception);
    }
  }

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

  @override
  Future<void> close() async {
    await _engine.cancel();
    await _moves.cancel();
    return super.close();
  }
}

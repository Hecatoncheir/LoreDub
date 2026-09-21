// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/repositories/session_repository.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:lore_dub/src/domain/engine_event.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart';
import 'package:lore_dub/src/domain/session_coordinator.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/failure_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/transcript_bloc.dart';

void main() {
  late _Engine engine;
  late SessionCoordinator sessions;
  late TranscriptBloc lists;

  const line = TranscriptEntry(
    original: 'Halt!',
    english: 'Halt!',
    translated: 'Стоять!',
    latency: Duration(milliseconds: 900),
    speaker: 'timbre:0',
  );

  void session(PipelineStatus status, PipelineSession kind) =>
      sessions.reportPipeline(status: status, session: kind, backends: const {});

  setUp(() {
    engine = _Engine();
    sessions = SessionCoordinator();
    lists = TranscriptBloc(engine, sessions, _Sink());
  });

  tearDown(() async {
    await lists.close();
    await sessions.dispose();
    await engine.said.close();
  });

  test('a subtitle session starting empties the lines under the frame', () async {
    engine.said.add(const LineDubbed(line: line));
    await pumpEventQueue();
    expect(lists.state.transcript, hasLength(1));

    session(PipelineStatus.starting, PipelineSession.screen);
    await pumpEventQueue();

    expect(lists.state.transcript, isEmpty, reason: 'the list is that session\'s');
  });

  test('a dubbing session starting forgets who spoke, not what was said', () async {
    engine.said.add(const LineDubbed(line: line));
    await pumpEventQueue();
    expect(lists.state.speakers.single.key, 'timbre:0');

    session(PipelineStatus.starting, PipelineSession.live);
    await pumpEventQueue();

    expect(lists.state.speakers, isEmpty);
    expect(lists.state.transcript, hasLength(1));
  });

  test('keeps ten lines under the frame and fifty on Live', () async {
    session(PipelineStatus.listening, PipelineSession.screen);
    for (var index = 0; index < 12; index++) {
      engine.said.add(const LineDubbed(line: line));
    }
    await pumpEventQueue();
    expect(lists.state.transcript, hasLength(TranscriptState.subtitlesKept));

    session(PipelineStatus.listening, PipelineSession.live);
    for (var index = 0; index < 60; index++) {
      engine.said.add(const LineDubbed(line: line));
    }
    await pumpEventQueue();
    expect(lists.state.transcript, hasLength(TranscriptState.linesKept));
  });

  test('a session ending leaves no selection waiting', () async {
    session(PipelineStatus.listening, PipelineSession.screen);
    engine.said.add(const SnapshotReading());
    await pumpEventQueue();
    expect(lists.state.snapshotReading, isTrue);

    session(PipelineStatus.idle, PipelineSession.screen);
    await pumpEventQueue();

    expect(lists.state.snapshotReading, isFalse);
  });
}

class _Engine extends SessionRepository {
  _Engine() : super(NativeEngineService());

  final said = StreamController<EngineEvent>.broadcast();

  @override
  Stream<EngineEvent> get events => said.stream;
}

class _Sink implements FailureSink {
  @override
  void report(Object? failure) {}
}

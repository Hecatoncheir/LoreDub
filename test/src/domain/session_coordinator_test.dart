// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:lore_dub/src/domain/engine_activity.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart';
import 'package:lore_dub/src/domain/session_coordinator.dart';

void main() {
  late SessionCoordinator sessions;

  setUp(() => sessions = SessionCoordinator());
  tearDown(() => sessions.dispose());

  test('each screen reports its own half, and neither undoes the other', () {
    sessions
      ..reportPipeline(
        status: PipelineStatus.listening,
        session: PipelineSession.live,
        backends: const {},
      )
      ..reportCast(running: true);

    expect(sessions.activity.pipelineRuns, isTrue);
    expect(sessions.activity.recordingVoice, isTrue);
    expect(sessions.dubbingRuns, isTrue, reason: 'the cast screen refuses on this');
    expect(sessions.anyRuns, isTrue);
  });

  test('tells a change before the report returns, and only a change', () {
    // The dubbing screen reports on every state it moves to -- a line of
    // the transcript included -- and the canvas must not be redrawn for
    // what did not change.
    final heard = <EngineActivity>[];
    final listening = sessions.changes.listen(heard.add);
    addTearDown(listening.cancel);

    const backends = {ComputeStage.speech: ComputeBackend.cpu};
    sessions
      ..reportPipeline(
        status: PipelineStatus.listening,
        session: PipelineSession.live,
        backends: backends,
      )
      ..reportPipeline(
        status: PipelineStatus.listening,
        session: PipelineSession.live,
        backends: {...backends},
      )
      ..reportPipeline(
        status: PipelineStatus.paused,
        session: PipelineSession.live,
        backends: backends,
      );

    expect(heard.map((activity) => activity.paused), [false, true]);
  });
}

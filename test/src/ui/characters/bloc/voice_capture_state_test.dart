// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart';
import 'package:lore_dub/src/ui/characters/bloc/voice_capture_bloc.dart';

void main() {
  const idle = VoiceCaptureState(clips: {'ann'});
  const recording = VoiceCaptureState(
    status: PipelineStatus.listening,
    busy: {CardActivity.recording: 'ann'},
  );

  test('plays a clip a card has, and only while nothing else sounds', () {
    expect(idle.canPlayClip('ann'), isTrue);
    expect(idle.canPlayClip('bob'), isFalse, reason: 'no clip of its own');
    expect(idle.doing(CardActivity.playing, 'bob').canPlayClip('ann'), isFalse);
  });

  test('reads a sample only with the voice installed and the worker free', () {
    expect(idle.canPreview(dubbing: false, speechInstalled: true), isTrue);
    expect(idle.canPreview(dubbing: false, speechInstalled: false), isFalse);
    expect(idle.canPreview(dubbing: true, speechInstalled: true), isFalse);
    expect(recording.canPreview(dubbing: false, speechInstalled: true), isFalse);
    expect(
      idle.doing(CardActivity.building, 'bob').canPreview(dubbing: false, speechInstalled: true),
      isFalse,
    );
  });

  test('records on a running session, one card at a time', () {
    expect(idle.recordActionFor('ann'), isNull, reason: 'no session to record through');
    expect(recording.recordActionFor('ann'), RecordAction.stop);
    expect(recording.recordActionFor('bob'), isNull, reason: 'another card is recording');
    const listening = VoiceCaptureState(status: PipelineStatus.listening);
    expect(listening.recordActionFor('bob'), RecordAction.start);
  });

  test('takes files with the converter installed and nothing else measuring', () {
    expect(idle.takesFiles(dubbing: false, converterInstalled: true), isTrue);
    expect(idle.takesFiles(dubbing: false, converterInstalled: false), isFalse);
    expect(idle.takesFiles(dubbing: true, converterInstalled: true), isFalse);
    expect(recording.takesFiles(dubbing: false, converterInstalled: true), isFalse);
  });

  test('does things to different cards side by side, one card each', () {
    final both = recording.doing(CardActivity.playing, 'bob');

    expect(both.isDoing(CardActivity.recording, 'ann'), isTrue, reason: 'a clip plays meanwhile');
    expect(both.isDoing(CardActivity.playing, 'bob'), isTrue);
    expect(both.doing(CardActivity.playing, 'cat').cardDoing(CardActivity.playing), 'cat');

    final played = both.done(CardActivity.playing);
    expect(played.cardDoing(CardActivity.playing), isNull);
    expect(played.recording, isTrue, reason: 'ending one leaves the other');
  });
}

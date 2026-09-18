// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/characters_cubit.dart';

void main() {
  const idle = CharactersState(loading: false, clips: {'ann'});
  const recording = CharactersState(
    loading: false,
    status: PipelineStatus.listening,
    recordingId: 'ann',
  );

  test('plays a clip a card has, and only while nothing else sounds', () {
    expect(idle.canPlayClip('ann'), isTrue);
    expect(idle.canPlayClip('bob'), isFalse, reason: 'no clip of its own');
    expect(idle.copyWith(playingId: 'bob').canPlayClip('ann'), isFalse);
  });

  test('reads a sample only with the voice installed and the worker free', () {
    expect(idle.canPreview(dubbing: false, speechInstalled: true), isTrue);
    expect(idle.canPreview(dubbing: false, speechInstalled: false), isFalse);
    expect(idle.canPreview(dubbing: true, speechInstalled: true), isFalse);
    expect(recording.canPreview(dubbing: false, speechInstalled: true), isFalse);
    expect(
      idle.copyWith(buildingId: 'bob').canPreview(dubbing: false, speechInstalled: true),
      isFalse,
    );
  });

  test('records on a running session, one card at a time', () {
    expect(idle.recordActionFor('ann'), isNull, reason: 'no session to record through');
    expect(recording.recordActionFor('ann'), RecordAction.stop);
    expect(recording.recordActionFor('bob'), isNull, reason: 'another card is recording');
    const listening = CharactersState(loading: false, status: PipelineStatus.listening);
    expect(listening.recordActionFor('bob'), RecordAction.start);
  });

  test('takes files with the converter installed and nothing else measuring', () {
    expect(idle.takesFiles(dubbing: false, converterInstalled: true), isTrue);
    expect(idle.takesFiles(dubbing: false, converterInstalled: false), isFalse);
    expect(idle.takesFiles(dubbing: true, converterInstalled: true), isFalse);
    expect(recording.takesFiles(dubbing: false, converterInstalled: true), isFalse);
  });
}

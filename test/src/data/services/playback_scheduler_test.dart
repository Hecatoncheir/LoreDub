// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/playback_scheduler.dart';

void main() {
  late Map<String, Completer<void>> sounding;
  late List<String> started;
  late PlaybackScheduler scheduler;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// Lets [wavePath] reach its end, as the speakers finishing it would.
  Future<void> finish(String wavePath) async {
    sounding.remove(wavePath)!.complete();
    await settle();
  }

  setUp(() {
    sounding = {};
    started = [];
    scheduler = PlaybackScheduler(
      maxVoices: overlappingVoices,
      play: (wavePath) {
        started.add(wavePath);
        return (sounding[wavePath] = Completer<void>()).future;
      },
    );
  });

  test('starts another character while the first is still speaking', () async {
    scheduler
      ..add('a1', speaker: 'timbre:0')
      ..add('b1', speaker: 'timbre:1');
    await settle();

    expect(started, ['a1', 'b1']);
    expect(scheduler.playing, 2);
  });

  test('never lets a character talk over themselves', () async {
    scheduler
      ..add('a1', speaker: 'timbre:0')
      ..add('a2', speaker: 'timbre:0')
      ..add('b1', speaker: 'timbre:1');
    await settle();

    expect(started, ['a1', 'b1'], reason: 'the other character overtakes the waiting line');

    await finish('a1');
    expect(started, ['a1', 'b1', 'a2']);
  });

  test('holds a third voice until one of two has finished', () async {
    scheduler
      ..add('a1', speaker: 'timbre:0')
      ..add('b1', speaker: 'timbre:1')
      ..add('c1', speaker: 'timbre:2');
    await settle();
    expect(started, ['a1', 'b1']);

    await finish('b1');
    expect(started, ['a1', 'b1', 'c1']);
  });

  test('plays a line of unknown speaker alone and in its turn', () async {
    scheduler
      ..add('a1', speaker: 'timbre:0')
      ..add('unknown')
      ..add('b1', speaker: 'timbre:1');
    await settle();
    expect(started, ['a1'], reason: 'nothing overtakes a line that may be anyone');

    await finish('a1');
    expect(started, ['a1', 'unknown']);

    await finish('unknown');
    expect(started, ['a1', 'unknown', 'b1']);
  });

  test('keeps strict order when overlapping is off', () async {
    scheduler
      ..maxVoices = 1
      ..add('a1', speaker: 'timbre:0')
      ..add('b1', speaker: 'timbre:1')
      ..add('a2', speaker: 'timbre:0');
    await settle();
    expect(started, ['a1']);

    await finish('a1');
    await finish('b1');
    expect(started, ['a1', 'b1', 'a2']);
  });

  test('carries on after a line that failed to play', () async {
    final failing = PlaybackScheduler(
      maxVoices: 1,
      play: (wavePath) async {
        started.add(wavePath);
        if (wavePath == 'broken') throw StateError('no device');
      },
    );

    failing
      ..add('broken', speaker: 'voice:aidar')
      ..add('next', speaker: 'voice:aidar');
    await settle();
    await settle();

    expect(started, ['broken', 'next']);
  });

  test('drops what has not started when cleared', () async {
    scheduler
      ..add('a1', speaker: 'timbre:0')
      ..add('a2', speaker: 'timbre:0');
    await settle();

    expect(scheduler.clear(), ['a2']);
    await finish('a1');
    expect(started, ['a1']);
    expect(scheduler.waiting, 0);
  });
}

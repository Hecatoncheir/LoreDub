// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/phrase_queue.dart';

void main() {
  test('voices phrases one at a time in the order they were spoken', () async {
    final events = <String>[];
    final queue = PhraseQueue(
      process: (phrase) async {
        events.add('start ${phrase.text}');
        await Future<void>.delayed(Duration.zero);
        events.add('done ${phrase.text}');
      },
    );

    queue
      ..add(PendingPhrase.text('one'))
      ..add(PendingPhrase.text('two'))
      ..add(PendingPhrase.text('three'));
    await queue.drained;

    expect(events, [
      'start one',
      'done one',
      'start two',
      'done two',
      'start three',
      'done three',
    ]);
  });

  test('keeps every phrase when speech outruns processing', () async {
    final processed = <String>[];
    final queue = PhraseQueue(
      process: (phrase) async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        processed.add(phrase.text!);
      },
    );

    for (var index = 0; index < 20; index++) {
      queue.add(PendingPhrase.text('$index'));
    }
    await queue.drained;

    expect(processed, List.generate(20, (index) => '$index'));
  });

  test('picks up a phrase captured while another is being processed', () async {
    final processed = <String>[];
    late PhraseQueue queue;
    queue = PhraseQueue(
      process: (phrase) async {
        processed.add(phrase.text!);
        if (phrase.text == 'first') queue.add(PendingPhrase.text('second'));
      },
    );

    queue.add(PendingPhrase.text('first'));
    await queue.drained;

    expect(processed, ['first', 'second']);
  });

  test('a failing phrase does not strand the ones behind it', () async {
    final processed = <String>[];
    final queue = PhraseQueue(
      process: (phrase) async {
        if (phrase.text == 'bad') throw StateError('whisper failed');
        processed.add(phrase.text!);
      },
    );

    queue
      ..add(PendingPhrase.text('bad'))
      ..add(PendingPhrase.text('good'));
    await queue.drained;

    expect(processed, ['good']);
  });

  test('clear hands back the phrases that were still waiting', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final queue = PhraseQueue(
      process: (phrase) async {
        if (!started.isCompleted) started.complete();
        await release.future;
      },
    );

    queue
      ..add(PendingPhrase.audio(r'C:\work\segment-1.wav'))
      ..add(PendingPhrase.audio(r'C:\work\segment-2.wav'))
      ..add(PendingPhrase.audio(r'C:\work\segment-3.wav'));
    await started.future;
    final abandoned = queue.clear();
    release.complete();
    await queue.drained;

    expect(abandoned.map((phrase) => phrase.wavePath), [
      r'C:\work\segment-2.wav',
      r'C:\work\segment-3.wav',
    ]);
    expect(queue.length, 0);
  });

  test('drained completes immediately when nothing is queued', () async {
    final queue = PhraseQueue(process: (_) async {});

    await expectLater(queue.drained, completes);
  });
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/worker_channel.dart';
import 'package:lore_dub/src/domain/failure.dart';

void main() {
  late StringBuffer written;
  late WorkerChannel channel;

  setUp(() {
    written = StringBuffer();
    channel = WorkerChannel(lastWords: () => 'Traceback: out of memory');
  });

  /// The requests written so far, as the worker reads them.
  List<Map<String, Object?>> sent() => [
    for (final line in const LineSplitter().convert(written.toString()))
      jsonDecode(line) as Map<String, Object?>,
  ];

  Matcher failsWith(FailureCode code, {Object? detail}) => throwsA(
    isA<LoreDubFailure>()
        .having((failure) => failure.code, 'code', code)
        .having((failure) => failure.detail, 'detail', detail ?? anything),
  );

  test('writes each request on a line of its own, numbered, and answers by the number', () async {
    final first = channel.request(written, {
      'listen': 'a.wav',
    }, timeout: const Duration(seconds: 1));
    final second = channel.request(written, {
      'listen': 'b.wav',
    }, timeout: const Duration(seconds: 1));

    final [one, two] = sent();
    expect(one, {'id': 1, 'listen': 'a.wav'});
    expect(two, {'id': 2, 'listen': 'b.wav'});

    // Answered out of order, each reaches the one who asked.
    channel.answer({'id': 2, 'speaker': 'timbre:2'});
    channel.answer({'id': 1, 'speaker': 'timbre:1'});
    expect((await first)['speaker'], 'timbre:1');
    expect((await second)['speaker'], 'timbre:2');
  });

  test('reads an error in the reply as the worker failing', () async {
    final asked = channel.request(written, {'text': 'Hi'}, timeout: const Duration(seconds: 1));
    channel.answer({'id': 1, 'error': 'CUDA out of memory'});

    await expectLater(asked, failsWith(FailureCode.workerFailed, detail: 'CUDA out of memory'));
  });

  test('gives up after its timeout with what the worker said last', () async {
    final asked = channel.request(
      written,
      {'text': 'Hi'},
      timeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      asked,
      failsWith(FailureCode.workerTimeout, detail: 'Traceback: out of memory'),
    );
    // A reply arriving late answers nobody.
    expect(() => channel.answer({'id': 1, 'translated': 'Привет'}), returnsNormally);
  });

  test('fails everything still waiting once the worker is gone', () async {
    final asked = channel.request(written, {'text': 'Hi'}, timeout: const Duration(minutes: 2));
    channel.failAll(const LoreDubFailure(FailureCode.pipelineStopped));

    await expectLater(asked, failsWith(FailureCode.pipelineStopped));
  });

  test('passes over a line that answers no request', () {
    expect(() => channel.answer({'type': 'progress', 'value': 0.5}), returnsNormally);
    expect(() => channel.answer({'id': 99, 'translated': 'x'}), returnsNormally);
  });
}

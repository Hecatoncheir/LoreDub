// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/local_inference_service.dart';

void main() {
  test('reads a translated reply written as UTF-8', () async {
    final reply = jsonEncode({'id': 1, 'translated': 'Ворота запечатаны.'});
    final Stream<List<int>> source = Stream.value(utf8.encode('$reply\n'));

    final lines = await decodeWorkerLines(source).toList();

    expect(lines, [reply]);
    expect(jsonDecode(lines.single), containsPair('translated', 'Ворота запечатаны.'));
  });

  test('survives a reply the interpreter wrote in the ANSI code page', () async {
    // cp1251 bytes for 'Вход' inside an otherwise ASCII JSON line: the decoder
    // must not tear the stream down and lose every later reply.
    final source = Stream.value([
      ...utf8.encode('{"id": 1, "translated": "'),
      0xC2,
      0xF5,
      0xEE,
      0xE4,
      ...utf8.encode('"}\n{"id": 2}\n'),
    ]);

    final lines = await decodeWorkerLines(source).toList();

    expect(lines, hasLength(2));
    expect(lines.last, '{"id": 2}');
  });

  test('splits replies that arrive in one chunk', () async {
    final Stream<List<int>> source = Stream.value(
      utf8.encode('{"type": "ready"}\n{"id": 7}\n'),
    );

    expect(await decodeWorkerLines(source).toList(), ['{"type": "ready"}', '{"id": 7}']);
  });

  test('explains a worker crash with the reason it printed', () {
    final diagnostics = WorkerDiagnostics()
      ..add('Python was not found; run without arguments to install from the Microsoft Store');

    final message = diagnostics.describeExit(9009);

    expect(message, contains('9009'));
    expect(message, contains('Microsoft Store'));
  });

  test('keeps only the last stderr lines and drops blank ones', () {
    final diagnostics = WorkerDiagnostics(limit: 2)
      ..add('first')
      ..add('   ')
      ..add('')
      ..add('second')
      ..add('third');

    final message = diagnostics.describeExit(1);

    expect(message, isNot(contains('first')));
    expect(message, contains('second'));
    expect(message, contains('third'));
  });

  test('points at the interpreter when the worker dies silently', () {
    final diagnostics = WorkerDiagnostics();

    expect(diagnostics.isEmpty, isTrue);
    expect(
      diagnostics.describeExit(1),
      allOf(contains('torch'), contains('transformers')),
    );
  });

  test('forgets the previous run when the pipeline restarts', () {
    final diagnostics = WorkerDiagnostics()
      ..add('stale failure')
      ..clear();

    expect(diagnostics.describeExit(1), isNot(contains('stale failure')));
  });
}

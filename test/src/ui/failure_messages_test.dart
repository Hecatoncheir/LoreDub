// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/l10n/app_localizations.dart';
import 'package:lore_dub/src/data/services/local_inference_service.dart';
import 'package:lore_dub/src/data/services/python_discovery.dart';
import 'package:lore_dub/src/domain/failure.dart';
import 'package:lore_dub/src/ui/failure_messages.dart';

void main() {
  late AppLocalizations ru;
  late AppLocalizations en;

  setUp(() async {
    ru = await AppLocalizations.delegate.load(const Locale('ru'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('writes every failure out in both interface languages', () {
    for (final code in FailureCode.values) {
      final failure = LoreDubFailure(code, detail: '42');
      expect(describeFailure(ru, failure), isNotEmpty, reason: code.name);
      expect(describeFailure(en, failure), isNotEmpty, reason: code.name);
      expect(
        describeFailure(ru, failure),
        isNot(contains('42\u0000')),
        reason: '${code.name} leaks the separator',
      );
    }
  });

  test('follows the interface language', () {
    const failure = LoreDubFailure(FailureCode.workerNotRunning);

    expect(describeFailure(ru, failure), 'Marian/Silero worker не запущен');
    expect(describeFailure(en, failure), 'The Marian/Silero worker is not running');
  });

  test('keeps the technical detail as it came', () {
    final failure = LoreDubFailure(
      FailureCode.whisperMissing,
      detail: r'C:\Program Files\LoreDub\runtime\whisper\whisper-cli.exe',
    );

    expect(describeFailure(en, failure), contains(r'C:\Program Files\LoreDub'));
  });

  test('splits the worker exit code from its output', () {
    final failure = WorkerDiagnostics().let((diagnostics) {
      diagnostics.add('ModuleNotFoundError: torch');
      return diagnostics.describeExit(9009);
    });

    final message = describeFailure(en, failure);

    expect(message, contains('9009'));
    expect(message, contains('ModuleNotFoundError: torch'));
    expect(message, isNot(contains('\u0000')));
  });

  test('shows an unexpected error as it is rather than translating it', () {
    expect(describeFailure(ru, StateError('boom')), contains('boom'));
  });

  test('names the interpreters a search turned down', () {
    const rejected = [
      RejectedPython(r'C:\Python314\python.exe', version: '3.14.0'),
      RejectedPython(r'C:\broken\python.exe'),
    ];

    final russian = describeRejectedPython(ru, rejected);
    final english = describeRejectedPython(en, rejected);

    expect(russian, contains('нет torch/transformers'));
    expect(russian, contains('не запускается'));
    expect(english, contains('no torch/transformers'));
    expect(english, contains('does not start'));
  });

  test('writes every startup stage the pipeline reports', () {
    for (final stage in [
      'python',
      'torch',
      'transformers',
      'translator',
      'speech',
      'converter',
      'capture',
    ]) {
      expect(describeStartupStage(ru, stage), isNot(stage), reason: stage);
      expect(describeStartupStage(en, stage), isNot(stage), reason: stage);
    }
    // An unknown stage is shown as it came instead of vanishing.
    expect(describeStartupStage(ru, 'quantum'), 'quantum');
  });
}

extension<T> on T {
  R let<R>(R Function(T) body) => body(this);
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/repositories/app_repository.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:lore_dub/src/domain/failure.dart';

void main() {
  late _SlowEngine engine;
  late AppRepository repository;

  setUp(() {
    engine = _SlowEngine();
    repository = AppRepository(engine, SettingsService());
  });

  /// The start with the least to it: the converter alone, and no game.
  Future<void> start() => repository.startVoiceFiles(
    settings: const AppSettings(),
    converterDirectory: 'converter',
    converterBackend: ComputeBackend.cpu,
    runtimeDirectory: 'runtime',
  );

  Matcher failsWith(FailureCode code) =>
      throwsA(isA<LoreDubFailure>().having((failure) => failure.code, 'code', code));

  test('clears away what a failed start left behind', () async {
    final starting = expectLater(start(), failsWith(FailureCode.workerStartTimeout));

    engine.starts.single.completeError(const LoreDubFailure(FailureCode.workerStartTimeout));
    await starting;

    expect(engine.stops, 1);
  });

  test('leaves a newer session alone when the start it replaced fails at last', () async {
    final replaced = expectLater(start(), failsWith(FailureCode.pipelineStopped));
    final current = start();

    // Minutes later, as a start nobody ended used to: into whichever session
    // was running by then.
    engine.starts.first.completeError(TimeoutException('Future not completed'));
    await replaced;

    expect(engine.stops, 0, reason: 'the engine holds a session that is not this start\'s to end');
    engine.starts.last.complete();
    await current;
  });

  test('ends a start the player stopped as stopped, whatever it failed with', () async {
    final stopped = expectLater(start(), failsWith(FailureCode.pipelineStopped));

    await repository.stop();
    engine.starts.single.completeError(StateError('the pipe closed under it'));
    await stopped;

    expect(engine.stops, 1, reason: 'the stop that was asked for, and not a second one');
  });
}

/// An engine whose starts end when the test says so, the way a real one ends
/// minutes after it was asked.
class _SlowEngine extends NativeEngineService {
  final starts = <Completer<void>>[];
  int stops = 0;

  @override
  Future<void> startVoiceFiles(Map<String, Object?> config) {
    final starting = Completer<void>();
    starts.add(starting);
    return starting.future;
  }

  @override
  Future<void> stop() async => stops++;
}

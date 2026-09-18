// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/repositories/app_repository.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/built_voice.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:lore_dub/src/domain/failure.dart';
import 'package:lore_dub/src/domain/voice_files.dart';

void main() {
  late _SlowEngine engine;
  late AppRepository repository;

  setUp(() {
    engine = _SlowEngine();
    repository = AppRepository(engine, SettingsService());
  });

  /// The start with the least to it: the converter alone, and no game. It
  /// answers with the number of the session it began.
  Future<int> start() => repository.startVoiceFiles(
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

  group('a session that was borrowed', () {
    /// A start that came up, and the number it answered with.
    Future<int> borrow() {
      final borrowing = start();
      engine.starts.last.complete();
      return borrowing;
    }

    test('is put down while it is still the one the engine holds', () async {
      final borrowed = await borrow();

      await repository.stopSession(borrowed);

      expect(engine.stops, 1);
    });

    test('is left alone once another session has replaced it', () async {
      final borrowed = await borrow();
      // Live starting takes the worker over, and asks nobody.
      await borrow();

      await repository.stopSession(borrowed);

      expect(engine.stops, 0, reason: 'what the engine holds by now is somebody else\'s');
    });

    test('is not stopped a second time once it has been stopped', () async {
      final borrowed = await borrow();
      await repository.stop();
      // Whatever started since is not this number's to end either.
      final current = await borrow();

      await repository.stopSession(borrowed);

      expect(engine.stops, 1, reason: 'the stop that was asked for, and no other');
      await repository.stopSession(current);
      expect(engine.stops, 2);
    });
  });

  group('files a card is built from', () {
    Future<void> borrow() async {
      final borrowing = start();
      engine.starts.last.complete();
      await borrowing;
    }

    test('are measured through the session they were handed to', () async {
      await borrow();

      final building = repository.buildVoice(['line.ogg']);
      engine.decoding.single.complete(engine.files);

      expect((await building).used, 1);
      expect(engine.measured, [engine.files]);
      expect(engine.discarded, isEmpty);
    });

    test('are dropped unmeasured once Live has taken the worker over', () async {
      await borrow();

      final building = expectLater(
        repository.buildVoice(['line.ogg']),
        failsWith(FailureCode.pipelineStopped),
      );
      // Live stops the session the files were meant for and starts its own
      // while they are still being decoded.
      await repository.stop();
      await borrow();
      engine.decoding.single.complete(engine.files);
      await building;

      expect(engine.measured, isEmpty, reason: 'the worker is the dubbing\'s by now');
      expect(engine.discarded, [engine.files], reason: 'the decoded files are not left behind');
    });
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

  /// The files every decoding answers with, once the test lets it finish.
  final files = const VoiceFiles(decoded: {'dropped_0.wav': 'line.ogg'});
  final decoding = <Completer<VoiceFiles>>[];
  final measured = <VoiceFiles>[];
  final discarded = <VoiceFiles>[];

  @override
  Future<VoiceFiles> decodeVoiceFiles(List<String> paths) {
    final decoded = Completer<VoiceFiles>();
    decoding.add(decoded);
    return decoded.future;
  }

  @override
  Future<BuiltVoice> measureVoiceFiles(VoiceFiles files) async {
    measured.add(files);
    return const BuiltVoice(vector: [1], used: 1);
  }

  @override
  Future<void> discardVoiceFiles(VoiceFiles files, {String? keeping}) async => discarded.add(files);
}

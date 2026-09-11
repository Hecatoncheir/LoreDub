// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lore_dub/src/data/repositories/app_repository.dart';
import 'package:lore_dub/src/data/repositories/model_repository.dart';
import 'package:lore_dub/src/data/repositories/runtime_repository.dart';
import 'package:lore_dub/src/data/repositories/update_repository.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/data/services/model_storage_service.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:lore_dub/src/data/services/notification_service.dart';
import 'package:lore_dub/src/data/services/runtime_storage_service.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/data/services/update_service.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:lore_dub/src/domain/failure.dart';
import 'package:lore_dub/src/domain/game_process.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/dashboard_cubits.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/downloads_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/pipeline_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/settings_cubit.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SlowStartRepository repository;
  late DashboardCubits cubits;
  late DateTime now;
  late PipelineCubit pipeline;

  /// Lets every pending microtask run, which is as far as a start that never
  /// finishes can get.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    repository = _SlowStartRepository();
    cubits = DashboardCubits(
      repository,
      _FixedModelRepository(),
      RuntimeRepository(RuntimeStorageService()),
      UpdateRepository(
        UpdateService(
          client: MockClient((_) async => http.Response('offline', 503)),
          // Read from the platform otherwise, which a unit test does not have.
          packageInfo: Future.value(
            PackageInfo(
              appName: 'LoreDub',
              packageName: 'lore_dub',
              version: '0.4.0',
              buildNumber: '5',
            ),
          ),
        ),
        NotificationService(plugin: FlutterLocalNotificationsPlugin()),
      ),
    );
    // The whole default output needs no process, and every package is in
    // place, so a press is all a start takes.
    cubits.settings.seed(
      const SettingsState(settings: AppSettings(audioCaptureSource: AudioCaptureSource.system)),
    );
    cubits.downloads.seed(
      DownloadsState(
        models: [
          for (final model in modelCatalog) ModelInstallState(model: model, installed: true),
        ],
      ),
    );
    now = DateTime(2026, 9, 11, 12);
    pipeline = PipelineCubit(
      repository,
      _FixedModelRepository(),
      cubits.settings,
      cubits.downloads,
      cubits.shell,
      clock: () => now,
    );
  });

  tearDown(() async {
    await pipeline.close();
    await cubits.dispose();
  });

  test('takes a second press straight after Start for the rest of a double-click', () async {
    unawaited(pipeline.toggle(initializing: false));
    await settle();
    expect(pipeline.state.status, PipelineStatus.starting);
    expect(repository.starts, 1);

    now = now.add(const Duration(milliseconds: 300));
    await pipeline.toggle(initializing: false);

    expect(pipeline.state.status, PipelineStatus.starting, reason: 'the start goes on');
    expect(repository.stops, 0);
  });

  test('still cancels a start when asked once the double-click is over', () async {
    unawaited(pipeline.toggle(initializing: false));
    await settle();

    now = now.add(PipelineCubit.doubleClickGrace);
    await pipeline.toggle(initializing: false);

    expect(pipeline.state.status, PipelineStatus.idle);
    expect(repository.stops, 1);
  });

  test('pauses and resumes on the hotkeys pressed in the game', () async {
    pipeline
      ..listen()
      ..seed(const LivePipelineState(status: PipelineStatus.listening));

    repository.push({'type': 'hotkey', 'action': 'pause'});
    await settle();
    expect(pipeline.state.status, PipelineStatus.paused);
    expect(pipeline.state.running, isTrue, reason: 'a paused session is still a session');

    repository.push({'type': 'hotkey', 'action': 'pause'});
    await settle();
    expect(pipeline.state.status, PipelineStatus.paused, reason: 'pausing twice changes nothing');

    repository.push({'type': 'hotkey', 'action': 'resume'});
    await settle();
    expect(pipeline.state.status, PipelineStatus.listening);
    expect(repository.stops, 0, reason: 'neither tears the session down');
  });

  test('stops for good from a pause', () async {
    pipeline.seed(const LivePipelineState(status: PipelineStatus.paused));

    await pipeline.stop();

    expect(pipeline.state.status, PipelineStatus.idle);
    expect(repository.stops, 1);
  });

  group('the snapshot session', () {
    const waiting = LivePipelineState(
      status: PipelineStatus.listening,
      session: PipelineSession.snapshot,
    );

    test('loads only the translator and the voice', () async {
      await pipeline.toggleSnapshot(initializing: false);

      expect(repository.snapshotStarts, 1);
      expect(repository.snapshotModels.keys, unorderedEquals(['translation', 'speech']));
      expect(pipeline.state.session, PipelineSession.snapshot);
      expect(repository.starts, 0, reason: 'nothing is captured');
    });

    test('keeps a selection apart from the live transcript', () async {
      pipeline
        ..listen()
        ..seed(waiting);

      repository
        ..push({'type': 'snapshotReading'})
        ..push({'type': 'snapshot', 'text': 'Press E to open'});
      await settle();
      expect(pipeline.state.snapshotReading, isTrue, reason: 'the translation is on its way');

      repository.push({
        'type': 'transcript',
        'original': 'Press E to open',
        'translated': 'Нажмите E, чтобы открыть',
        'latencyMs': 800,
        'snapshot': true,
      });
      await settle();
      expect(pipeline.state.snapshots.single.translated, 'Нажмите E, чтобы открыть');
      expect(pipeline.state.transcript, isEmpty);
      expect(pipeline.state.snapshotReading, isFalse);
    });

    test('says when a selection held no text', () async {
      pipeline
        ..listen()
        ..seed(waiting);

      repository
        ..push({'type': 'snapshotReading'})
        ..push({'type': 'snapshot', 'text': ''});
      await settle();

      expect(pipeline.state.snapshotMissed, isTrue);
      expect(pipeline.state.snapshotReading, isFalse);
    });

    test('gives the worker over when live dubbing starts', () async {
      pipeline.seed(waiting);

      unawaited(pipeline.toggle(initializing: false));
      await settle();

      expect(repository.stops, 1, reason: 'the worker was loaded without whisper');
      expect(repository.starts, 1);
      expect(pipeline.state.session, PipelineSession.live);
    });

    test('leaves live dubbing to be stopped from its own screen', () async {
      pipeline.seed(const LivePipelineState(status: PipelineStatus.listening));

      await pipeline.toggleSnapshot(initializing: false);

      expect(repository.stops, 0);
      expect(repository.snapshotStarts, 0);
    });
  });

  test('raises the banner for a capture failure and keeps it through an empty error', () async {
    pipeline.listen();
    const failure = LoreDubFailure(
      FailureCode.captureFailed,
      detail: 'English OCR language is not installed.',
    );

    repository.push({'type': 'error', 'failure': failure});
    await settle();
    expect(cubits.shell.state.error, same(failure));

    repository.push({'type': 'error'});
    await settle();
    expect(
      cubits.shell.state.error,
      same(failure),
      reason: 'an event with nothing to show is no reason to clear the banner',
    );
  });
}

/// A start that never finishes, as a first start does while the worker loads
/// Marian and Silero.
class _SlowStartRepository extends AppRepository {
  _SlowStartRepository() : super(NativeEngineService(), SettingsService());

  final _events = StreamController<Map<String, Object?>>.broadcast();
  int starts = 0;
  int stops = 0;
  int snapshotStarts = 0;
  Map<String, String> snapshotModels = const {};

  void push(Map<String, Object?> event) => _events.add(event);

  @override
  Stream<Map<String, Object?>> get events => _events.stream;

  @override
  Future<void> start({
    required GameProcess? process,
    required AppSettings settings,
    required Map<String, String> modelDirectories,
    required String speaker,
    required String translationPrefix,
    required bool translateSpeech,
    required bool followSpeaker,
    required List<String> maleVoices,
    required List<String> femaleVoices,
    required ComputeBackend recognitionBackend,
    required ComputeBackend translationBackend,
    required ComputeBackend voiceConversionBackend,
    required String runtimeDirectory,
    String? voiceBank,
  }) {
    starts++;
    return Completer<void>().future;
  }

  @override
  Future<void> startSnapshot({
    required AppSettings settings,
    required Map<String, String> modelDirectories,
    required String speaker,
    required String translationPrefix,
    required ComputeBackend translationBackend,
    required String runtimeDirectory,
  }) async {
    snapshotStarts++;
    snapshotModels = modelDirectories;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  void dispose() {
    unawaited(_events.close());
  }
}

/// Model directories without a disk behind them.
class _FixedModelRepository extends ModelRepository {
  _FixedModelRepository() : super(ModelStorageService());

  @override
  Future<String> directoryFor(ModelPackage model) async => 'models';
}

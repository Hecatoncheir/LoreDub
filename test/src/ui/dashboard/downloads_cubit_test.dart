// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/repositories/model_repository.dart';
import 'package:lore_dub/src/data/repositories/runtime_repository.dart';
import 'package:lore_dub/src/data/repositories/settings_repository.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/data/services/model_storage_service.dart';
import 'package:lore_dub/src/data/services/runtime_storage_service.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/domain/download_control.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/downloads_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/shell_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _HeldModels models;
  late DownloadsCubit downloads;
  late _Banner banner;

  /// The first package of the catalogue, which the tests fetch.
  final first = modelCatalog.first;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    models = _HeldModels();
    banner = _Banner();
    downloads = DownloadsCubit(
      models,
      _NoRuntimes(),
      SettingsRepository(SettingsService()),
      banner,
    );
    await downloads.load();
  });

  tearDown(() async {
    await downloads.close();
  });

  ModelInstallState rowFor(String id) =>
      downloads.state.models.firstWhere((install) => install.model.id == id);

  test('writes the progress and the end on the row it was asked for', () async {
    final fetching = downloads.installModel(rowFor(first.id));
    await pumpEventQueue();

    models.report(0.5);
    await pumpEventQueue();
    expect(rowFor(first.id).progress, 0.5);

    models.finish(DownloadOutcome.completed);
    await fetching;

    expect(rowFor(first.id).installed, isTrue);
    expect(rowFor(first.id).progress, isNull);
  });

  test('still writes on the right row when the list was reread mid-flight', () async {
    // What rereading what is on disk does: a whole new list of rows. The
    // download was addressed by the index of the row it started on, so
    // after this it wrote its ticks and its outcome on whatever stood
    // there -- which, with the catalogue reordered, is another package.
    final fetching = downloads.installModel(rowFor(first.id));
    await pumpEventQueue();

    models.reversed = true;
    await downloads.load();
    models.report(0.5);
    await pumpEventQueue();

    expect(rowFor(first.id).progress, 0.5, reason: 'the one being fetched');
    for (final other in downloads.state.models.where((row) => row.model.id != first.id)) {
      expect(other.progress, isNull, reason: '${other.model.id} was not asked for');
    }

    models.finish(DownloadOutcome.completed);
    await fetching;

    expect(rowFor(first.id).installed, isTrue);
  });

  test('a pause keeps the bar where it stopped and a cancel clears it', () async {
    var fetching = downloads.installModel(rowFor(first.id));
    await pumpEventQueue();
    models.report(0.4);
    await pumpEventQueue();

    models.finish(DownloadOutcome.paused);
    await fetching;
    expect(rowFor(first.id).progress, 0.4, reason: 'asking again reads as carrying on');
    expect(rowFor(first.id).paused, isTrue);

    fetching = downloads.installModel(rowFor(first.id));
    await pumpEventQueue();
    models.finish(DownloadOutcome.cancelled);
    await fetching;

    expect(rowFor(first.id).progress, isNull);
    expect(rowFor(first.id).paused, isFalse);
  });

  test('a second press while it is arriving is not a second download', () async {
    final fetching = downloads.installModel(rowFor(first.id));
    await pumpEventQueue();

    await downloads.installModel(rowFor(first.id));

    expect(models.asked, 1);
    models.finish(DownloadOutcome.completed);
    await fetching;
  });

  test('a failure is written on the row rather than raised to the banner', () async {
    final fetching = downloads.installModel(rowFor(first.id));
    await pumpEventQueue();

    models.fail(StateError('no route to host'));
    await fetching;

    expect(rowFor(first.id).error, isA<StateError>());
    expect(rowFor(first.id).progress, isNull);
    expect(banner.raised, isEmpty, reason: 'the row says it; the banner is for the whole app');
  });
}

/// A model store whose download is held open, so a test can tick it along
/// and say how it ended.
class _HeldModels extends ModelRepository {
  _HeldModels() : super(ModelStorageService());

  /// Reverses what [loadStates] answers, for the test that rereads the
  /// list while a download is running.
  bool reversed = false;

  int asked = 0;
  Completer<DownloadOutcome>? _outcome;
  DownloadProgress? _onProgress;

  void report(double progress) => _onProgress?.call(progress);

  void finish(DownloadOutcome outcome) => _outcome?.complete(outcome);

  void fail(Object error) => _outcome?.completeError(error);

  @override
  Future<List<ModelInstallState>> loadStates() async {
    final rows = [for (final model in modelCatalog) ModelInstallState(model: model)];
    return reversed ? rows.reversed.toList() : rows;
  }

  @override
  Future<String> rootDirectory() async => r'C:\models';

  @override
  Future<DownloadOutcome> install(
    ModelPackage model, {
    required DownloadProgress onProgress,
    String proxyUrl = '',
    DownloadControl? control,
  }) {
    asked++;
    _onProgress = onProgress;
    return (_outcome = Completer<DownloadOutcome>()).future;
  }
}

/// No GPU runtimes and no directory to look for them in: these tests are
/// about the models.
class _NoRuntimes extends RuntimeRepository {
  _NoRuntimes() : super(RuntimeStorageService());

  @override
  Future<Set<String>> installedIds() async => const {};

  @override
  Future<String> rootDirectory() async => 'C:/runtime';
}

class _Banner implements FailureSink {
  final raised = <Object>[];

  @override
  void report(Object? error) {
    if (error != null) raised.add(error);
  }
}

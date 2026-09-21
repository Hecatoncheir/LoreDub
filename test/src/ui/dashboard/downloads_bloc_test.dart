// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/repositories/install_repository.dart';
import 'package:lore_dub/src/data/repositories/model_repository.dart';
import 'package:lore_dub/src/data/repositories/runtime_repository.dart';
import 'package:lore_dub/src/data/repositories/settings_repository.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/data/services/model_storage_service.dart';
import 'package:lore_dub/src/data/services/runtime_storage_service.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/domain/download_control.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/downloads_bloc.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/failure_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _HeldModels models;
  late DownloadsBloc downloads;
  late InstallRepository installed;
  late _Banner banner;

  /// The first package of the catalogue, which the tests fetch.
  final first = modelCatalog.first;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    models = _HeldModels();
    banner = _Banner();
    final runtimes = _NoRuntimes();
    installed = InstallRepository(models, runtimes);
    downloads = DownloadsBloc(
      models,
      runtimes,
      installed,
      SettingsRepository(SettingsService()),
      banner,
    );
    await installed.load();
    await pumpEventQueue();
  });

  tearDown(() async {
    await downloads.close();
  });

  ModelInstallState rowFor(String id) =>
      downloads.state.models.firstWhere((install) => install.model.id == id);

  test('writes the progress and the end on the row it was asked for', () async {
    downloads.add(ModelInstallAsked(rowFor(first.id)));
    await pumpEventQueue();

    models.report(0.5);
    await pumpEventQueue();
    expect(rowFor(first.id).progress, 0.5);

    models.finish(DownloadOutcome.completed);
    await pumpEventQueue();

    expect(rowFor(first.id).installed, isTrue);
    expect(rowFor(first.id).progress, isNull);
  });

  test('still writes on the right row when the list was reread mid-flight', () async {
    // What rereading what is on disk does: a whole new list of rows. The
    // download was addressed by the index of the row it started on, so
    // after this it wrote its ticks and its outcome on whatever stood
    // there -- which, with the catalogue reordered, is another package.
    downloads.add(ModelInstallAsked(rowFor(first.id)));
    await pumpEventQueue();

    models.reversed = true;
    await installed.load();
    await pumpEventQueue();
    models.report(0.5);
    await pumpEventQueue();

    expect(rowFor(first.id).progress, 0.5, reason: 'the one being fetched');
    for (final other in downloads.state.models.where((row) => row.model.id != first.id)) {
      expect(other.progress, isNull, reason: '${other.model.id} was not asked for');
    }

    models.finish(DownloadOutcome.completed);
    await pumpEventQueue();

    expect(rowFor(first.id).installed, isTrue);
  });

  test('a pause keeps the bar where it stopped and a cancel clears it', () async {
    downloads.add(ModelInstallAsked(rowFor(first.id)));
    await pumpEventQueue();
    models.report(0.4);
    await pumpEventQueue();

    models.finish(DownloadOutcome.paused);
    await pumpEventQueue();
    expect(rowFor(first.id).progress, 0.4, reason: 'asking again reads as carrying on');
    expect(rowFor(first.id).paused, isTrue);

    downloads.add(ModelInstallAsked(rowFor(first.id)));
    await pumpEventQueue();
    models.finish(DownloadOutcome.cancelled);
    await pumpEventQueue();

    expect(rowFor(first.id).progress, isNull);
    expect(rowFor(first.id).paused, isFalse);
  });

  test('a second press while it is arriving is not a second download', () async {
    downloads.add(ModelInstallAsked(rowFor(first.id)));
    await pumpEventQueue();

    downloads.add(ModelInstallAsked(rowFor(first.id)));
    await pumpEventQueue();

    expect(models.asked, 1);
    models.finish(DownloadOutcome.completed);
    await pumpEventQueue();
  });

  test('a model that lands is on disk for every screen, not only this one', () async {
    expect(
      installed.parts.models.firstWhere((row) => row.model.id == first.id).installed,
      isFalse,
    );

    downloads.add(ModelInstallAsked(rowFor(first.id)));
    await pumpEventQueue();
    models.finish(DownloadOutcome.completed);
    await pumpEventQueue();

    // What the dubbing screens and the cast screen read: they ask the
    // repository, not this bloc.
    expect(
      installed.parts.models.firstWhere((row) => row.model.id == first.id).installed,
      isTrue,
    );
  });

  test('a model thrown away is gone for every screen too', () async {
    installed.seed(
      InstalledParts(
        models: [
          for (final model in modelCatalog) ModelInstallState(model: model, installed: true),
        ],
      ),
    );
    await installed.load();
    await pumpEventQueue();

    downloads.add(ModelRemoved(rowFor(first.id)));
    await pumpEventQueue();

    expect(
      installed.parts.models.firstWhere((row) => row.model.id == first.id).installed,
      isFalse,
    );
  });

  test('pausing or cancelling what is not arriving changes nothing', () async {
    // A row staged with progress has no attempt in flight, so there is no
    // control to signal. Asking anyway must be harmless rather than throw.
    downloads
      ..add(DownloadPaused(first.id))
      ..add(DownloadCancelled(first.id));
    await pumpEventQueue();

    expect(downloads.state.isStopping(first.id), isFalse);
    expect(banner.raised, isEmpty);
  });

  test('a pause reaches the download it stops while it is still arriving', () async {
    downloads.add(ModelInstallAsked(rowFor(first.id)));
    await pumpEventQueue();

    downloads.add(DownloadPaused(first.id));
    await pumpEventQueue();
    expect(downloads.state.isStopping(first.id), isTrue, reason: 'answered mid-download');
    expect(models.paused, isTrue);

    models.finish(DownloadOutcome.paused);
    await pumpEventQueue();
    expect(downloads.state.isStopping(first.id), isFalse);
    expect(rowFor(first.id).paused, isTrue);
  });

  test('a failure is written on the row rather than raised to the banner', () async {
    downloads.add(ModelInstallAsked(rowFor(first.id)));
    await pumpEventQueue();

    models.fail(StateError('no route to host'));
    await pumpEventQueue();

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

  /// The handle the download was given, which a pause or a cancel signals.
  DownloadControl? _control;

  /// Whether the download in flight was asked to pause.
  bool get paused => _control?.requestedStop == DownloadOutcome.paused;
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
    _control = control;
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

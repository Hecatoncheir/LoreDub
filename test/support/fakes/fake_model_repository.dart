// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:lore_dub/src/data/repositories/model_repository.dart';
import 'package:lore_dub/src/domain/download_control.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:mocktail/mocktail.dart';

/// The model store without a disk: what is installed is [states], every
/// package sits in one directory, and a download stays open until the test
/// ticks it along and says how it ended.
class FakeModelRepository extends Fake implements ModelRepository {
  FakeModelRepository({this.states = const []});

  List<ModelInstallState> states;

  /// Whether reading what is installed fails, as an unreadable disk does.
  bool loadFails = false;

  /// How many downloads were asked for.
  int asked = 0;

  DownloadControl? _control;
  Completer<DownloadOutcome>? _outcome;
  DownloadProgress? _onProgress;

  /// Whether the download in flight was asked to pause.
  bool get paused => _control?.requestedStop == DownloadOutcome.paused;

  void report(double progress) => _onProgress?.call(progress);

  void finish(DownloadOutcome outcome) => _outcome?.complete(outcome);

  void fail(Object error) => _outcome?.completeError(error);

  @override
  Future<List<ModelInstallState>> loadStates() async {
    if (loadFails) throw StateError('disk unreadable');
    return states;
  }

  @override
  Future<String> directoryFor(ModelPackage model) async => 'models';

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

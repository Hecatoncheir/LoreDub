// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:lore_dub/src/data/repositories/runtime_repository.dart';
import 'package:lore_dub/src/data/services/runtime_catalog.dart';
import 'package:lore_dub/src/domain/download_control.dart';
import 'package:lore_dub/src/domain/runtime_package.dart';
import 'package:mocktail/mocktail.dart';

/// The GPU runtimes without a disk or a network: [installed] is what is
/// there, an install completes at once and a removal takes it away, and
/// both are recorded for the test to read.
class FakeRuntimeRepository extends Fake implements RuntimeRepository {
  FakeRuntimeRepository({Set<String> installed = const {}}) : installed = {...installed};

  final Set<String> installed;
  final removed = <String>[];
  final installs = <String>[];

  @override
  List<RuntimePackage> get catalog => runtimeCatalog;

  @override
  Future<Set<String>> installedIds() async => {...installed};

  @override
  Future<String> rootDirectory() async => r'C:\runtime';

  @override
  Future<void> remove(RuntimePackage package) async {
    removed.add(package.id);
    installed.remove(package.id);
  }

  @override
  Future<DownloadOutcome> install(
    RuntimePackage package, {
    required DownloadProgress onProgress,
    String proxyUrl = '',
    String pythonExecutable = '',
    DownloadControl? control,
  }) async {
    installs.add(package.id);
    return DownloadOutcome.completed;
  }
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lore_dub/src/data/services/runtime_storage_service.dart';
import 'package:lore_dub/src/domain/failure.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/runtime_package.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('lore-dub-runtime-store');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  RuntimeStorageService storeWith(
    http.Client client, {
    Future<ProcessResult> Function(String, List<String>)? runProcess,
  }) => RuntimeStorageService(
    client: client,
    rootProvider: () async => root,
    runProcess: runProcess,
  );

  /// A zip shaped like the official whisper.cpp archives: the binaries sit in
  /// a build subdirectory rather than at the top.
  List<int> nestedArchive({String directory = 'Release'}) {
    final archive = Archive()
      ..addFile(ArchiveFile('$directory/whisper-cli.exe', 7, [...'binary!'.codeUnits]))
      ..addFile(ArchiveFile('$directory/ggml-cuda.dll', 3, [...'dll'.codeUnits]));
    return ZipEncoder().encode(archive);
  }

  RuntimePackage packageFor(List<int> bytes) => RuntimePackage(
    id: 'whisper-cuda',
    kind: RuntimeInstallKind.archive,
    approximateBytes: bytes.length,
    probeFileName: 'whisper-cli.exe',
    artifacts: [
      ModelArtifact(
        fileName: 'build.zip',
        url: Uri.parse('https://example.invalid/build.zip'),
        byteSize: bytes.length,
      ),
    ],
  );

  test('unpacks an archive and lifts the binaries out of their subdirectory', () async {
    final bytes = nestedArchive();
    final package = packageFor(bytes);
    final store = storeWith(MockClient((_) async => http.Response.bytes(bytes, 200)));
    final progress = <double>[];

    await store.install(package, onProgress: progress.add);

    final directory = await store.directoryFor(package);
    expect(File(path.join(directory.path, 'whisper-cli.exe')).existsSync(), isTrue);
    expect(File(path.join(directory.path, 'ggml-cuda.dll')).existsSync(), isTrue);
    expect(
      File(path.join(directory.path, 'build.zip')).existsSync(),
      isFalse,
      reason: 'the archive is not worth keeping once it is unpacked',
    );
    expect(await store.isInstalled(package), isTrue);
    expect(progress.last, 1);
  });

  test('reports a runtime that arrived without the binary it promised', () async {
    final archive = Archive()..addFile(ArchiveFile('Release/readme.txt', 2, [...'hi'.codeUnits]));
    final bytes = ZipEncoder().encode(archive);
    final package = packageFor(bytes);
    final store = storeWith(MockClient((_) async => http.Response.bytes(bytes, 200)));

    await expectLater(
      store.install(package, onProgress: (_) {}),
      throwsA(
        isA<LoreDubFailure>().having((error) => error.code, 'code', FailureCode.runtimeIncomplete),
      ),
    );
  });

  test('refuses an archive whose size does not match the catalogue', () async {
    final package = packageFor(nestedArchive());
    final store = storeWith(
      MockClient((_) async => http.Response.bytes(const [1, 2, 3], 200)),
    );

    await expectLater(
      store.install(package, onProgress: (_) {}),
      throwsA(
        isA<LoreDubFailure>().having(
          (error) => error.code,
          'code',
          FailureCode.verificationFailed,
        ),
      ),
    );
    // Nothing half-written is left claiming to be a runtime.
    expect(await store.isInstalled(package), isFalse);
  });

  test('does not call a runtime installed while only the directory exists', () async {
    final package = packageFor(nestedArchive());
    await (await storeWith(MockClient((_) async => http.Response('', 404))).directoryFor(package))
        .create(recursive: true);

    final store = storeWith(MockClient((_) async => http.Response('', 404)));

    expect(await store.isInstalled(package), isFalse);
  });

  test('reports what pip printed when the CUDA wheels cannot be installed', () async {
    const package = RuntimePackage(
      id: 'torch-cuda',
      kind: RuntimeInstallKind.pip,
      approximateBytes: 2900000000,
      probeFileName: 'torch',
      pipArguments: ['torch==2.7.1+cu126'],
    );
    final store = storeWith(
      MockClient((_) async => http.Response('', 404)),
      runProcess: (executable, arguments) async =>
          ProcessResult(0, 1, '', 'ERROR: No matching distribution found'),
    );

    await expectLater(
      store.install(
        package,
        onProgress: (_) {},
        pythonExecutable: Platform.resolvedExecutable,
      ),
      throwsA(
        isA<LoreDubFailure>()
            .having((error) => error.code, 'code', FailureCode.runtimeInstallFailed)
            .having((error) => error.detail, 'detail', contains('No matching distribution')),
      ),
    );
  });

  test('installs the CUDA wheels into their own directory', () async {
    const package = RuntimePackage(
      id: 'torch-cuda',
      kind: RuntimeInstallKind.pip,
      approximateBytes: 2900000000,
      probeFileName: 'torch',
      pipArguments: ['--index-url', 'https://example.invalid/cu126', 'torch==2.7.1+cu126'],
    );
    List<String>? seen;
    final store = storeWith(
      MockClient((_) async => http.Response('', 404)),
      runProcess: (executable, arguments) async {
        seen = arguments;
        return ProcessResult(0, 0, '', '');
      },
    );

    await store.install(
      package,
      onProgress: (_) {},
      pythonExecutable: Platform.resolvedExecutable,
    );

    expect(seen, containsAllInOrder(['-m', 'pip', 'install']));
    expect(seen, containsAllInOrder(['--target', path.join(root.path, 'torch-cuda')]));
    expect(seen!.last, 'torch==2.7.1+cu126');
    expect(seen, isNot(contains('--proxy')), reason: 'no proxy was configured');
  });

  test('passes a configured proxy through to pip', () async {
    const package = RuntimePackage(
      id: 'torch-cuda',
      kind: RuntimeInstallKind.pip,
      approximateBytes: 1,
      probeFileName: 'torch',
      pipArguments: ['torch'],
    );
    List<String>? seen;
    final store = storeWith(
      MockClient((_) async => http.Response('', 404)),
      runProcess: (executable, arguments) async {
        seen = arguments;
        return ProcessResult(0, 0, '', '');
      },
    );

    await store.install(
      package,
      onProgress: (_) {},
      proxyUrl: 'http://proxy.invalid:3128',
      pythonExecutable: Platform.resolvedExecutable,
    );

    expect(seen, containsAllInOrder(['--proxy', 'http://proxy.invalid:3128']));
  });

  test('removes a runtime the user no longer wants', () async {
    final bytes = nestedArchive();
    final package = packageFor(bytes);
    final store = storeWith(MockClient((_) async => http.Response.bytes(bytes, 200)));
    await store.install(package, onProgress: (_) {});

    await store.remove(package);

    expect(await store.isInstalled(package), isFalse);
  });
}

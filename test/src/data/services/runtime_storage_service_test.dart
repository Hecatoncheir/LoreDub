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

import '../../../support/temporary_directory.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('lore-dub-runtime-store');
  });

  tearDown(() => deleteOnceReleased(root));

  RuntimeStorageService storeWith(http.Client client, {ProcessStarter? startProcess}) =>
      RuntimeStorageService(
        client: client,
        rootProvider: () async => root,
        startProcess: startProcess,
      );

  /// A process that is already finished, for the pip paths that only care
  /// about the arguments and the exit code.
  ProcessStarter finished(ProcessResult result, {void Function(List<String>)? record}) =>
      (executable, arguments) {
        record?.call(arguments);
        return (result: Future.value(result), kill: () {});
      };

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
      startProcess: finished(ProcessResult(0, 1, '', 'ERROR: No matching distribution found')),
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

  test('clears what a failed pip left behind, keeping only the end of its output', () async {
    const package = RuntimePackage(
      id: 'torch-cuda',
      kind: RuntimeInstallKind.pip,
      approximateBytes: 1,
      probeFileName: 'torch',
      pipArguments: ['torch'],
    );
    final output = [
      for (var line = 0; line < 40; line++) 'Collecting dependency $line',
      'ERROR: Could not install packages due to an OSError',
    ].join('\n');
    final store = storeWith(
      MockClient((_) async => http.Response('', 404)),
      startProcess: (executable, arguments) {
        // pip got as far as moving torch into place before it gave up.
        final target = arguments[arguments.indexOf('--target') + 1];
        Directory(path.join(target, 'torch')).createSync(recursive: true);
        return (result: Future.value(ProcessResult(0, 1, '', output)), kill: () {});
      },
    );

    await expectLater(
      store.install(package, onProgress: (_) {}, pythonExecutable: Platform.resolvedExecutable),
      throwsA(
        isA<LoreDubFailure>().having(
          (error) => error.detail,
          'detail',
          allOf(contains('OSError'), isNot(contains('dependency 0'))),
        ),
      ),
    );
    expect(
      await store.isInstalled(package),
      isFalse,
      reason: 'a half-moved torch directory must not pass the probe',
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
      startProcess: finished(ProcessResult(0, 0, '', ''), record: (arguments) => seen = arguments),
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
      startProcess: finished(ProcessResult(0, 0, '', ''), record: (arguments) => seen = arguments),
    );

    await store.install(
      package,
      onProgress: (_) {},
      proxyUrl: 'http://proxy.invalid:3128',
      pythonExecutable: Platform.resolvedExecutable,
    );

    expect(seen, containsAllInOrder(['--proxy', 'http://proxy.invalid:3128']));
  });

  group('the CUDA torch wheel', () {
    final wheel = List<int>.generate(64, (index) => index);
    const wheelName = 'torch-2.7.1+cu126-cp311-cp311-win_amd64.whl';

    RuntimePackage wheelPackage() => RuntimePackage(
      id: 'torch-cuda',
      kind: RuntimeInstallKind.wheel,
      approximateBytes: wheel.length,
      probeFileName: 'torch',
      wheelPython: 'cp311',
      artifacts: [
        ModelArtifact(
          fileName: wheelName,
          url: Uri.parse('https://example.invalid/torch.whl'),
          byteSize: wheel.length,
        ),
      ],
      pipArguments: const ['--index-url', 'https://example.invalid/cu126', 'torch==2.7.1+cu126'],
    );

    /// An interpreter that answers the version question with [tag] and runs
    /// pip with [pipExit], recording pip's arguments. A pip that succeeds
    /// leaves torch in the target directory, as the real one would.
    ProcessStarter interpreter(
      String tag, {
      required List<List<String>> pipRuns,
      int pipExit = 0,
    }) => (executable, arguments) {
      if (arguments.first == '-c') {
        return (result: Future.value(ProcessResult(0, 0, tag, '')), kill: () {});
      }
      pipRuns.add(arguments);
      if (pipExit == 0) {
        final target = arguments[arguments.indexOf('--target') + 1];
        Directory(path.join(target, 'torch')).createSync(recursive: true);
      }
      return (
        result: Future.value(ProcessResult(0, pipExit, '', pipExit == 0 ? '' : 'ERROR: disk full')),
        kill: () {},
      );
    };

    Directory downloads() => Directory(path.join(root.path, '.downloads', 'torch-cuda'));

    test('fetches the wheel itself and has pip install the local file', () async {
      final pipRuns = <List<String>>[];
      final package = wheelPackage();
      final store = storeWith(
        MockClient((_) async => http.Response.bytes(wheel, 200)),
        startProcess: interpreter('cp311', pipRuns: pipRuns),
      );

      await store.install(
        package,
        onProgress: (_) {},
        pythonExecutable: Platform.resolvedExecutable,
      );

      expect(pipRuns, hasLength(1));
      expect(pipRuns.single.last, path.join(downloads().path, wheelName));
      expect(pipRuns.single, isNot(contains('--index-url')), reason: 'torch is not fetched again');
      expect(await store.isInstalled(package), isTrue);
      expect(downloads().existsSync(), isFalse, reason: 'the wheel is not kept once installed');
    });

    test('leaves another interpreter to pip and the index, as before', () async {
      final pipRuns = <List<String>>[];
      var fetched = 0;
      final store = storeWith(
        MockClient((_) async {
          fetched++;
          return http.Response.bytes(wheel, 200);
        }),
        startProcess: interpreter('cp312', pipRuns: pipRuns),
      );

      await store.install(
        wheelPackage(),
        onProgress: (_) {},
        pythonExecutable: Platform.resolvedExecutable,
      );

      expect(fetched, 0, reason: 'a cp311 wheel is no use to Python 3.12');
      expect(pipRuns.single.last, 'torch==2.7.1+cu126');
    });

    test('keeps the wheel when pip fails, so trying again does not fetch it twice', () async {
      final pipRuns = <List<String>>[];
      var fetched = 0;
      final client = MockClient((_) async {
        fetched++;
        return http.Response.bytes(wheel, 200);
      });
      final package = wheelPackage();

      await expectLater(
        storeWith(
          client,
          startProcess: interpreter('cp311', pipRuns: pipRuns, pipExit: 1),
        ).install(package, onProgress: (_) {}, pythonExecutable: Platform.resolvedExecutable),
        throwsA(
          isA<LoreDubFailure>().having(
            (error) => error.code,
            'code',
            FailureCode.runtimeInstallFailed,
          ),
        ),
      );
      final store = storeWith(client, startProcess: interpreter('cp311', pipRuns: pipRuns));
      expect(await store.isInstalled(package), isFalse);

      await store.install(
        package,
        onProgress: (_) {},
        pythonExecutable: Platform.resolvedExecutable,
      );

      expect(fetched, 1, reason: 'the verified wheel on disk is used again');
      expect(await store.isInstalled(package), isTrue);
    });
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

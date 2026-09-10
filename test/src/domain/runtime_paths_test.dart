// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/runtime_paths.dart';
import 'package:path/path.dart' as path;

void main() {
  Future<Directory> createRuntime() async {
    final directory = await Directory.systemTemp.createTemp('lore-dub-runtime');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    return directory;
  }

  Future<File> createExecutable(Directory root, List<String> segments) async {
    final file = File(path.joinAll([root.path, ...segments]));
    await file.parent.create(recursive: true);
    await file.writeAsString('binary');
    return file;
  }

  test('composes the bundled runtime paths', () async {
    final runtime = await createRuntime();

    expect(
      whisperExecutablePath(runtimeDirectory: runtime.path),
      path.join(runtime.path, 'whisper', 'whisper-cli.exe'),
    );
    expect(
      bundledPythonExecutablePath(runtimeDirectory: runtime.path),
      path.join(runtime.path, 'python', 'python.exe'),
    );
  });

  test('resolves whisper-cli.exe when the runtime is prepared', () async {
    final runtime = await createRuntime();
    final executable = await createExecutable(runtime, ['whisper', 'whisper-cli.exe']);

    expect(
      await resolveWhisperExecutable(runtimeDirectory: runtime.path),
      executable.path,
    );
  });

  test('reports a missing whisper runtime with a setup hint', () async {
    final runtime = await createRuntime();

    await expectLater(
      resolveWhisperExecutable(runtimeDirectory: runtime.path),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('whisper-cli.exe'),
            contains('prepare_windows_runtime.ps1'),
          ),
        ),
      ),
    );
  });

  test('recognizes the Microsoft Store execution alias', () {
    expect(
      isWindowsStoreAliasStub(path.join('C:', 'Users', 'x', 'WindowsApps', 'python.exe')),
      isTrue,
    );
    expect(
      isWindowsStoreAliasStub(
        path.join('C:', 'WindowsApps', 'PythonSoftwareFoundation.Python.3.11', 'python.exe'),
      ),
      isFalse,
    );
    expect(
      isWindowsStoreAliasStub(path.join('C:', 'Python311', 'python.exe')),
      isFalse,
    );
  });

  test('resolves a configured interpreter that exists', () async {
    final runtime = await createRuntime();
    final python = await createExecutable(runtime, ['python', 'python.exe']);

    expect(await resolvePythonExecutable(python.path), python.absolute.path);
  });

  test('rejects the Store alias instead of launching it', () async {
    final runtime = await createRuntime();
    final alias = await createExecutable(runtime, ['WindowsApps', 'python.exe']);

    await expectLater(
      resolvePythonExecutable(alias.path),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains('Microsoft Store'), contains('torch')),
        ),
      ),
    );
  });

  test('reports a missing interpreter with a setup hint', () async {
    final runtime = await createRuntime();
    final missing = path.join(runtime.path, 'python', 'python.exe');

    await expectLater(
      resolvePythonExecutable(missing),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains('Не найден Python'), contains('prepare_windows_runtime.ps1')),
        ),
      ),
    );
  });
}

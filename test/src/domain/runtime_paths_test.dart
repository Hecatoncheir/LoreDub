// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:lore_dub/src/domain/failure.dart';
import 'package:lore_dub/src/domain/runtime_paths.dart';
import 'package:path/path.dart' as path;

import '../../support/temporary_directory.dart';

void main() {
  Future<Directory> createRuntime() async {
    final directory = await Directory.systemTemp.createTemp('lore-dub-runtime');
    addTearDown(() => deleteOnceReleased(directory));
    return directory;
  }

  Future<File> createExecutable(Directory root, List<String> segments) async {
    final file = File(path.joinAll([root.path, ...segments]));
    await file.parent.create(recursive: true);
    await file.writeAsString('binary');
    return file;
  }

  test('scales the default thread count with the CPU', () {
    expect(defaultCpuThreads(2), 2);
    expect(defaultCpuThreads(4), 2);
    expect(defaultCpuThreads(8), 4);
    expect(defaultCpuThreads(12), 6);
    expect(defaultCpuThreads(24), 12);
    expect(defaultCpuThreads(64), 12, reason: 'more threads stop paying off');
  });

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
        isA<LoreDubFailure>()
            .having((error) => error.code, 'code', FailureCode.whisperMissing)
            .having((error) => error.detail, 'detail', contains('whisper-cli.exe')),
      ),
    );
  });

  test('keeps each whisper build in its own directory', () {
    // The builds ship ggml libraries of the same name compiled against
    // different backends; one shared directory would load the wrong one.
    final directories = {
      for (final backend in ComputeBackend.values) whisperBackendDirectory(backend),
    };

    expect(directories, hasLength(ComputeBackend.values.length));
    expect(whisperBackendDirectory(ComputeBackend.cpu), 'whisper');
  });

  test('finds the Vulkan build beside the bundled CPU one', () async {
    final runtime = await createRuntime();
    final executable = await createExecutable(runtime, ['whisper-vulkan', 'whisper-cli.exe']);

    expect(
      await resolveWhisperExecutable(
        runtimeDirectory: runtime.path,
        backend: ComputeBackend.vulkan,
      ),
      executable.path,
    );
  });

  test('finds the CUDA build where it was downloaded, not where the app lives', () async {
    final bundled = await createRuntime();
    final downloaded = await createRuntime();
    final executable = await createExecutable(downloaded, ['whisper-cuda', 'whisper-cli.exe']);

    expect(
      await resolveWhisperExecutable(
        runtimeDirectory: bundled.path,
        downloadedRuntimeDirectory: downloaded.path,
        backend: ComputeBackend.cuda,
      ),
      executable.path,
    );
  });

  test('names the missing GPU binary rather than the CPU one', () async {
    final runtime = await createRuntime();
    await createExecutable(runtime, ['whisper', 'whisper-cli.exe']);

    await expectLater(
      resolveWhisperExecutable(
        runtimeDirectory: runtime.path,
        downloadedRuntimeDirectory: runtime.path,
        backend: ComputeBackend.cuda,
      ),
      throwsA(
        isA<LoreDubFailure>()
            .having((error) => error.code, 'code', FailureCode.whisperMissing)
            .having((error) => error.detail, 'detail', contains('whisper-cuda')),
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
        isA<LoreDubFailure>().having(
          (error) => error.code,
          'code',
          FailureCode.pythonStoreAlias,
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
        isA<LoreDubFailure>()
            .having((error) => error.code, 'code', FailureCode.pythonMissing)
            .having((error) => error.detail, 'detail', missing),
      ),
    );
  });
}

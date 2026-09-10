// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/python_discovery.dart';
import 'package:lore_dub/src/domain/failure.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('lore-dub-python');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<String> createInterpreter(List<String> segments) async {
    final file = File(path.joinAll([root.path, ...segments]));
    await file.parent.create(recursive: true);
    await file.writeAsString('binary');
    return file.path;
  }

  String joinPath(List<String> directories) => directories.join(Platform.isWindows ? ';' : ':');

  PythonProbe probeReturning(Map<String, PythonProbeResult> byPath, {List<String>? visited}) {
    return (executable) async {
      visited?.add(executable);
      return byPath[executable.toLowerCase()] ?? const PythonProbeResult.unusable();
    };
  }

  test('prefers the runtime shipped with the application', () async {
    final bundled = await createInterpreter(['runtime', 'python', 'python.exe']);
    final onPath = await createInterpreter(['tools', 'python.exe']);
    final discovery = PythonDiscovery(
      bundledExecutable: bundled,
      environment: {
        'PATH': joinPath([path.dirname(onPath)]),
      },
      probe: probeReturning({
        bundled.toLowerCase(): const PythonProbeResult(version: '3.11.9', hasDependencies: true),
        onPath.toLowerCase(): const PythonProbeResult(version: '3.14.0', hasDependencies: true),
      }),
    );

    final result = await discovery.find();

    expect(result.executable, bundled);
    expect(result.rejected, isEmpty);
  });

  test('never probes the Microsoft Store execution alias', () async {
    final alias = await createInterpreter(['WindowsApps', 'python.exe']);
    final usable = await createInterpreter(['Python313', 'python.exe']);
    final visited = <String>[];
    final discovery = PythonDiscovery(
      bundledExecutable: path.join(root.path, 'missing', 'python.exe'),
      environment: {
        'PATH': joinPath([path.dirname(alias), path.dirname(usable)]),
      },
      probe: probeReturning({
        usable.toLowerCase(): const PythonProbeResult(version: '3.13.1', hasDependencies: true),
      }, visited: visited),
    );

    final result = await discovery.find();

    expect(result.executable, usable);
    expect(visited, isNot(contains(alias)));
  });

  test('reuses the runtime of an installed LoreDub before anything on PATH', () async {
    final installed = await createInterpreter([
      'local',
      'Programs',
      'LoreDub',
      'runtime',
      'python',
      'python.exe',
    ]);
    final onPath = await createInterpreter(['tools', 'python.exe']);
    final discovery = PythonDiscovery(
      bundledExecutable: path.join(root.path, 'missing', 'python.exe'),
      environment: {
        'PATH': joinPath([path.dirname(onPath)]),
        'LOCALAPPDATA': path.join(root.path, 'local'),
      },
      probe: probeReturning({
        installed.toLowerCase(): const PythonProbeResult(version: '3.11.9', hasDependencies: true),
        onPath.toLowerCase(): const PythonProbeResult(version: '3.14.0', hasDependencies: true),
      }),
    );

    expect((await discovery.find()).executable, installed);
  });

  test('skips an interpreter without torch and transformers', () async {
    final bare = await createInterpreter(['bare', 'python.exe']);
    final complete = await createInterpreter(['complete', 'python.exe']);
    final discovery = PythonDiscovery(
      bundledExecutable: path.join(root.path, 'missing', 'python.exe'),
      environment: {
        'PATH': joinPath([path.dirname(bare), path.dirname(complete)]),
      },
      probe: probeReturning({
        bare.toLowerCase(): const PythonProbeResult(version: '3.14.0', hasDependencies: false),
        complete.toLowerCase(): const PythonProbeResult(
          version: '3.11.9',
          hasDependencies: true,
        ),
      }),
    );

    final result = await discovery.find();

    expect(result.executable, complete);
    expect(result.rejected.single.path, bare);
    expect(result.rejected.single.version, '3.14.0');
  });

  test('searches the standard Windows installation directories', () async {
    final installed = await createInterpreter([
      'local',
      'Programs',
      'Python',
      'Python313',
      'python.exe',
    ]);
    final discovery = PythonDiscovery(
      bundledExecutable: path.join(root.path, 'missing', 'python.exe'),
      environment: {'PATH': '', 'LOCALAPPDATA': path.join(root.path, 'local')},
      probe: probeReturning({
        installed.toLowerCase(): const PythonProbeResult(version: '3.13.1', hasDependencies: true),
      }),
    );

    expect((await discovery.find()).executable, installed);
  });

  test('inspects a duplicated PATH entry only once', () async {
    final python = await createInterpreter(['tools', 'python.exe']);
    final visited = <String>[];
    final discovery = PythonDiscovery(
      bundledExecutable: python,
      environment: {
        'PATH': joinPath([path.dirname(python), path.dirname(python)]),
      },
      probe: probeReturning({}, visited: visited),
    );

    await discovery.find();

    expect(visited, hasLength(1));
  });

  test('explains what was rejected when nothing can run the worker', () async {
    final bare = await createInterpreter(['bare', 'python.exe']);
    final discovery = PythonDiscovery(
      bundledExecutable: path.join(root.path, 'missing', 'python.exe'),
      environment: {
        'PATH': joinPath([path.dirname(bare)]),
      },
      probe: probeReturning({
        bare.toLowerCase(): const PythonProbeResult(version: '3.14.0', hasDependencies: false),
      }),
    );

    final result = await discovery.find();

    expect(result.executable, isNull);
    expect(result.failure.code, FailureCode.pythonSearchNoDependencies);
    expect(result.rejected.single.path, bare);
    expect(result.rejected.single.version, '3.14.0');
  });

  test('says nothing was found when no interpreter exists at all', () async {
    final discovery = PythonDiscovery(
      bundledExecutable: path.join(root.path, 'missing', 'python.exe'),
      environment: {
        'PATH': joinPath([path.join(root.path, 'empty')]),
      },
      probe: probeReturning({}),
    );

    final result = await discovery.find();

    expect(result.executable, isNull);
    expect(result.failure.code, FailureCode.pythonSearchEmpty);
    expect(result.rejected, isEmpty);
  });
}

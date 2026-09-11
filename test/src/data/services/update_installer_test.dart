// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lore_dub/src/data/services/update_installer.dart';
import 'package:lore_dub/src/domain/app_release.dart';
import 'package:path/path.dart' as path;

import '../../../support/temporary_directory.dart';

void main() {
  late Directory temp;
  late Directory updates;
  late String executable;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('lore_dub_update_');
    updates = Directory(path.join(temp.path, 'updates'));
    executable = path.join(temp.path, 'app', 'lore_dub.exe');
    await File(executable).create(recursive: true);
  });

  tearDown(() => deleteOnceReleased(temp));

  final bytes = List<int>.generate(512, (index) => index % 251);
  final installer = ReleaseInstaller(
    name: 'LoreDub-0.9.0-windows-x64-setup.exe',
    url: Uri.parse('https://example.com/LoreDub-0.9.0-windows-x64-setup.exe'),
    size: bytes.length,
  );

  test('updates only a copy the setup put in place', () async {
    final service = UpdateInstaller(root: () async => updates, executable: executable);
    expect(service.canInstall, isFalse, reason: 'a build run from its folder');

    await File(path.join(temp.path, 'app', 'unins000.exe')).create();
    expect(service.canInstall, isTrue);
  });

  test('downloads the setup and clears the ones before it', () async {
    await updates.create(recursive: true);
    final stale = File(path.join(updates.path, 'LoreDub-0.8.0-windows-x64-setup.exe'));
    await stale.writeAsString('old');
    final service = UpdateInstaller(
      client: MockClient((_) async => http.Response.bytes(bytes, 200)),
      root: () async => updates,
      executable: executable,
    );
    final progress = <double>[];

    final setup = await service.download(installer, onProgress: progress.add);

    expect(setup, path.join(updates.path, installer.name));
    expect(await File(setup).length(), bytes.length);
    expect(await stale.exists(), isFalse);
    expect(progress.last, 1);
  });

  test('hands over to the setup and closes the application', () async {
    await updates.create(recursive: true);
    final setup = path.join(updates.path, installer.name);
    String? started;
    List<String>? arguments;
    int? exitCode;
    final service = UpdateInstaller(
      root: () async => updates,
      executable: executable,
      start: (program, args) async {
        started = program;
        arguments = args;
        return _NoProcess();
      },
      exit: (code) => exitCode = code,
    );

    await service.restartInto(setup);

    expect(started, 'powershell.exe');
    expect(arguments, containsAllInOrder(['-Setup', setup, '-Executable', executable]));
    expect(arguments, contains('$pid'));
    expect(exitCode, 0);
    final script = await File(path.join(updates.path, 'apply_update.ps1')).readAsString();
    expect(script, contains('/VERYSILENT'));
    expect(script, contains('Wait-Process'));
    expect(script.codeUnits.every((unit) => unit < 128), isTrue, reason: 'no BOM, so ASCII');
  });
}

/// A process that was never started: the handover only needs it to exist.
class _NoProcess implements Process {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

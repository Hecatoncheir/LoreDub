// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/directory_removal.dart';

void main() {
  late Directory root;

  setUp(() async => root = await Directory.systemTemp.createTemp('lore-dub-removal'));
  tearDown(() async {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// A removal that fails with [code] the first [failures] times, the way a
  /// scanner holding a file does, and then lets the folder go.
  Future<void> Function(Directory) held(int code, {required int failures}) {
    var seen = 0;
    return (directory) async {
      if (seen++ < failures) {
        throw FileSystemException('held', directory.path, OSError('held', code));
      }
      await directory.delete(recursive: true);
    };
  }

  test('takes the whole directory away', () async {
    File('${root.path}/whisper-cli.exe').writeAsStringSync('binary!');

    await deleteDirectory(root);

    expect(root.existsSync(), isFalse);
  });

  test('a directory that is not there is nothing to do', () async {
    final missing = Directory('${root.path}/never-downloaded');

    await deleteDirectory(missing);

    expect(missing.existsSync(), isFalse);
  });

  test('waits out a scanner holding a file rather than reporting it', () async {
    await deleteDirectory(
      root,
      wait: Duration.zero,
      // A sharing violation twice, then the hold is over.
      remove: held(32, failures: 2),
    );

    expect(root.existsSync(), isFalse);
  });

  test('gives up on a hold that outlasts the waiting', () async {
    await expectLater(
      deleteDirectory(root, attempts: 3, wait: Duration.zero, remove: held(145, failures: 99)),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('a failure that is not a hold is reported at once', () async {
    var tries = 0;
    Future<void> refuse(Directory directory) async {
      tries++;
      throw FileSystemException('gone', directory.path, const OSError('gone', 2));
    }

    await expectLater(
      deleteDirectory(root, wait: Duration.zero, remove: refuse),
      throwsA(isA<FileSystemException>()),
    );
    expect(tries, 1, reason: 'nothing is gained by asking again');
  });
}

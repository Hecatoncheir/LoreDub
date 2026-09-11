// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/voice_bank_service.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory temp;
  late Directory root;
  late VoiceBankService service;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('lore_dub_voice_bank_');
    root = Directory(path.join(temp.path, 'voice_bank'));
    service = VoiceBankService(root: () async => root);
  });

  tearDown(() => temp.delete(recursive: true));

  Future<void> writeBank(String name, int voices) => File(path.join(root.path, name)).writeAsString(
    jsonEncode({
      'version': 1,
      'voices': [
        for (var voice = 0; voice < voices; voice++) List.filled(256, 0.1),
      ],
    }),
  );

  test('names a game by its executable, safe for any file system', () {
    expect(voiceBankFileName('Cyberpunk2077.exe'), 'cyberpunk2077.json');
    expect(voiceBankFileName('The Witcher 3!.exe'), 'the_witcher_3_.json');
    expect(voiceBankFileName(r'C:\Games\Disco Elysium.exe'), 'disco_elysium.json');
    expect(voiceBankFileName(''), 'system.json', reason: 'system audio has no game');
    expect(voiceBankFileName('..'), 'system.json');
  });

  test('makes the directory the worker writes the bank into', () async {
    final file = await service.fileFor('Game.exe');

    expect(file, path.join(root.path, 'game.json'));
    expect(root.existsSync(), isTrue);
  });

  test('counts the voices of every game together', () async {
    expect(await service.count(), 0, reason: 'nothing kept yet');

    await root.create(recursive: true);
    await writeBank('first.json', 3);
    await writeBank('second.json', 2);
    // A bank the worker was writing when it died, and a stray file.
    await File(path.join(root.path, 'broken.json')).writeAsString('{"voices": [');
    await File(path.join(root.path, 'first.tmp')).writeAsString('{}');

    expect(await service.count(), 5);
  });

  test('forgets every voice', () async {
    await root.create(recursive: true);
    await writeBank('game.json', 4);

    await service.clear();

    expect(root.existsSync(), isFalse);
    expect(await service.count(), 0);
    await service.clear();
  });
}

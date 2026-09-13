// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/character_service.dart';
import 'package:lore_dub/src/domain/character.dart';
import 'package:lore_dub/src/domain/failure.dart';
import 'package:path/path.dart' as path;

import '../../../support/temporary_directory.dart';

void main() {
  late Directory temp;
  late CharacterService service;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('lore_dub_characters_');
    service = CharacterService(root: () async => temp);
  });

  tearDown(() => deleteOnceReleased(temp));

  const guard = Character(
    id: 'a1',
    name: 'Стражник',
    vector: [0.5, -0.25],
    gender: 'male',
    voice: 'eugene',
    seconds: 3.5,
  );
  const trader = Character(id: 'b2', name: 'Торговец', vector: [0.1, 0.2]);
  const tavern = CharacterPack(id: 'p1', name: 'Таверна', characterIds: ['a1', 'b2']);

  test('starts with nobody and keeps whoever was written', () async {
    expect((await service.load()).characters, isEmpty, reason: 'no file yet');

    await service.save(const CharacterLibrary(characters: [guard, trader]));
    final kept = await service.load();

    expect(kept.characters.map((character) => character.name), ['Стражник', 'Торговец']);
    expect(kept.characters.first.voice, 'eugene');
    expect(path.basename(await service.file()), 'characters.json');
  });

  test('keeps the packs beside the cards, in the same file', () async {
    await service.save(
      const CharacterLibrary(characters: [guard, trader], packs: [tavern]),
    );
    final kept = await service.load();

    expect(kept.packs.single.name, 'Таверна');
    expect(kept.packs.single.characterIds, ['a1', 'b2']);
  });

  test('reads a file written before packs existed as a cast in none', () async {
    await File(await service.file()).writeAsString(jsonEncode(charactersToJson([guard])));

    final kept = await service.load();

    expect(kept.characters.single.name, 'Стражник');
    expect(kept.packs, isEmpty);
  });

  test('drops from a pack whoever is no longer in the cast', () async {
    await File(await service.file()).writeAsString(
      jsonEncode(characterLibraryToJson([guard], [tavern])),
    );

    final kept = await service.load();

    expect(kept.packs.single.characterIds, ['a1'], reason: 'the trader was deleted');
  });

  test('starts empty rather than refusing to open on a damaged file', () async {
    await File(await service.file()).writeAsString('{ this is not json');

    expect((await service.load()).characters, isEmpty);
  });

  test('reads back a card it exported, alone or among others', () async {
    final one = path.join(temp.path, 'guard.json');
    final many = path.join(temp.path, 'cast.json');
    await service.exportTo(one, const CharacterLibrary(characters: [guard]));
    await service.exportTo(many, const CharacterLibrary(characters: [guard, trader]));

    expect((await service.readFiles([one])).characters.single.name, 'Стражник');
    expect(
      (await service.readFiles([one, many])).characters.length,
      3,
      reason: 'the file is read as given',
    );
  });

  test('an exported pack carries the cards it holds', () async {
    final file = path.join(temp.path, 'tavern.json');
    await service.exportTo(
      file,
      const CharacterLibrary(characters: [guard, trader], packs: [tavern]),
    );

    final read = await service.readFiles([file]);

    expect(read.packs.single.name, 'Таверна');
    expect(read.characters.map((character) => character.name), ['Стражник', 'Торговец']);
  });

  test('takes a pack of five in, and gives the same five back', () async {
    // A file of the shape the application writes, five cards deep and with a
    // pack over them, so the way in and the way out are walked whole rather
    // than over the two-card libraries the tests above build by hand.
    final incoming = await service.readFiles(['test/fixtures/cast_with_pack.json']);

    expect(incoming.characters.map((character) => character.name), [
      'Кайра',
      'Невея',
      'Одрис',
      'Талрен',
      'Скарн',
    ]);
    expect(incoming.packs.single.name, 'Старый порт');
    expect(incoming.packs.single.characterIds.length, 5);
    // The fingerprints are the shape the converter's encoder makes, so the
    // worker weighs them like any other rather than passing them over.
    expect(incoming.characters.first.vector.length, 256);
    expect(
      incoming.characters.firstWhere((character) => character.id == 'skarn').voicedBy,
      'kaira',
      reason: 'a part handed across the genders survives the file',
    );

    await service.save(incoming);
    final kept = await service.load();
    expect(kept.characters.length, 5);
    expect(kept.packs.single.characterIds, incoming.packs.single.characterIds);

    // And out again: the pack is exported with the cards it holds, and reads
    // back as what went in.
    final file = path.join(temp.path, 'harbour.json');
    await service.exportTo(
      file,
      CharacterLibrary(characters: kept.characters, packs: kept.packs),
    );
    final again = await service.readFiles([file]);

    expect(again.characters.map((character) => character.id), [
      for (final character in incoming.characters) character.id,
    ]);
    expect(again.characters.first.vector, incoming.characters.first.vector);
    expect(again.characters.first.gender, 'female');
    expect(again.packs.single.id, 'old-harbour');
  });

  test('says which file held no characters', () async {
    final wrong = path.join(temp.path, 'screenshot.json');
    await File(wrong).writeAsString(jsonEncode({'settings': 'something else'}));

    expect(
      () => service.readFiles([wrong]),
      throwsA(
        isA<LoreDubFailure>()
            .having((failure) => failure.code, 'code', FailureCode.charactersImportFailed)
            .having((failure) => failure.detail, 'detail', 'screenshot.json'),
      ),
    );
  });
}

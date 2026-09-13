// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/character.dart';

void main() {
  Character character(String id, String name, {List<double>? vector}) =>
      Character(id: id, name: name, vector: vector ?? const [0.1, 0.2, 0.3]);

  test('writes a card and reads it back as it was', () {
    const guard = Character(
      id: 'a1',
      name: 'Стражник',
      vector: [0.5, -0.25],
      gender: 'male',
      voice: 'eugene',
      seconds: 3.5,
    );

    final read = charactersFromJson(jsonDecode(jsonEncode(charactersToJson([guard]))));

    expect(read.single.id, 'a1');
    expect(read.single.name, 'Стражник');
    expect(read.single.vector, [0.5, -0.25]);
    expect(read.single.gender, 'male');
    expect(read.single.voice, 'eugene');
    expect(read.single.seconds, 3.5);
  });

  test('reads a file holding one card the same way as a file holding many', () {
    final many = charactersToJson([character('a', 'Первый'), character('b', 'Второй')]);
    final one = charactersToJson([character('c', 'Третий')]);

    expect(charactersFromJson(many).length, 2);
    expect(charactersFromJson(one).single.name, 'Третий');
  });

  test('passes over what is not a usable card', () {
    expect(charactersFromJson(null), isEmpty);
    expect(charactersFromJson({'characters': 'not a list'}), isEmpty);
    expect(
      charactersFromJson({
        'characters': [
          {'id': 'a', 'name': 'Без отпечатка', 'vector': <double>[]},
          {
            'id': 'b',
            'name': '  ',
            'vector': [0.1],
          },
          {
            'id': 'c',
            'name': 'Годный',
            'vector': [0.1],
          },
        ],
      }).map((character) => character.name),
      ['Годный'],
    );
  });

  test('lays an imported card over the one it came from', () {
    final existing = [character('a', 'Стражник'), character('b', 'Торговец')];
    final incoming = [
      character('b', 'Торговец у ворот'),
      character('c', 'Кузнец'),
    ];

    final merged = mergeCharacters(existing, incoming);

    expect(merged.map((character) => character.name), [
      'Стражник',
      'Торговец у ворот',
      'Кузнец',
    ]);
  });

  test('writes a pack with the cards it holds and reads it back', () {
    const tavern = CharacterPack(id: 'p1', name: 'Таверна', characterIds: ['a', 'b']);
    final written = characterLibraryToJson([character('a', 'Первый')], [tavern]);

    final read = CharacterLibrary.fromJson(jsonDecode(jsonEncode(written)));

    expect(read.characters.single.name, 'Первый');
    expect(read.packs.single.name, 'Таверна');
    expect(
      read.packs.single.characterIds,
      ['a'],
      reason: 'b is in no card, so the pack does not name them',
    );
  });

  test('reads a file from before packs existed as a cast in none', () {
    final read = CharacterLibrary.fromJson(
      jsonDecode(jsonEncode(charactersToJson([character('a', 'Первый')]))),
    );

    expect(read.characters, hasLength(1));
    expect(read.packs, isEmpty);
  });

  test('passes over what is not a usable pack', () {
    expect(packsFromJson(null), isEmpty);
    expect(packsFromJson({'packs': 'not a list'}), isEmpty);
    expect(
      packsFromJson({
        'packs': [
          {'id': '', 'name': 'Без номера'},
          {'id': 'p2', 'name': '  '},
          {
            'id': 'p3',
            'name': 'Годный',
            'characters': ['a'],
          },
        ],
      }).map((pack) => pack.name),
      ['Годный'],
    );
  });

  test('takes a card in once however often it is dropped, and lets it out', () {
    const pack = CharacterPack(id: 'p1', name: 'Таверна');

    final filled = pack.withCharacter('a').withCharacter('b').withCharacter('a');

    expect(filled.characterIds, ['a', 'b']);
    expect(filled.holds('a'), isTrue);
    expect(filled.withoutCharacter('a').characterIds, ['b']);
    expect(
      identical(filled.withoutCharacter('missing'), filled),
      isTrue,
      reason: 'nothing to take out',
    );
  });

  test('lays an imported pack over the one it came from', () {
    const existing = [
      CharacterPack(id: 'p1', name: 'Таверна', characterIds: ['a']),
      CharacterPack(id: 'p2', name: 'Пролог'),
    ];
    const incoming = [
      CharacterPack(id: 'p2', name: 'Пролог, глава 1'),
      CharacterPack(id: 'p3', name: 'Стража'),
    ];

    expect(mergePacks(existing, incoming).map((pack) => pack.name), [
      'Таверна',
      'Пролог, глава 1',
      'Стража',
    ]);
  });

  test('cleans a pack of ids no card answers to, keeping a name once', () {
    const packs = [
      CharacterPack(id: 'p1', name: 'Таверна', characterIds: ['a', 'gone', 'a', 'b']),
    ];

    final pruned = prunePacks(packs, [character('a', 'Первый'), character('b', 'Второй')]);

    expect(pruned.single.characterIds, ['a', 'b']);
  });

  test('keeps the card a character is read by', () {
    const guard = Character(
      id: 'a1',
      name: 'Стражник',
      vector: [0.5],
      voicedBy: 'b2',
    );

    final read = charactersFromJson(jsonDecode(jsonEncode(charactersToJson([guard]))));

    expect(read.single.voicedBy, 'b2');
    expect(read.single.copyWith(clearVoicedBy: true).voicedBy, isNull);
    expect(read.single.copyWith(voicedBy: 'c3').voicedBy, 'c3');
  });

  test('a card written before substitutions existed is read by nobody', () {
    final read = charactersFromJson({
      'characters': [
        {
          'id': 'a1',
          'name': 'Стражник',
          'vector': [0.5],
        },
      ],
    });

    expect(read.single.voicedBy, isNull);
  });
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/character.dart';
import 'package:lore_dub/src/domain/speaker_map.dart';

void main() {
  test('writes whose voice reads whom and reads it back', () {
    const replacements = {'timbre:2': 'a1', 'character:b7': 'c3'};

    final read = speakerMapFromJson(jsonDecode(jsonEncode(speakerMapToJson(replacements))));

    expect(read, replacements);
  });

  test('passes over what cannot be a replacement', () {
    expect(speakerMapFromJson(null), isEmpty);
    expect(speakerMapFromJson({'replacements': 'not a map'}), isEmpty);
    expect(
      speakerMapFromJson({
        'replacements': {
          // A voice nobody could place has no identity to replace.
          'voice:eugene': 'a1',
          'timbre:0': '',
          'timbre:1': 7,
          'timbre:2': 'a1',
        },
      }),
      {'timbre:2': 'a1'},
    );
  });

  test('names the character a key belongs to, and only a card has one', () {
    expect(characterOfSpeaker('character:a1'), 'a1');
    expect(characterOfSpeaker('timbre:3'), isNull);
    expect(characterOfSpeaker('voice:eugene'), isNull);
  });

  test('only a voice with an identity can be replaced', () {
    expect(isReplaceableSpeaker('character:a1'), isTrue);
    expect(isReplaceableSpeaker('timbre:3'), isTrue);
    expect(isReplaceableSpeaker('voice:eugene'), isFalse);
  });

  test('assigns a character, replaces the assignment and takes it back', () {
    const none = <String, String>{};

    final assigned = withReplacement(none, 'timbre:2', 'a1');
    final moved = withReplacement(assigned, 'timbre:2', 'b2');
    final undone = withReplacement(moved, 'timbre:2', null);

    expect(assigned, {'timbre:2': 'a1'});
    expect(moved, {'timbre:2': 'b2'});
    expect(undone, isEmpty);
    expect(none, isEmpty, reason: 'the map it came from is left alone');
  });

  group('who reads a voice', () {
    const guard = Character(id: 'a1', name: 'Стражник', vector: [0.2], voicedBy: 'b2');
    const smith = Character(id: 'b2', name: 'Кузнец', vector: [0.3], voicedBy: 'c3');
    const bard = Character(id: 'c3', name: 'Бард', vector: [0.4]);
    const cast = [guard, smith, bard];

    test('reads a voice as itself when nobody was named', () {
      expect(readerOfSpeaker('timbre:2', const {}, cast), isNull);
      expect(readerOfSpeaker('character:c3', const {}, cast), isNull);
    });

    test('follows the card a character carries into every game', () {
      expect(readerOfSpeaker('character:a1', const {}, cast), 'b2');
    });

    test('follows the card one hop and no further', () {
      expect(
        readerOfSpeaker('character:a1', const {}, cast),
        'b2',
        reason: 'the smith is read by the bard, but the guard is not',
      );
    });

    test('lets this game override the card', () {
      expect(readerOfSpeaker('character:a1', const {'character:a1': 'c3'}, cast), 'c3');
    });

    test('a voice the bank founded has no card to carry anything', () {
      expect(readerOfSpeaker('timbre:0', const {'timbre:0': 'a1'}, cast), 'a1');
      expect(readerOfSpeaker('timbre:0', const {}, cast), isNull);
    });

    test('a card that is gone reads nobody', () {
      expect(readerOfSpeaker('character:a1', const {}, const [bard]), isNull);
    });
  });
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/character.dart';
import 'package:lore_dub/src/domain/speaker_keys.dart';

void main() {
  test('names the character a key belongs to, and only a card has one', () {
    expect(characterOfSpeaker('character:a1'), 'a1');
    expect(characterOfSpeaker('timbre:3'), isNull);
    expect(characterOfSpeaker('voice:eugene'), isNull);
  });

  group('who reads a voice', () {
    const guard = Character(id: 'a1', name: 'Стражник', vector: [0.2], voicedBy: 'b2');
    const smith = Character(id: 'b2', name: 'Кузнец', vector: [0.3], voicedBy: 'c3');
    const bard = Character(id: 'c3', name: 'Бард', vector: [0.4]);
    const cast = [guard, smith, bard];

    test('reads a voice as itself when nobody was given it', () {
      expect(readerOfSpeaker('character:c3', cast), isNull);
    });

    test('follows the card the graph drew the line to', () {
      expect(readerOfSpeaker('character:a1', cast), 'b2');
    });

    test('follows the card one hop and no further', () {
      expect(
        readerOfSpeaker('character:a1', cast),
        'b2',
        reason: 'the smith is read by the bard, but the guard is not',
      );
    });

    test('a voice the bank founded has no card to carry anything', () {
      expect(readerOfSpeaker('timbre:0', cast), isNull);
      expect(readerOfSpeaker('voice:eugene', cast), isNull);
    });

    test('a card that is gone reads nobody', () {
      expect(readerOfSpeaker('character:a1', const [bard]), isNull);
    });
  });
}

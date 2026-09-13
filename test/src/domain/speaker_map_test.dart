// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
}

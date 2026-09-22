// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/glossary.dart';

void main() {
  test('files every shared case under the key the worker files it under', () {
    // The worker's Glossary._key reads the same file in its own tests, which
    // is what keeps the two rules one.
    final fixture = jsonDecode(
      File('test/fixtures/glossary_keys.json').readAsStringSync(),
    ) as Map<String, Object?>;
    for (final entry in fixture['cases']! as List<Object?>) {
      final (:source, :key) = switch (entry) {
        {'source': final String source, 'key': final String key} => (source: source, key: key),
        _ => throw StateError('a case is a source and a key'),
      };
      expect(normalizedGlossaryKey(source), key, reason: source);
    }
  });

  const fire = GlossaryEntry(
    kind: GlossaryKind.phrase,
    source: 'Fire in the hole!',
    reading: 'Ложись!',
  );
  const megaton = GlossaryEntry(
    kind: GlossaryKind.name,
    source: 'Megaton',
    reading: 'Мегатон',
  );
  const vault = GlossaryEntry(
    kind: GlossaryKind.word,
    source: 'Хранилище',
    reading: 'Убежище',
  );

  Glossary written() => const Glossary().keeping(fire).keeping(megaton).keeping(vault);

  test('names an entry by its kind as well as its source', () {
    const phrase = GlossaryEntry(kind: GlossaryKind.phrase, source: 'Vault', reading: 'a');
    const name = GlossaryEntry(kind: GlossaryKind.name, source: 'vault', reading: 'b');

    // The same word written as two kinds is two entries, and a pack that
    // holds one must not be read as holding the other.
    expect(phrase.key, name.key);
    expect(phrase.packKey, isNot(name.packKey));
  });

  test('files a line under one key whatever it ends with', () {
    // Whisper hears the same shout with a full stop as often as with an
    // exclamation, and an entry written under one must not miss the other.
    expect(
      normalizedGlossaryKey('Fire in the hole!'),
      normalizedGlossaryKey('fire in the hole.'),
    );
    expect(normalizedGlossaryKey('  Watch  your   six?  '), 'watch your six');
    expect(normalizedGlossaryKey('«Rapture»'), 'rapture');
    // A source that is punctuation and nothing else keeps what it had rather
    // than filing every such entry under the empty string.
    expect(normalizedGlossaryKey('...'), '...');
  });

  group('a line passed over', () {
    const silenced = GlossaryEntry(
      kind: GlossaryKind.phrase,
      source: 'Reloading!',
      reading: '',
      silent: true,
    );

    test('needs no reading, which is the whole of it', () {
      expect(silenced.isEmpty, isFalse);
      expect(
        const GlossaryEntry(kind: GlossaryKind.phrase, source: 'Reloading!', reading: ''),
        predicate<GlossaryEntry>((entry) => entry.isEmpty),
        reason: 'an ordinary entry still needs both halves',
      );
    });

    test('is a phrase and nothing else', () {
      // A name and a word stand inside a line rather than being one, so
      // there is nothing about them to pass over.
      expect(silenced.silences, isTrue);
      expect(megaton.silences, isFalse);
      expect(vault.silences, isFalse);
      expect(
        const GlossaryEntry(
          kind: GlossaryKind.name,
          source: 'Megaton',
          reading: '',
          silent: true,
        ).isEmpty,
        isTrue,
      );
    });

    test('survives a write and a read', () {
      final read = Glossary.fromJson(const Glossary(entries: [silenced]).toJson());

      expect(read.entries.single.silent, isTrue);
      expect(read.entries.single, silenced);
    });

    test('is written down only where it is set', () {
      expect(fire.toJson().containsKey('silent'), isFalse);
      expect(silenced.toJson()['silent'], isTrue);
    });
  });

  group('packs', () {
    test('reads everything written down while no pack is switched on', () {
      final glossary = written().keepingPack(
        GlossaryPack(id: 'p1', name: 'Fallout', entryKeys: [megaton.packKey]),
      );

      expect(glossary.inUse.entries, [fire, megaton, vault]);
    });

    test('reads only what the switched-on packs hold', () {
      final glossary = written()
          .keepingPack(GlossaryPack(id: 'p1', name: 'Fallout', entryKeys: [megaton.packKey]))
          .keepingPack(GlossaryPack(id: 'p2', name: 'Общее', entryKeys: [fire.packKey]))
          .activating('p1', active: true);

      expect(glossary.inUse.entries, [megaton], reason: 'the rest is not in an active pack');

      // Several may be on at once, and what they hold adds together.
      final both = glossary.activating('p2', active: true);
      expect(both.inUse.entries, [fire, megaton]);
    });

    test('hands the worker no packs, only the entries it should apply', () {
      final glossary = written()
          .keepingPack(GlossaryPack(id: 'p1', name: 'Fallout', entryKeys: [megaton.packKey]))
          .activating('p1', active: true);

      expect(glossary.inUse.packs, isEmpty);
    });

    test('reads nothing from a pack switched on with nothing in it', () {
      // Not everything: the screen says the dubbing reads only the packs
      // switched on, and opening the whole glossary would bring every other
      // game's names back with it.
      final glossary = written()
          .keepingPack(const GlossaryPack(id: 'p1', name: 'Пустой'))
          .activating('p1', active: true);

      expect(glossary.inUse.entries, isEmpty);
    });

    test('narrows a pack to the kinds the scheme lets it apply, and no other pack', () {
      final glossary = written()
          .keepingPack(
            GlossaryPack(id: 'p1', name: 'Fallout', entryKeys: [megaton.packKey, vault.packKey]),
          )
          .keepingPack(GlossaryPack(id: 'p2', name: 'Общее', entryKeys: [fire.packKey]))
          .activating('p1', active: true)
          .activating('p2', active: true);

      expect(
        glossary.inUseWithin({
          'p1': {GlossaryKind.word},
        }).entries,
        [fire, vault],
        reason: 'the pack the scheme does not draw applies whole',
      );
      expect(
        glossary.inUseWithin({
          'p1': <GlossaryKind>{},
          'p2': {GlossaryKind.name},
        }).entries,
        isEmpty,
        reason: 'drawn where none of its kinds can be met, a pack applies nothing',
      );
      expect(
        written().inUseWithin({
          'p1': <GlossaryKind>{},
        }).entries,
        [fire, megaton, vault],
        reason: 'a pack the glossary no longer has draws nothing, and none is switched on',
      );
    });

    test('reads nothing while the scheme draws packs and none of them is switched on', () {
      final glossary = written().keepingPack(
        GlossaryPack(id: 'p1', name: 'Fallout', entryKeys: [megaton.packKey]),
      );

      expect(
        glossary.inUseWithin({
          'p1': {GlossaryKind.name, GlossaryKind.word},
        }).entries,
        isEmpty,
        reason: 'the last pack switched off on the scheme must not open the whole glossary',
      );
      expect(
        glossary.inUse.entries,
        [fire, megaton, vault],
        reason: 'what the scheme does not draw for -- the screen -- still reads it whole',
      );
    });

    test('counts what a pack holds of some kinds', () {
      final pack = GlossaryPack(
        id: 'p1',
        name: 'Fallout',
        entryKeys: [megaton.packKey, vault.packKey, fire.packKey],
      );

      expect(pack.countOf({GlossaryKind.name, GlossaryKind.word}), 2);
      expect(pack.countOf({GlossaryKind.phrase}), 1);
      expect(GlossaryKind.ofPackKey(fire.packKey), GlossaryKind.phrase);
      expect(GlossaryKind.ofPackKey('rumour:who knows'), isNull);
    });

    test('tells one reach from another by what it lets through', () {
      expect(
        sameGlossaryReach(
          {
            'p1': {GlossaryKind.name, GlossaryKind.word},
          },
          {
            'p1': {GlossaryKind.word, GlossaryKind.name},
          },
        ),
        isTrue,
      );
      expect(
        sameGlossaryReach(
          {
            'p1': {GlossaryKind.word},
          },
          {
            'p1': {GlossaryKind.phrase},
          },
        ),
        isFalse,
      );
      expect(sameGlossaryReach(const {}, {'p1': <GlossaryKind>{}}), isFalse);
    });

    test('moves an entry when it is dragged from one pack to another', () {
      final glossary = written()
          .keepingPack(GlossaryPack(id: 'p1', name: 'One', entryKeys: [megaton.packKey]))
          .keepingPack(const GlossaryPack(id: 'p2', name: 'Two'))
          .filing(megaton, into: 'p2', from: 'p1');

      expect(glossary.packWithId('p1')!.entryKeys, isEmpty);
      expect(glossary.packWithId('p2')!.entryKeys, [megaton.packKey]);
    });

    test('leaves the entries where a pack is deleted', () {
      final glossary = written()
          .keepingPack(GlossaryPack(id: 'p1', name: 'One', entryKeys: [megaton.packKey]))
          .withoutPack('p1');

      expect(glossary.packs, isEmpty);
      expect(glossary.entries, contains(megaton));
    });

    test('takes a deleted entry out of every pack that named it', () {
      final glossary = written()
          .keepingPack(GlossaryPack(id: 'p1', name: 'One', entryKeys: [megaton.packKey]))
          .keepingPack(GlossaryPack(id: 'p2', name: 'Two', entryKeys: [megaton.packKey]))
          .without(GlossaryKind.name, 'megaton');

      expect(glossary.entries, isNot(contains(megaton)));
      expect(glossary.packs.every((pack) => pack.entryKeys.isEmpty), isTrue);
    });

    test('writes a pack out with the entries it names, switched off', () {
      final glossary = written()
          .keepingPack(
            GlossaryPack(id: 'p1', name: 'Fallout', entryKeys: [megaton.packKey, vault.packKey]),
          )
          .activating('p1', active: true);

      final only = glossary.onlyPack('p1');

      expect(only.entries, [megaton, vault]);
      expect(only.packs.single.name, 'Fallout');
      expect(
        only.packs.single.active,
        isFalse,
        reason: 'a pack that arrived already replacing the glossary would be a surprise',
      );
    });
  });

  group('the file', () {
    test('reads a file written before packs existed', () {
      final read = Glossary.fromJson(const {
        'version': 1,
        'entries': [
          {'kind': 'phrase', 'source': 'Fire in the hole!', 'reading': 'Ложись!'},
        ],
      });

      expect(read.entries, [fire]);
      expect(read.packs, isEmpty);
    });

    test('carries the packs through a write and a read', () {
      final glossary = written()
          .keepingPack(GlossaryPack(id: 'p1', name: 'Fallout', entryKeys: [megaton.packKey]))
          .activating('p1', active: true);

      final read = Glossary.fromJson(glossary.toJson());

      expect(read.entries, glossary.entries);
      expect(read.packs.single.name, 'Fallout');
      expect(read.packs.single.entryKeys, [megaton.packKey]);
      expect(read.packs.single.active, isTrue);
    });

    test('drops from a pack what no entry answers to', () {
      final read = Glossary.fromJson(const {
        'version': 2,
        'entries': [
          {'kind': 'name', 'source': 'Megaton', 'reading': 'Мегатон'},
        ],
        'packs': [
          {
            'id': 'p1',
            'name': 'Fallout',
            'entries': ['name:megaton', 'phrase:gone'],
            'active': true,
          },
        ],
      });

      expect(read.packs.single.entryKeys, ['name:megaton']);
    });

    test('passes over a pack with no name to answer to', () {
      final read = Glossary.fromJson(const {
        'version': 2,
        'entries': [
          {'kind': 'name', 'source': 'Megaton', 'reading': 'Мегатон'},
        ],
        'packs': [
          {'id': 'p1', 'entries': <String>[]},
        ],
      });

      expect(read.packs, isEmpty);
    });
  });
}

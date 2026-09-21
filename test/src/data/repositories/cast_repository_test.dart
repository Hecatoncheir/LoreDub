// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/repositories/cast_repository.dart';
import 'package:lore_dub/src/domain/character.dart';

import '../../../support/memory_cast.dart';

void main() {
  const guard = Character(id: 'a1', name: 'Стражник', vector: [0.2]);
  const smith = Character(id: 'b2', name: 'Кузнец', vector: [0.3]);

  late MemoryCharacters files;
  late TellingEngine engine;
  late CastRepository cast;

  setUp(() {
    files = MemoryCharacters();
    engine = TellingEngine();
    cast = CastRepository(engine, files);
  });

  test('a listener has the change before the write returns', () async {
    // Delivered as it is published, not a microtask later. A screen that
    // writes here also listens here: with the usual delivery its own echo
    // arrived after it had moved on and put the older list back.
    final heard = <int>[];
    final listening = cast.changes.listen((library) => heard.add(library.characters.length));
    addTearDown(listening.cancel);

    final writing = cast.save(const CharacterLibrary(characters: [guard]));

    expect(heard, [1], reason: 'told before the disk is');
    expect(cast.cast.single.id, 'a1');
    await writing;
    expect(files.stored.characters.single.id, 'a1', reason: 'and written after');
  });

  test('writes build on each other rather than on what the last one saw', () async {
    // What two screens working on one cast does: each change is made from
    // what the repository holds now, and the one before it is not undone.
    await cast.save(const CharacterLibrary(characters: [guard]));
    await cast.save(CharacterLibrary(characters: [...cast.cast, smith]));

    expect(cast.cast.map((one) => one.id), ['a1', 'b2']);
  });

  test('a card given away is written and the running session is told', () async {
    await cast.save(const CharacterLibrary(characters: [guard, smith]));

    await cast.voiceAs('a1', 'b2');

    expect(cast.cast.firstWhere((one) => one.id == 'a1').voicedBy, 'b2');
    expect(files.stored.characters.first.voicedBy, 'b2', reason: 'kept for the next session');
    expect(engine.told, [('a1', 'b2')], reason: 'and the session already running');
  });

  test('a card cannot be given its own voice, which would say nothing', () async {
    await cast.save(const CharacterLibrary(characters: [guard]));
    files.stored = CharacterLibrary.empty;

    await cast.voiceAs('a1', 'a1');

    expect(files.stored.characters, isEmpty, reason: 'nothing written');
    expect(engine.told, isEmpty);
  });
}

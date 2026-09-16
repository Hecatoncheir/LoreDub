// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/glossary_catalog.dart';
import 'package:lore_dub/src/data/services/glossary_service.dart';
import 'package:lore_dub/src/domain/failure.dart';
import 'package:lore_dub/src/domain/glossary.dart';
import 'package:path/path.dart' as path;

import '../../../support/temporary_directory.dart';

void main() {
  late Directory temp;
  late GlossaryService service;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('lore_dub_glossary_');
    service = GlossaryService(root: () async => temp);
  });

  tearDown(() => deleteOnceReleased(temp));

  const grenade = GlossaryEntry(
    kind: GlossaryKind.phrase,
    source: 'Fire in the hole!',
    reading: 'Ложись!',
  );
  const rapture = GlossaryEntry(
    kind: GlossaryKind.name,
    source: 'Rapture',
    reading: 'Восторг',
  );

  test('opens empty before anything is written down', () async {
    expect((await service.load()).isEmpty, isTrue);
  });

  test('keeps what was written and reads it back', () async {
    await service.save(const Glossary(entries: [grenade, rapture]));

    final stored = await service.load();
    expect(stored.entries, [grenade, rapture]);
    expect(stored.of(GlossaryKind.name).single, rapture);
  });

  test('opens empty on a file that is not a glossary', () async {
    await File(path.join(temp.path, 'glossary.json')).writeAsString('{ not json');
    expect((await service.load()).isEmpty, isTrue);
  });

  test('drops an entry with nothing on one side of it', () async {
    await File(path.join(temp.path, 'glossary.json')).writeAsString(
      '{"version":1,"entries":['
      '{"kind":"name","source":"Rapture","reading":"Восторг"},'
      '{"kind":"name","source":"  ","reading":"nobody"},'
      '{"kind":"name","source":"Megaton","reading":""}]}',
    );
    expect((await service.load()).entries, [rapture]);
  });

  test('writes a file an import reads back', () async {
    final carried = path.join(temp.path, 'carried.json');
    await service.exportTo(carried, const Glossary(entries: [grenade, rapture]));

    expect((await service.readFiles([carried])).entries, [grenade, rapture]);
  });

  group('the pack LoreDub brings', () {
    test('lays both packs over an empty glossary, switched off', () async {
      final offered = await service.withBuiltIn(Glossary.empty, builtInGlossary());

      expect(
        offered.packs.map((pack) => pack.id),
        [builtInGlossaryPackId, builtInQuotesPackId],
      );
      expect(offered.packs.every((pack) => !pack.active), isTrue);
      expect(offered.entries, isNotEmpty);
      expect(
        offered.packs.fold(0, (count, pack) => count + pack.entryKeys.length),
        offered.entries.length,
        reason: 'every entry it brings is in one of the packs it brings',
      );
    });

    test('offers it once, so a pack thrown away stays away', () async {
      final first = await service.withBuiltIn(Glossary.empty, builtInGlossary());
      await service.save(first.withoutPack(builtInGlossaryPackId));

      final again = await service.withBuiltIn(await service.load(), builtInGlossary());

      expect(again.packWithId(builtInGlossaryPackId), isNull);
    });

    test('leaves an entry the player wrote under the same line', () async {
      const mine = GlossaryEntry(
        kind: GlossaryKind.phrase,
        source: 'Fire in the hole!',
        reading: 'Граната!',
      );

      final offered = await service.withBuiltIn(const Glossary(entries: [mine]), builtInGlossary());

      expect(offered.match(GlossaryKind.phrase, 'Fire in the hole!')?.reading, 'Граната!');
    });

    test('keeps an apostrophe, which the key is matched on', () {
      // Whisper writes "You're" and "'em"; an entry filed without them would
      // never answer the line it was written for.
      final sources = builtInGlossary().entries.map((entry) => entry.source).toList();

      expect(sources, contains("We're taking fire!"));
      expect(sources, contains("Light 'em up."));
      expect(sources, contains("Hey, you. You're finally awake."));
    });

    test('brings phrases only, and every one of them readable', () {
      final glossary = builtInGlossary();

      expect(glossary.entries.every((entry) => entry.kind == GlossaryKind.phrase), isTrue);
      expect(glossary.entries.every((entry) => !entry.isEmpty), isTrue);
      // Two entries filed under one key would leave the pack naming a line
      // that is no longer there.
      final keys = glossary.entries.map((entry) => entry.packKey).toSet();
      expect(keys, hasLength(glossary.entries.length));
    });
  });

  test('carries a pack and its entries between machines', () async {
    final shelf = const Glossary(entries: [grenade, rapture]).keepingPack(
      GlossaryPack(id: 'p1', name: 'BioShock', entryKeys: [rapture.packKey]),
    );
    final carried = path.join(temp.path, 'pack.json');

    // Only the pack and what it names, so the file is worth passing on.
    await service.exportTo(carried, shelf.onlyPack('p1'));
    final read = await service.readFiles([carried]);

    expect(read.entries, [rapture]);
    expect(read.packs.single.name, 'BioShock');
    expect(read.packs.single.entryKeys, [rapture.packKey]);
  });

  test('hands a session only what the switched-on packs hold', () async {
    final shelf = const Glossary(entries: [grenade, rapture])
        .keepingPack(GlossaryPack(id: 'p1', name: 'BioShock', entryKeys: [rapture.packKey]))
        .activating('p1', active: true);
    await service.save(shelf);

    final handed = Glossary.fromJson(
      jsonDecode(await File(await service.sessionFile()).readAsString()),
    );

    expect(handed.entries, [rapture], reason: 'the file a worker reads holds no more than this');
    expect(await service.file(), isNot(await service.sessionFile()));
    expect((await service.load()).entries, [grenade, rapture], reason: 'the shelf keeps both');
  });

  test('merges several files, the last word winning', () async {
    const louder = GlossaryEntry(
      kind: GlossaryKind.phrase,
      source: 'Fire in the hole!',
      reading: 'Граната!',
    );
    final first = path.join(temp.path, 'first.json');
    final second = path.join(temp.path, 'second.json');
    await service.exportTo(first, const Glossary(entries: [grenade, rapture]));
    await service.exportTo(second, const Glossary(entries: [louder]));

    expect((await service.readFiles([first, second])).entries, [louder, rapture]);
  });

  test('says which file held no glossary rather than importing nothing', () async {
    final empty = path.join(temp.path, 'empty.json');
    await File(empty).writeAsString('{"version":1,"entries":[]}');

    await expectLater(
      service.readFiles([empty]),
      throwsA(
        isA<LoreDubFailure>()
            .having((failure) => failure.code, 'code', FailureCode.glossaryImportFailed)
            .having((failure) => failure.detail, 'detail', 'empty.json'),
      ),
    );
  });

  test('a source written twice replaces the first and keeps its place', () {
    const louder = GlossaryEntry(
      kind: GlossaryKind.phrase,
      // The same entry however it was typed: case and spacing are not what
      // an entry is filed under.
      source: 'fire   in the hole!',
      reading: 'Граната!',
    );
    final written = const Glossary(entries: [grenade, rapture]).keeping(louder);

    expect(written.entries, [louder, rapture]);
    expect(written.match(GlossaryKind.phrase, 'FIRE IN THE HOLE!')?.reading, 'Граната!');
  });

  test('keeps a word of the dubbing beside the two matched on English', () async {
    const spoken = GlossaryEntry(
      kind: GlossaryKind.word,
      source: 'Хранилище',
      reading: 'Убежище',
    );
    await service.save(const Glossary(entries: [grenade, rapture, spoken]));

    final stored = await service.load();
    expect(stored.of(GlossaryKind.word).single, spoken);
    expect(stored.of(GlossaryKind.name).single, rapture);
    expect(stored.match(GlossaryKind.word, 'хранилище')?.reading, 'Убежище');
  });

  test('a name and a phrase of the same spelling are two entries', () {
    const spoken = GlossaryEntry(
      kind: GlossaryKind.phrase,
      source: 'Rapture',
      reading: 'Восторг, город на дне',
    );
    final written = const Glossary(entries: [rapture]).keeping(spoken);

    expect(written.entries.length, 2);
    expect(written.match(GlossaryKind.name, 'rapture')?.reading, 'Восторг');
  });

  test('an entry taken out leaves the rest where they were', () {
    final written = const Glossary(
      entries: [grenade, rapture],
    ).without(GlossaryKind.name, 'RAPTURE');

    expect(written.entries, [grenade]);
  });
}

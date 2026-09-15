// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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

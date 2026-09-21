// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/glossary_service.dart';
import 'package:lore_dub/src/data/services/json_file_store.dart';
import 'package:lore_dub/src/domain/failure.dart';
import 'package:lore_dub/src/domain/glossary.dart';
import 'package:lore_dub/src/data/services/glossary_catalog.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory temp;
  late JsonFileStore<List<String>> store;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('lore_dub_store_');
    store = JsonFileStore(
      fileName: 'names.json',
      // A cast the way every `fromJson` makes one: JSON of the wrong shape
      // throws a TypeError rather than a FormatException.
      decode: (json) => [
        for (final name in (json! as Map<String, Object?>)['names']! as List) name as String,
      ],
      encode: (names) => {'names': names},
      empty: const [],
      saveFailure: FailureCode.charactersSaveFailed,
      root: () async => temp,
    );
  });

  tearDown(() => temp.delete(recursive: true));

  Future<void> write(String name, String text) =>
      File(path.join(temp.path, name)).writeAsString(text);

  test('reads a missing file as empty', () async {
    expect(await store.load(), isEmpty);
  });

  test('reads JSON of the wrong shape as empty, as it does text that is not JSON', () async {
    await write('names.json', '{"names": [1, 2]}');
    expect(await store.load(), isEmpty);

    await write('names.json', '[]');
    expect(await store.load(), isEmpty);

    await write('names.json', 'not json');
    expect(await store.load(), isEmpty);
  });

  test('writes one value at a time, the last one asked for landing last', () async {
    // The canvas saves on every drop without waiting; through one temporary
    // file the writes renamed over each other.
    await Future.wait([
      for (var index = 0; index < 20; index++) store.save(['name $index']),
    ]);

    expect(await store.load(), ['name 19']);
    expect(File(path.join(temp.path, 'names.json.tmp')).existsSync(), isFalse);
  });

  test('a write that fails is said, and the next one still lands', () async {
    // A directory where the temporary file would go refuses the write.
    final blocker = Directory(path.join(temp.path, 'names.json.tmp'))..createSync();

    await expectLater(
      store.save(['refused']),
      throwsA(
        isA<LoreDubFailure>().having((f) => f.code, 'code', FailureCode.charactersSaveFailed),
      ),
    );
    blocker.deleteSync();
    await store.save(['kept']);

    expect(await store.load(), ['kept']);
  });

  test('an import names a file of the wrong shape rather than reading it as empty', () async {
    await write('good.json', '{"names": ["Lydia"]}');
    await write('odd.json', '{"names": [7]}');

    await expectLater(
      importJsonFiles(
        [path.join(temp.path, 'good.json'), path.join(temp.path, 'odd.json')],
        decode: (json) => [
          for (final name in (json! as Map<String, Object?>)['names']! as List) name as String,
        ],
        holdsNothing: (names) => names.isEmpty,
        failure: FailureCode.charactersImportFailed,
      ),
      throwsA(isA<LoreDubFailure>().having((f) => f.detail, 'detail', 'odd.json')),
    );
  });

  test('a built-in pack whose save failed is offered again, not marked as offered', () async {
    final glossary = GlossaryService(root: () async => temp);
    final blocker = Directory(path.join(temp.path, 'glossary.json.tmp'))..createSync();

    await expectLater(
      glossary.withBuiltIn(Glossary.empty, builtInGlossary()),
      throwsA(isA<LoreDubFailure>()),
    );
    expect(File(path.join(temp.path, 'glossary.builtin')).existsSync(), isFalse);

    blocker.deleteSync();
    final offered = await glossary.withBuiltIn(Glossary.empty, builtInGlossary());
    expect(offered.packWithId(builtInGlossaryPackId), isNotNull);
    expect((await glossary.load()).packWithId(builtInGlossaryPackId), isNotNull);
  });
}

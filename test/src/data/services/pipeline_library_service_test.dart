// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/pipeline_library_service.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/pipeline_graph.dart';
import 'package:lore_dub/src/domain/saved_pipeline.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('loredub-schemes');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  PipelineLibraryService service() => PipelineLibraryService(root: () async => root);

  test('keeps a scheme whole and reads it back', () async {
    final library = PipelineLibrary(
      pipelines: [
        SavedPipeline(
          id: 's1',
          name: 'Вечер в таверне',
          captureMode: CaptureMode.ocr,
          castRouted: false,
          layout: PipelineLayout.drawing(['guard']),
          readers: const {'guard': 'smith', 'smith': null},
        ),
      ],
    );

    await service().save(library);
    final read = await service().load();

    final scheme = read.pipelines.single;
    expect(scheme.name, 'Вечер в таверне');
    expect(scheme.captureMode, CaptureMode.ocr);
    expect(scheme.castRouted, isFalse);
    expect(scheme.layout.characters, ['guard']);
    expect(scheme.readers, {'guard': 'smith', 'smith': null});
  });

  test('reads a file somebody else\'s editor put a byte order mark on', () async {
    // Windows editors write UTF-8 with a mark in front, and jsonDecode reads
    // that mark as a character. A shelf lost to it would be lost in silence.
    final file = File(path.join(root.path, 'pipelines.json'));
    await file.writeAsString(
      '﻿${jsonEncode(const PipelineLibrary(
        pipelines: [SavedPipeline(id: 's1', name: 'Схема')],
      ).toJson())}',
    );

    final read = await service().load();

    expect(read.pipelines.single.name, 'Схема');
  });

  test('reads schemes out of the files the player chose', () async {
    final source = File(path.join(root.path, 'shared.json'));
    await source.writeAsString(
      jsonEncode(
        const PipelineLibrary(
          pipelines: [
            SavedPipeline(id: 'a', name: 'Одна'),
            SavedPipeline(id: 'b', name: 'Другая'),
          ],
        ).toJson(),
      ),
    );

    expect(
      [
        for (final scheme in await service().readFiles([source.path])) scheme.name,
      ],
      ['Одна', 'Другая'],
    );
  });

  test('says which file held no scheme', () async {
    final source = File(path.join(root.path, 'wrong.json'));
    await source.writeAsString('{"characters": []}');

    await expectLater(service().readFiles([source.path]), throwsA(isA<Object>()));
  });

  test('an empty shelf is what a machine with no file has', () async {
    expect((await service().load()).pipelines, isEmpty);
  });
}

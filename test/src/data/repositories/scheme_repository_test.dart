// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/repositories/scheme_repository.dart';
import 'package:lore_dub/src/data/services/pipeline_graph_service.dart';
import 'package:lore_dub/src/data/services/pipeline_library_service.dart';
import 'package:lore_dub/src/domain/pipeline_graph.dart';
import 'package:lore_dub/src/domain/saved_pipeline.dart';
import 'package:path/path.dart' as path;

/// The canvases' own files: each keeps its arrangement and its shelf apart
/// from the other's, Эфир's under the names it had while it was the only one.
void main() {
  late Directory root;
  late SchemeRepository schemes;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('loredub-canvases');
    Future<Directory> at() async => root;
    schemes = SchemeRepository(
      layout: PipelineGraphService(root: at),
      shelf: PipelineLibraryService(root: at),
      screenLayout: PipelineGraphService(root: at, scheme: PipelineScheme.screen),
      screenShelf: PipelineLibraryService(root: at, scheme: PipelineScheme.screen),
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('opens each canvas on its own arrangement before anything is kept', () async {
    expect((await schemes.loadLayout()).positions, PipelineLayout.standardPositions);
    expect(
      (await schemes.loadLayout(scheme: PipelineScheme.screen)).positions,
      PipelineLayout.screenPositions,
    );
  });

  test('keeps each canvas\'s arrangement in a file of its own', () async {
    final live = PipelineLayout.standard.withPosition(
      PipelineNodeIds.voice,
      const GraphPoint(1, 2),
    );
    final screen = PipelineLayout.screenStandard.withPosition(
      PipelineNodeIds.detection,
      const GraphPoint(3, 4),
    );

    await schemes.saveLayout(live);
    await schemes.saveLayout(screen, scheme: PipelineScheme.screen);

    expect(await File(path.join(root.path, 'pipeline_graph.json')).exists(), isTrue);
    expect(await File(path.join(root.path, 'screen_graph.json')).exists(), isTrue);
    expect(
      (await schemes.loadLayout()).positions[PipelineNodeIds.voice],
      const GraphPoint(1, 2),
    );
    expect(
      (await schemes.loadLayout(scheme: PipelineScheme.screen))
          .positions[PipelineNodeIds.detection],
      const GraphPoint(3, 4),
    );
  });

  test('keeps each canvas\'s shelf apart, and writes out and reads in its own', () async {
    const live = SavedPipeline(id: 'live', name: 'Таверна');
    const screen = SavedPipeline(
      id: 'screen',
      name: 'Субтитры',
      scheme: PipelineScheme.screen,
      layout: PipelineLayout.screenStandard,
    );
    await schemes.saveSchemes(const PipelineLibrary(pipelines: [live]));
    await schemes.saveSchemes(
      const PipelineLibrary(pipelines: [screen]),
      scheme: PipelineScheme.screen,
    );

    expect((await schemes.loadSchemes()).pipelines.single.id, 'live');
    expect(
      (await schemes.loadSchemes(scheme: PipelineScheme.screen)).pipelines.single.id,
      'screen',
    );

    final shared = path.join(root.path, 'shared.json');
    await schemes.exportSchemes(shared, const [screen, live]);
    expect(
      (jsonDecode(await File(shared).readAsString()) as Map<String, Object?>)['pipelines'],
      hasLength(2),
    );
    expect(
      [
        for (final scheme in await schemes.importSchemes([shared])) scheme.id,
      ],
      ['live'],
    );
    expect(
      [
        for (final scheme in await schemes.importSchemes([
          shared,
        ], scheme: PipelineScheme.screen))
          scheme.id,
      ],
      ['screen'],
    );
  });
}

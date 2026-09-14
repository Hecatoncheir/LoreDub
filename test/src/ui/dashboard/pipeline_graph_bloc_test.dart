// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lore_dub/src/data/repositories/app_repository.dart';
import 'package:lore_dub/src/data/repositories/model_repository.dart';
import 'package:lore_dub/src/data/repositories/runtime_repository.dart';
import 'package:lore_dub/src/data/repositories/update_repository.dart';
import 'package:lore_dub/src/data/services/model_storage_service.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:lore_dub/src/data/services/notification_service.dart';
import 'package:lore_dub/src/data/services/runtime_storage_service.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/data/services/update_service.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/character.dart';
import 'package:lore_dub/src/domain/pipeline_graph.dart';
import 'package:lore_dub/src/domain/saved_pipeline.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/dashboard_cubits.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/pipeline_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/pipeline_graph_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The canvas as a script of gestures: what a link drawn between two sockets
/// does to the settings and to the cast, and what one step back undoes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _GraphRepository repository;
  late DashboardCubits cubits;
  late PipelineGraphBloc graph;

  const guard = Character(id: 'guard', name: 'Стражник', vector: [0.2, 0.4]);
  const smith = Character(id: 'smith', name: 'Кузнец', vector: [0.1, 0.9]);

  const gameAudio = PipelinePort(PipelineNodeIds.source, PipelineSocket.gameAudio);
  const speechIn = PipelinePort(PipelineNodeIds.recognition, PipelineSocket.speechIn);
  const screenText = PipelinePort(PipelineNodeIds.source, PipelineSocket.screenText);
  const translationIn = PipelinePort(
    PipelineNodeIds.translation,
    PipelineSocket.translationIn,
  );

  PipelinePort voiceOf(String id) =>
      PipelinePort(PipelineNodeIds.character(id), PipelineSocket.characterVoice);
  PipelinePort readBy(String id) =>
      PipelinePort(PipelineNodeIds.character(id), PipelineSocket.readBy);

  /// Pulls a link from one socket and lets it go over another, the way the
  /// canvas does: the events are what the gesture sends.
  Future<void> drawLink(PipelinePort from, PipelinePort to) async {
    graph.add(PipelineLinkStarted(from, GraphPoint.zero));
    graph.add(const PipelineLinkDragged(GraphPoint(10, 10)));
    graph.add(PipelineLinkReleased(to));
    await pumpEvents();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = _GraphRepository();
    cubits = DashboardCubits(
      repository,
      ModelRepository(ModelStorageService()),
      RuntimeRepository(RuntimeStorageService()),
      UpdateRepository(
        UpdateService(
          client: MockClient((_) async => http.Response('offline', 503)),
          // Read from the platform otherwise, which a unit test does not have.
          packageInfo: Future.value(
            PackageInfo(
              appName: 'LoreDub',
              packageName: 'lore_dub',
              version: '0.15.0',
              buildNumber: '20',
            ),
          ),
        ),
        NotificationService(plugin: FlutterLocalNotificationsPlugin()),
      ),
    );
    graph = cubits.graph;
    repository.stored = const CharacterLibrary(characters: [guard, smith]);
    await cubits.settings.load();
    await cubits.characters.load();
    graph.add(const PipelineGraphOpened());
    graph.add(const PipelineCharacterPlaced('guard'));
    graph.add(const PipelineCharacterPlaced('smith'));
    await pumpEvents();
  });

  tearDown(() async => cubits.dispose());

  test('draws the route the settings describe', () {
    expect(graph.state.graph.route, CaptureMode.audio);
    expect(graph.state.graph.linkInto(speechIn)?.from, gameAudio);
    expect(graph.state.graph.node(PipelineNodeIds.recognition)?.bypassed, isFalse);
  });

  test('takes the way into the pipeline apart, and draws it back', () async {
    final route = graph.state.graph.linkInto(speechIn)!;

    graph.add(PipelineLinkCut(route));
    await pumpEvents();

    expect(cubits.settings.settings.captureRouted, isFalse);
    expect(
      cubits.settings.settings.captureMode,
      CaptureMode.audio,
      reason: 'the mode is remembered, so drawing any link back picks it up',
    );
    expect(graph.state.graph.routed, isFalse);
    expect(graph.state.graph.linkInto(speechIn), isNull);
    for (final node in graph.state.graph.nodes) {
      if (node.kind == PipelineNodeKind.character) continue;
      expect(node.unrouted, isTrue, reason: '${node.id} has nothing reaching it');
      expect(node.bypassed, isFalse, reason: 'unrouted is not the same as passed over');
    }

    await drawLink(gameAudio, speechIn);

    expect(cubits.settings.settings.captureRouted, isTrue);
    expect(graph.state.graph.linkInto(speechIn)?.from, gameAudio);
    expect(graph.state.graph.nodes.every((node) => !node.unrouted), isTrue);
  });

  test('one step back puts a cut route together again', () async {
    graph.add(PipelineLinkCut(graph.state.graph.linkInto(speechIn)!));
    await pumpEvents();
    expect(cubits.settings.settings.captureRouted, isFalse);

    graph.add(const PipelineGraphUndone());
    await pumpEvents();

    expect(cubits.settings.settings.captureRouted, isTrue);
    expect(graph.state.graph.linkInto(speechIn)?.from, gameAudio);
  });

  test('taking the screen text to the translator puts the pipeline in subtitle mode', () async {
    await drawLink(screenText, translationIn);

    expect(cubits.settings.settings.captureMode, CaptureMode.ocr);
    expect(graph.state.graph.linkInto(translationIn)?.from, screenText);
    expect(graph.state.refusal, isNull);
  });

  test('a link the engine has no route for changes nothing and says why', () async {
    await drawLink(screenText, speechIn);

    expect(cubits.settings.settings.captureMode, CaptureMode.audio);
    expect(graph.state.refusal, ConnectionRefusal.signal);
  });

  test('a link between two cards is who reads whom, and is written to the cast', () async {
    // Out of the card whose part it is, into the card that will speak it.
    await drawLink(voiceOf('guard'), readBy('smith'));

    expect(repository.stored.characters.first.voicedBy, 'smith');
    expect(graph.state.graph.linkInto(readBy('smith'))?.from, voiceOf('guard'));
  });

  test('cutting that link gives the card its own voice back', () async {
    await drawLink(voiceOf('guard'), readBy('smith'));

    graph.add(PipelineLinkCut(graph.state.graph.linkInto(readBy('smith'))!));
    await pumpEvents();

    expect(repository.stored.characters.first.voicedBy, isNull);
    expect(
      graph.state.graph.linkInto(readBy('smith')),
      isNull,
      reason: 'nobody speaks for anybody now',
    );
    expect(
      graph.state.graph.links.any(
        (link) =>
            link.from == voiceOf('guard') &&
            link.to == const PipelinePort(PipelineNodeIds.mix, PipelineSocket.mixCast),
      ),
      isTrue,
      reason: 'it speaks for itself again, straight into the mix',
    );
  });

  test('the route cannot be changed while a session is running', () async {
    cubits.pipeline.seed(const LivePipelineState(status: PipelineStatus.listening));

    await drawLink(screenText, translationIn);

    expect(cubits.settings.settings.captureMode, CaptureMode.audio);
    expect(graph.state.refusal, ConnectionRefusal.locked);
  });

  test('a card is still given away while a session is running', () async {
    cubits.pipeline.seed(const LivePipelineState(status: PipelineStatus.listening));

    await drawLink(voiceOf('guard'), readBy('smith'));

    expect(repository.stored.characters.first.voicedBy, 'smith');
  });

  test('a step back puts the route and the cast where they were', () async {
    await drawLink(screenText, translationIn);
    await drawLink(voiceOf('smith'), readBy('guard'));

    graph.add(const PipelineGraphUndone());
    await pumpEvents();
    expect(repository.stored.characters.first.voicedBy, isNull, reason: 'the cast comes back');

    graph.add(const PipelineGraphUndone());
    await pumpEvents();
    expect(cubits.settings.settings.captureMode, CaptureMode.audio);
    expect(graph.state.canRedo, isTrue);

    graph.add(const PipelineGraphRedone());
    await pumpEvents();
    expect(cubits.settings.settings.captureMode, CaptureMode.ocr);
  });

  test('a node dragged is written where it was left', () async {
    final before = graph.state.graph.node(PipelineNodeIds.voice)!.position;

    graph.add(const PipelineNodeGrabbed(PipelineNodeIds.voice));
    graph.add(const PipelineNodeMoved(PipelineNodeIds.voice, 30, -10));
    graph.add(const PipelineNodeMoved(PipelineNodeIds.voice, 10, 5));
    graph.add(const PipelineArrangementSettled());
    await pumpEvents();

    final after = graph.state.graph.node(PipelineNodeIds.voice)!.position;
    expect(after.x, before.x + 40);
    expect(after.y, before.y - 5);
    expect(repository.layout.positions[PipelineNodeIds.voice], after);

    graph.add(const PipelineGraphUndone());
    await pumpEvents();
    expect(
      graph.state.graph.node(PipelineNodeIds.voice)!.position,
      before,
      reason: 'a drag is one step back, not a hundred',
    );
  });

  test('a preset lays the canvas out again and picks its route', () async {
    graph.add(const PipelineNodeGrabbed(PipelineNodeIds.voice));
    graph.add(const PipelineNodeMoved(PipelineNodeIds.voice, 120, 80));
    graph.add(const PipelinePresetChosen(PipelinePreset.subtitles));
    await pumpEvents();

    expect(cubits.settings.settings.captureMode, CaptureMode.ocr);
    expect(
      graph.state.graph.node(PipelineNodeIds.voice)!.position,
      PipelineLayout.standardPositions[PipelineNodeIds.voice],
    );
    expect(graph.state.layout.characters, ['guard', 'smith'], reason: 'the cast stays put');
  });

  test('draws a card again beside the part it takes over', () async {
    graph.add(const PipelineCharacterPlaced('guard'));
    await pumpEvents();

    final copy = PipelineNodeIds.characterCopy('guard', 2);
    expect(graph.state.layout.cast.length, 3);
    expect(graph.state.graph.node(copy)?.characterId, 'guard');
    expect(graph.state.selected, copy, reason: 'the panel opens on what was just drawn');
    // The card was already one of the voices of the game; the copy is drawn
    // to take a part over, so the mix is not told the same character twice.
    expect(
      graph.state.graph.linkInto(PipelinePort(copy, PipelineSocket.characterIn)),
      isNull,
    );
    expect(
      graph.state.graph.linkInto(
        PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.characterIn),
      ),
      isNotNull,
    );
    expect(repository.layout.cast.length, 3, reason: 'the arrangement is written');
  });

  test('one copy goes and the others stay', () async {
    graph.add(const PipelineCharacterPlaced('guard'));
    await pumpEvents();

    graph.add(PipelineCharacterRemoved(PipelineNodeIds.characterCopy('guard', 2)));
    await pumpEvents();

    expect(graph.state.layout.characters, ['guard', 'smith']);
    expect(graph.state.graph.node(PipelineNodeIds.character('guard')), isNotNull);
  });

  test('a card stops being counted among the voices of the game', () async {
    final counted = graph.state.graph.linkInto(
      PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.characterIn),
    )!;

    graph.add(PipelineLinkCut(counted));
    await pumpEvents();

    expect(
      graph.state.graph.linkInto(
        PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.characterIn),
      ),
      isNull,
    );
    expect(
      cubits.characters.state.characters.firstWhere((value) => value.id == 'guard').voicedBy,
      isNull,
      reason: 'a note on the canvas changes nothing of the cast',
    );
    expect(cubits.settings.settings.castRouted, isTrue, reason: 'nor of the settings');
    expect(repository.layout.cast.first.heard, isFalse);

    graph.add(const PipelineGraphUndone());
    await pumpEvents();

    expect(
      graph.state.graph.linkInto(
        PipelinePort(PipelineNodeIds.character('guard'), PipelineSocket.characterIn),
      ),
      isNotNull,
      reason: 'one step back counts it in again',
    );
  });

  group('the shelf of schemes', () {
    /// A scheme kept from a canvas arranged differently from the one the
    /// test starts on, so drawing it back is visible.
    Future<SavedPipeline> keep(String name) async {
      graph.add(PipelineSchemeSaved(name));
      await pumpEvents();
      return graph.state.schemes.last;
    }

    test('keeps the scheme as it stands, and writes the shelf', () async {
      await drawLink(voiceOf('guard'), readBy('smith'));
      graph.add(const PipelineNodeGrabbed(PipelineNodeIds.voice));
      graph.add(const PipelineNodeMoved(PipelineNodeIds.voice, 30, 40));
      await pumpEvents();

      final scheme = await keep('Вечер в таверне');

      expect(scheme.name, 'Вечер в таверне');
      expect(scheme.captureMode, CaptureMode.audio);
      expect(scheme.layout.characters, ['guard', 'smith']);
      expect(
        scheme.layout.positions[PipelineNodeIds.voice]!.x,
        PipelineLayout.standardPositions[PipelineNodeIds.voice]!.x + 30,
      );
      expect(scheme.readers['guard'], 'smith', reason: 'who reads whom is part of the scheme');
      expect(repository.shelf.pipelines.single.id, scheme.id, reason: 'written to the shelf');
    });

    test('draws a kept scheme again and makes it the one that runs', () async {
      await drawLink(screenText, translationIn);
      final subtitles = await keep('С экрана');
      await drawLink(gameAudio, speechIn);
      graph.add(PipelineCharacterRemoved(PipelineNodeIds.character('smith')));
      await pumpEvents();
      expect(cubits.settings.settings.captureMode, CaptureMode.audio);

      graph.add(PipelineSchemeChosen(subtitles.id));
      await pumpEvents();

      expect(cubits.settings.settings.captureMode, CaptureMode.ocr);
      expect(graph.state.layout.characters, ['guard', 'smith'], reason: 'the cards come back');
      expect(graph.state.graph.node(PipelineNodeIds.character('smith')), isNotNull);
    });

    test('puts the substitutions of a scheme back through the cast', () async {
      await drawLink(voiceOf('guard'), readBy('smith'));
      final together = await keep('Со сменой голосов');
      graph.add(
        PipelineLinkCut(
          PipelineLink(voiceOf('guard'), readBy('smith')),
        ),
      );
      await pumpEvents();
      expect(repository.stored.characters.first.voicedBy, isNull);

      graph.add(PipelineSchemeChosen(together.id));
      await pumpEvents();

      expect(repository.stored.characters.first.voicedBy, 'smith');
    });

    test('a scheme with an empty canvas takes every substitution away', () async {
      // What the user hit: one scheme with the cast rearranged, another with
      // a bare canvas. Choosing the bare one left the arrangement sounding,
      // because it named no cards to put back.
      graph.add(PipelineCharacterRemoved(PipelineNodeIds.character('guard')));
      graph.add(PipelineCharacterRemoved(PipelineNodeIds.character('smith')));
      await pumpEvents();
      final bare = await keep('Пусто');
      await drawLink(voiceOf('guard'), readBy('smith'));
      expect(repository.stored.characters.first.voicedBy, 'smith');
      repository.told.clear();

      graph.add(PipelineSchemeChosen(bare.id));
      await pumpEvents();

      expect(graph.state.layout.cast, isEmpty);
      expect(repository.stored.characters.first.voicedBy, isNull);
      expect(
        repository.told,
        contains(('guard', null)),
        reason: 'a session under the pause is told, not left reading the old scheme',
      );
    });

    test('a scheme is not drawn over a running session that would reroute', () async {
      await drawLink(screenText, translationIn);
      final subtitles = await keep('С экрана');
      await drawLink(gameAudio, speechIn);
      cubits.pipeline.seed(const LivePipelineState(status: PipelineStatus.listening));
      await pumpEvents();

      graph.add(PipelineSchemeChosen(subtitles.id));
      await pumpEvents();

      expect(cubits.settings.settings.captureMode, CaptureMode.audio);
      expect(graph.state.refusal, ConnectionRefusal.locked);
    });

    test('renames and throws away a scheme', () async {
      final scheme = await keep('Схема');

      graph.add(PipelineSchemeRenamed(scheme.id, 'Другое имя'));
      await pumpEvents();
      expect(repository.shelf.pipelines.single.name, 'Другое имя');

      graph.add(PipelineSchemeRemoved(scheme.id));
      await pumpEvents();
      expect(graph.state.schemes, isEmpty);
      expect(repository.shelf.pipelines, isEmpty);
    });

    test('writes one scheme to a file and reads schemes back', () async {
      final scheme = await keep('Схема');

      graph.add(PipelineSchemeExported(scheme.id, 'C:/out.json'));
      await pumpEvents();
      expect(repository.exported.single.$1, 'C:/out.json');
      expect(repository.exported.single.$2.single.id, scheme.id);

      // A file carrying an id already on the shelf lands on the scheme it
      // came from rather than beside it.
      repository.incoming = [
        SavedPipeline(id: scheme.id, name: 'Из файла'),
        const SavedPipeline(id: 'other', name: 'Ещё одна'),
      ];
      graph.add(const PipelineSchemeImported(['C:/in.json']));
      await pumpEvents();

      expect(graph.state.schemes.length, 2);
      expect(graph.state.schemes.first.name, 'Из файла');
      expect(repository.shelf.pipelines.last.id, 'other');
    });

    test('a scheme with no name is not kept', () async {
      graph.add(const PipelineSchemeSaved('   '));
      await pumpEvents();

      expect(graph.state.schemes, isEmpty);
    });
  });

  group('choosing several nodes', () {
    const voice = PipelineNodeIds.voice;
    const mix = PipelineNodeIds.mix;

    test('a click chooses one node and lets the last one go', () async {
      graph.add(const PipelineNodeSelected(voice));
      await pumpEvents();
      graph.add(const PipelineNodeSelected(mix));
      await pumpEvents();

      expect(graph.state.chosen, {mix});
      expect(graph.state.selected, mix, reason: 'one chosen node opens its own settings');
    });

    test('a click with shift adds a node and takes it back out', () async {
      graph.add(const PipelineNodeSelected(voice));
      graph.add(const PipelineNodeSelected(mix, add: true));
      await pumpEvents();

      expect(graph.state.chosen, {voice, mix});
      expect(
        graph.state.selected,
        isNull,
        reason: 'there is no such thing as the settings of two nodes',
      );

      graph.add(const PipelineNodeSelected(mix, add: true));
      await pumpEvents();

      expect(graph.state.chosen, {voice});
      expect(graph.state.selected, voice, reason: 'down to one, the panel opens again');
    });

    test('a band names what it caught, and empty space lets it all go', () async {
      graph.add(const PipelineSelectionSet({voice, mix}));
      await pumpEvents();
      expect(graph.state.chosen, {voice, mix});

      graph.add(const PipelineNodeSelected(null));
      await pumpEvents();

      expect(graph.state.chosen, isEmpty);
      expect(graph.state.selected, isNull);
    });

    test('a drag carries every chosen node the same way', () async {
      final was = {
        for (final id in [voice, mix]) id: graph.state.graph.node(id)!.position,
      };
      graph.add(const PipelineSelectionSet({voice, mix}));
      await pumpEvents();

      graph.add(const PipelineNodeGrabbed(voice));
      graph.add(const PipelineNodeMoved(voice, 40, -25));
      await pumpEvents();

      for (final id in [voice, mix]) {
        expect(graph.state.graph.node(id)!.position.x, was[id]!.x + 40);
        expect(graph.state.graph.node(id)!.position.y, was[id]!.y - 25);
      }

      // One step back is the whole move, not one node of it.
      graph.add(const PipelineGraphUndone());
      await pumpEvents();
      for (final id in [voice, mix]) {
        expect(graph.state.graph.node(id)!.position, was[id]);
      }
    });

    test('the group keeps its shape at the edge of the world', () async {
      graph.add(const PipelineSelectionSet({voice, mix}));
      await pumpEvents();
      final apart =
          graph.state.graph.node(mix)!.position.x - graph.state.graph.node(voice)!.position.x;

      graph.add(const PipelineNodeGrabbed(voice));
      graph.add(const PipelineNodeMoved(voice, GraphWorld.width * 2, 0));
      await pumpEvents();

      expect(
        graph.state.graph.node(mix)!.position.x - graph.state.graph.node(voice)!.position.x,
        apart,
        reason: 'held back by whichever reaches the wall first, not folded against it',
      );
    });

    test('a node taken hold of from outside the choice becomes the choice', () async {
      graph.add(const PipelineSelectionSet({voice, mix}));
      await pumpEvents();

      graph.add(PipelineNodeGrabbed(PipelineNodeIds.character('guard')));
      graph.add(PipelineNodeMoved(PipelineNodeIds.character('guard'), 10, 10));
      await pumpEvents();

      expect(graph.state.chosen, {PipelineNodeIds.character('guard')});
      expect(
        graph.state.graph.node(voice)!.position,
        PipelineLayout.standardPositions[voice],
        reason: 'the ones let go of stayed where they were',
      );
    });

    test('a card taken off the canvas leaves the choice with it', () async {
      graph.add(PipelineSelectionSet({PipelineNodeIds.character('guard'), voice}));
      await pumpEvents();

      graph.add(PipelineCharacterRemoved(PipelineNodeIds.character('guard')));
      await pumpEvents();

      expect(graph.state.chosen, {voice});
    });
  });

  test('a card taken off the canvas keeps the voice that reads it', () async {
    await drawLink(voiceOf('guard'), readBy('smith'));

    graph.add(PipelineCharacterRemoved(PipelineNodeIds.character('guard')));
    await pumpEvents();

    expect(graph.state.layout.characters, ['smith']);
    expect(repository.stored.characters.first.voicedBy, 'smith');
  });

  test('takes a card off the canvas even while it speaks for another', () async {
    await drawLink(voiceOf('guard'), readBy('smith'));

    graph.add(PipelineCharacterRemoved(PipelineNodeIds.character('smith')));
    await pumpEvents();

    expect(graph.state.layout.characters, ['guard']);
    expect(
      graph.state.graph.node(PipelineNodeIds.character('smith')),
      isNull,
      reason: 'asked to go, it goes, link or no link',
    );
    expect(
      cubits.characters.state.characters.firstWhere((value) => value.id == 'guard').voicedBy,
      'smith',
      reason: 'taking a card off the canvas is not taking the voice away',
    );
    // With nowhere on the canvas for the part to go, it goes to the mix, and
    // the card says whose voice reads it on its own face.
    expect(
      graph.state.graph.links.any(
        (link) =>
            link.from == voiceOf('guard') &&
            link.to == const PipelinePort(PipelineNodeIds.mix, PipelineSocket.mixCast),
      ),
      isTrue,
    );

    graph.add(const PipelineCharacterPlaced('smith'));
    await pumpEvents();

    expect(
      graph.state.graph.linkInto(readBy('smith'))?.from,
      voiceOf('guard'),
      reason: 'put back, it speaks for them again',
    );
  });

  /// What the canvas lets the player do while the dubbing rests.
  ///
  /// A paused session keeps its models loaded and its capture open, so the
  /// way in is as fixed as it is while the dubbing runs — but the cast is
  /// not: cards may be brought on, taken off and rewired, and the worker is
  /// told of every one of those without a restart.
  group('while the dubbing rests', () {
    setUp(() {
      cubits.pipeline.seed(const LivePipelineState(status: PipelineStatus.paused));
    });

    test('the way into the pipeline stays shut', () async {
      await drawLink(screenText, translationIn);

      expect(cubits.settings.settings.captureMode, CaptureMode.audio);
      expect(graph.state.refusal, ConnectionRefusal.locked);
      expect(graph.state.graph.linkInto(speechIn)?.from, gameAudio);
    });

    test('and cannot be taken apart either', () async {
      graph.add(PipelineLinkCut(graph.state.graph.linkInto(speechIn)!));
      await pumpEvents();

      expect(cubits.settings.settings.captureRouted, isTrue);
      expect(graph.state.refusal, ConnectionRefusal.locked);
    });

    test('a card is brought onto the canvas', () async {
      graph.add(PipelineCharacterRemoved(PipelineNodeIds.character('smith')));
      await pumpEvents();
      expect(graph.state.layout.characters, ['guard']);

      graph.add(const PipelineCharacterPlaced('smith'));
      await pumpEvents();

      expect(graph.state.layout.characters, ['guard', 'smith']);
      expect(graph.state.graph.node(PipelineNodeIds.character('smith')), isNotNull);
    });

    test('a card is taken off it', () async {
      graph.add(PipelineCharacterRemoved(PipelineNodeIds.character('guard')));
      await pumpEvents();

      expect(graph.state.layout.characters, ['smith']);
      expect(graph.state.graph.node(PipelineNodeIds.character('guard')), isNull);
    });

    test('a scheme put up while it rests changes who reads whom', () async {
      // The point of resting: rearrange the cast, put the scheme up, and
      // carry on with the voices it describes.
      await drawLink(voiceOf('guard'), readBy('smith'));
      graph.add(const PipelineSchemeSaved('Со сменой'));
      await pumpEvents();
      final scheme = graph.state.schemes.single;
      graph.add(PipelineLinkCut(PipelineLink(voiceOf('guard'), readBy('smith'))));
      await pumpEvents();
      repository.told.clear();

      graph.add(PipelineSchemeChosen(scheme.id));
      await pumpEvents();

      expect(repository.stored.characters.first.voicedBy, 'smith');
      expect(
        repository.told,
        contains(('guard', 'smith')),
        reason: 'the worker running under the pause is told, not left behind',
      );
      expect(cubits.pipeline.state.status, PipelineStatus.paused, reason: 'still rested');
    });

    test('one card is given to another, and the worker is told', () async {
      await drawLink(voiceOf('guard'), readBy('smith'));

      expect(graph.state.refusal, isNull);
      expect(repository.stored.characters.first.voicedBy, 'smith');
      expect(
        repository.told.last,
        ('guard', 'smith'),
        reason: 'the session keeps its cast loaded, so it is told rather than restarted',
      );
    });

    test('and the gift is taken back', () async {
      await drawLink(voiceOf('guard'), readBy('smith'));

      graph.add(PipelineLinkCut(graph.state.graph.linkInto(readBy('smith'))!));
      await pumpEvents();

      expect(repository.stored.characters.first.voicedBy, isNull);
      expect(repository.told.last, ('guard', null));
    });

    test('the cast comes out of the mix, and goes back in', () async {
      const intoTheMix = PipelinePort(PipelineNodeIds.mix, PipelineSocket.mixCast);
      await drawLink(voiceOf('guard'), readBy('smith'));

      graph.add(
        PipelineLinkCut(
          graph.state.graph.links.firstWhere((link) => link.to == intoTheMix),
        ),
      );
      await pumpEvents();

      expect(cubits.settings.settings.castRouted, isFalse);
      expect(graph.state.refusal, isNull, reason: 'the cast is not locked with the route');
      // The cards stay where they were put, dark, and who stands in for whom
      // waits in them for the link to come back.
      expect(graph.state.graph.node(PipelineNodeIds.character('guard'))?.unrouted, isTrue);
      expect(repository.stored.characters.first.voicedBy, 'smith');
      expect(
        graph.state.graph.links.any((link) => link.to == intoTheMix),
        isFalse,
      );

      await drawLink(voiceOf('smith'), intoTheMix);

      expect(cubits.settings.settings.castRouted, isTrue);
      expect(graph.state.graph.linkInto(readBy('smith'))?.from, voiceOf('guard'));
    });

    test('and a step back puts it back too', () async {
      const intoTheMix = PipelinePort(PipelineNodeIds.mix, PipelineSocket.mixCast);
      graph.add(
        PipelineLinkCut(
          graph.state.graph.links.firstWhere((link) => link.to == intoTheMix),
        ),
      );
      await pumpEvents();
      expect(cubits.settings.settings.castRouted, isFalse);

      graph.add(const PipelineGraphUndone());
      await pumpEvents();

      expect(cubits.settings.settings.castRouted, isTrue);
    });

    test('one step back still undoes what was done', () async {
      await drawLink(voiceOf('guard'), readBy('smith'));

      graph.add(const PipelineGraphUndone());
      await pumpEvents();

      expect(repository.stored.characters.first.voicedBy, isNull);
    });
  });
}

/// Lets the bloc work through what the gestures added. Events are handled
/// one at a time, and each one may write to the settings or the cast.
Future<void> pumpEvents() => Future<void>.delayed(Duration.zero);

/// An application repository with no disk behind it: the cast and the
/// arrangement are kept in memory.
class _GraphRepository extends AppRepository {
  _GraphRepository() : super(NativeEngineService(), SettingsService());

  CharacterLibrary stored = CharacterLibrary.empty;
  PipelineLayout layout = PipelineLayout.standard;

  /// The shelf of schemes, what was written out of it and what is read in.
  PipelineLibrary shelf = PipelineLibrary.empty;
  final exported = <(String, List<SavedPipeline>)>[];
  List<SavedPipeline> incoming = const [];

  @override
  Future<CharacterLibrary> loadCharacters() async => stored;

  @override
  Future<void> saveCharacters(CharacterLibrary library) async => stored = library;

  @override
  Future<PipelineLayout> loadGraphLayout() async => layout;

  @override
  Future<void> saveGraphLayout(PipelineLayout value) async => layout = value;

  @override
  Future<PipelineLibrary> loadPipelines() async => shelf;

  @override
  Future<void> savePipelines(PipelineLibrary library) async => shelf = library;

  @override
  Future<void> exportPipelines(String destination, List<SavedPipeline> pipelines) async =>
      exported.add((destination, pipelines));

  @override
  Future<List<SavedPipeline>> importPipelines(List<String> sources) async => incoming;

  @override
  Future<void> voiceCharacterAs(String id, String? target) async => told.add((id, target));

  /// What a running worker was told to read anew, without a restart.
  final told = <(String, String?)>[];

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

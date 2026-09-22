// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lore_dub/src/data/repositories/settings_repository.dart';
import 'package:lore_dub/src/data/repositories/model_repository.dart';
import 'package:lore_dub/src/data/repositories/runtime_repository.dart';
import 'package:lore_dub/src/data/repositories/update_repository.dart';
import 'package:lore_dub/src/data/services/model_storage_service.dart';
import 'package:lore_dub/src/data/services/notification_service.dart';
import 'package:lore_dub/src/data/services/runtime_storage_service.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/data/services/update_service.dart';
import 'package:lore_dub/src/data/repositories/glossary_repository.dart';
import 'package:lore_dub/src/domain/character.dart';
import 'package:lore_dub/src/domain/glossary.dart';
import 'package:lore_dub/src/domain/pipeline_graph.dart';
import 'package:lore_dub/src/domain/saved_pipeline.dart';
import 'package:lore_dub/src/domain/spoken_language.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart';

import '../../../../support/staged_dashboard.dart';

import 'package:lore_dub/src/ui/common/bloc/session_bloc.dart';
import 'package:lore_dub/src/ui/graph/bloc/pipeline_graph_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lore_dub/src/data/repositories/cast_repository.dart';

import '../../../../support/memory_cast.dart';
import '../../../../support/fakes/fake_session_repository.dart';

/// The canvas as a script of gestures: what a link drawn between two sockets
/// does to the settings and to the cast, and what one step back undoes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _GraphRepository repository;
  late StagedDashboard cubits;
  late PipelineGraphBloc graph;

  const guard = Character(id: 'guard', name: 'Стражник', vector: [0.2, 0.4]);
  const smith = Character(id: 'smith', name: 'Кузнец', vector: [0.1, 0.9]);

  const gameAudio = PipelinePort(PipelineNodeIds.source, PipelineSocket.gameAudio);
  const speechIn = PipelinePort(PipelineNodeIds.recognition, PipelineSocket.speechIn);
  const translationIn = PipelinePort(
    PipelineNodeIds.translation,
    PipelineSocket.translationIn,
  );

  PipelinePort voiceOf(String id) =>
      PipelinePort(PipelineNodeIds.character(id), PipelineSocket.characterVoice);
  PipelinePort readBy(String id) =>
      PipelinePort(PipelineNodeIds.character(id), PipelineSocket.readBy);
  PipelinePort heardIn(String id) =>
      PipelinePort(PipelineNodeIds.character(id), PipelineSocket.characterIn);

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
    final settings = SettingsRepository(SettingsService());
    cubits = StagedDashboard(
      repository,
      settings,
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
      cast: CastRepository(repository.engine, repository.cards),
      schemes: repository.schemes,
      glossaryRepository: GlossaryRepository(settings, repository.engine, repository.words),
    );
    graph = cubits.graph;
    repository.stored = const CharacterLibrary(characters: [guard, smith]);
    await cubits.settingsRepository.load();
    await cubits.cast.load();
    graph.add(const PipelineGraphOpened());
    graph.add(const PipelineCharacterPlaced('guard'));
    graph.add(const PipelineCharacterPlaced('smith'));
    await pumpEvents();
  });

  tearDown(() async => cubits.dispose());

  test('tells an event from another by what it carries', () {
    // What lets a screen's test verify the events it sends over a mock.
    const port = PipelinePort(PipelineNodeIds.voice, PipelineSocket.voiceCast);
    expect(const PipelineNodeMoved('mix', 1, 2), const PipelineNodeMoved('mix', 1, 2));
    expect(const PipelineNodeMoved('mix', 1, 2), isNot(const PipelineNodeMoved('mix', 1, 3)));
    expect(PipelineSelectionSet({'mix'}), PipelineSelectionSet({'mix'}));
    expect(
      const PipelineLinkStarted(port, GraphPoint(4, 5)),
      const PipelineLinkStarted(port, GraphPoint(4, 5)),
    );
    expect(
      const PipelineViewSet(GraphView(x: 1, zoom: 1.2)),
      const PipelineViewSet(GraphView(x: 1, zoom: 1.2)),
    );
    expect(const PipelineGraphUndone(), const PipelineGraphUndone());
    expect(const PipelineGraphUndone(), isNot(const PipelineGraphRedone()));
  });

  test('draws the route the settings describe', () {
    expect(graph.state.graph.routed, isTrue);
    expect(graph.state.graph.linkInto(speechIn)?.from, gameAudio);
  });

  test('takes the way into the pipeline apart, and draws it back', () async {
    final route = graph.state.graph.linkInto(speechIn)!;

    graph.add(PipelineLinkCut(route));
    await pumpEvents();

    expect(cubits.settings.settings.captureRouted, isFalse);
    expect(graph.state.graph.routed, isFalse);
    expect(graph.state.graph.linkInto(speechIn), isNull);
    for (final node in graph.state.graph.nodes) {
      if (node.kind == PipelineNodeKind.character) continue;
      expect(node.unrouted, isTrue, reason: '${node.id} has nothing reaching it');
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

  test('a link the engine has no route for changes nothing and says why', () async {
    await drawLink(gameAudio, translationIn);

    expect(cubits.settings.settings.captureRouted, isTrue);
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
    cubits.stageSession(const SessionState(status: PipelineStatus.listening));

    graph.add(PipelineLinkCut(graph.state.graph.linkInto(speechIn)!));
    await pumpEvents();

    expect(cubits.settings.settings.captureRouted, isTrue);
    expect(graph.state.refusal, ConnectionRefusal.locked);
  });

  test('cutting the translator dubs into English, which asks for none', () async {
    // There is no setting of its own behind the stage: whisper hands English
    // over whatever the game speaks, so a line without the translator is a
    // session dubbing into English, and the catalogue has a voice for it.
    graph.add(PipelineLinkCut(graph.state.graph.linkInto(translationIn)!));
    await pumpEvents();

    expect(cubits.settings.settings.targetLanguage, untranslatedDubbingLanguage);
    expect(graph.state.refusal, isNull);
    expect(graph.state.graph.linkInto(translationIn), isNull);
  });

  test('a card is still given away while a session is running', () async {
    cubits.stageSession(const SessionState(status: PipelineStatus.listening));

    await drawLink(voiceOf('guard'), readBy('smith'));

    expect(repository.stored.characters.first.voicedBy, 'smith');
  });

  test('a step back puts the route and the cast where they were', () async {
    graph.add(PipelineLinkCut(graph.state.graph.linkInto(speechIn)!));
    await pumpEvents();
    await drawLink(voiceOf('smith'), readBy('guard'));

    graph.add(const PipelineGraphUndone());
    await pumpEvents();
    expect(repository.stored.characters.first.voicedBy, isNull, reason: 'the cast comes back');

    graph.add(const PipelineGraphUndone());
    await pumpEvents();
    expect(cubits.settings.settings.captureRouted, isTrue);
    expect(graph.state.canRedo, isTrue);

    graph.add(const PipelineGraphRedone());
    await pumpEvents();
    expect(cubits.settings.settings.captureRouted, isFalse);
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

  test('the arrangement goes back to where it started, the cast staying put', () async {
    graph.add(const PipelineNodeGrabbed(PipelineNodeIds.voice));
    graph.add(const PipelineNodeMoved(PipelineNodeIds.voice, 120, 80));
    graph.add(const PipelineLayoutReset());
    await pumpEvents();

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

    graph.add(PipelineNodeRemoved(PipelineNodeIds.characterCopy('guard', 2)));
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
      cubits.cast.cast.firstWhere((value) => value.id == 'guard').voicedBy,
      isNull,
      reason: 'a note on the canvas changes nothing of the cast',
    );
    expect(graph.state.layout.silent, isEmpty, reason: 'nor of who is in the mix');
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
      expect(scheme.captureRouted, isTrue);
      expect(scheme.layout.characters, ['guard', 'smith']);
      expect(
        scheme.layout.positions[PipelineNodeIds.voice]!.x,
        PipelineLayout.standardPositions[PipelineNodeIds.voice]!.x + 30,
      );
      expect(scheme.readers['guard'], 'smith', reason: 'who reads whom is part of the scheme');
      expect(repository.shelf.pipelines.single.id, scheme.id, reason: 'written to the shelf');
    });

    test('draws a kept scheme again and makes it the one that runs', () async {
      graph.add(PipelineLinkCut(graph.state.graph.linkInto(speechIn)!));
      await pumpEvents();
      final cut = await keep('Путь разобран');
      await drawLink(gameAudio, speechIn);
      graph.add(PipelineNodeRemoved(PipelineNodeIds.character('smith')));
      await pumpEvents();
      expect(cubits.settings.settings.captureRouted, isTrue);

      graph.add(PipelineSchemeChosen(cut.id));
      await pumpEvents();

      expect(cubits.settings.settings.captureRouted, isFalse);
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
      graph.add(PipelineNodeRemoved(PipelineNodeIds.character('guard')));
      graph.add(PipelineNodeRemoved(PipelineNodeIds.character('smith')));
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
      graph.add(PipelineLinkCut(graph.state.graph.linkInto(speechIn)!));
      await pumpEvents();
      final cut = await keep('Путь разобран');
      await drawLink(gameAudio, speechIn);
      cubits.stageSession(const SessionState(status: PipelineStatus.listening));
      await pumpEvents();

      graph.add(PipelineSchemeChosen(cut.id));
      await pumpEvents();

      expect(cubits.settings.settings.captureRouted, isTrue);
      expect(graph.state.refusal, ConnectionRefusal.locked);
    });

    test('writes the canvas over a scheme already kept', () async {
      graph.add(const PipelineNodeGrabbed(PipelineNodeIds.voice));
      graph.add(const PipelineNodeMoved(PipelineNodeIds.voice, 30, 40));
      await pumpEvents();
      final scheme = await keep('Вечер в таверне');
      final was = scheme.layout.positions[PipelineNodeIds.voice];

      // The scheme goes on being worked on: a node moved and a card given
      // away since it was kept.
      graph.add(const PipelineNodeMoved(PipelineNodeIds.voice, 40, 25));
      await drawLink(voiceOf('guard'), readBy('smith'));
      graph.add(PipelineSchemeReplaced(scheme.id));
      await pumpEvents();

      final written = repository.shelf.pipelines.single;
      expect(written.id, scheme.id, reason: 'the same scheme, not another one beside it');
      expect(written.name, 'Вечер в таверне', reason: 'under the name it was given');
      expect(written.readers['guard'], 'smith');
      expect(written.layout.positions[PipelineNodeIds.voice], isNot(was));
      expect(graph.state.schemes.single.readers['guard'], 'smith');
    });

    test('writes over nothing when the scheme is no longer on the shelf', () async {
      await keep('Схема');
      await drawLink(voiceOf('guard'), readBy('smith'));

      graph.add(const PipelineSchemeReplaced('gone'));
      await pumpEvents();

      expect(graph.state.schemes.single.name, 'Схема');
      expect(
        graph.state.schemes.single.readers['guard'],
        isNull,
        reason: 'the shelf is left as it was rather than written somewhere else',
      );
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

      graph.add(PipelineNodeRemoved(PipelineNodeIds.character('guard')));
      await pumpEvents();

      expect(graph.state.chosen, {voice});
    });
  });

  test('a card taken off the canvas keeps the voice that reads it', () async {
    await drawLink(voiceOf('guard'), readBy('smith'));

    graph.add(PipelineNodeRemoved(PipelineNodeIds.character('guard')));
    await pumpEvents();

    expect(graph.state.layout.characters, ['smith']);
    expect(repository.stored.characters.first.voicedBy, 'smith');
  });

  test('takes a card off the canvas even while it speaks for another', () async {
    await drawLink(voiceOf('guard'), readBy('smith'));

    graph.add(PipelineNodeRemoved(PipelineNodeIds.character('smith')));
    await pumpEvents();

    expect(graph.state.layout.characters, ['guard']);
    expect(
      graph.state.graph.node(PipelineNodeIds.character('smith')),
      isNull,
      reason: 'asked to go, it goes, link or no link',
    );
    expect(
      cubits.cast.cast.firstWhere((value) => value.id == 'guard').voicedBy,
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
      cubits.stageSession(const SessionState(status: PipelineStatus.paused));
    });

    test('the way into the pipeline cannot be taken apart', () async {
      graph.add(PipelineLinkCut(graph.state.graph.linkInto(speechIn)!));
      await pumpEvents();

      expect(cubits.settings.settings.captureRouted, isTrue);
      expect(graph.state.refusal, ConnectionRefusal.locked);
    });

    test('a card is brought onto the canvas', () async {
      graph.add(PipelineNodeRemoved(PipelineNodeIds.character('smith')));
      await pumpEvents();
      expect(graph.state.layout.characters, ['guard']);

      graph.add(const PipelineCharacterPlaced('smith'));
      await pumpEvents();

      expect(graph.state.layout.characters, ['guard', 'smith']);
      expect(graph.state.graph.node(PipelineNodeIds.character('smith')), isNotNull);
    });

    test('a card is taken off it', () async {
      graph.add(PipelineNodeRemoved(PipelineNodeIds.character('guard')));
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

    test('one card comes out of the mix, and goes back in', () async {
      const intoTheMix = PipelinePort(PipelineNodeIds.mix, PipelineSocket.mixCast);
      // Guard's part runs to smith, so smith is the card the mix hears.
      await drawLink(voiceOf('guard'), readBy('smith'));
      repository.heard.clear();

      graph.add(
        PipelineLinkCut(
          graph.state.graph.links.firstWhere((link) => link.to == intoTheMix),
        ),
      );
      await pumpEvents();

      expect(graph.state.layout.silent, {'smith'});
      expect(
        repository.heard,
        [
          {'smith'},
        ],
        reason: 'the session keeps its cast loaded, so it is told which card fell silent',
      );
      expect(graph.state.refusal, isNull, reason: 'the cast is not locked with the route');
      // The card stays where it was put, dark, and who stands in for whom
      // waits in it for the link to come back.
      expect(graph.state.graph.node(PipelineNodeIds.character('smith'))?.unrouted, isTrue);
      expect(repository.stored.characters.first.voicedBy, 'smith');
      // The card it was reading is untouched and speaks for itself again.
      expect(graph.state.graph.node(PipelineNodeIds.character('guard'))?.unrouted, isFalse);
      expect(graph.state.graph.linkInto(intoTheMix)?.from, voiceOf('guard'));

      await drawLink(voiceOf('smith'), intoTheMix);

      expect(graph.state.layout.silent, isEmpty);
      expect(
        repository.heard,
        [
          {'smith'},
          <String>{},
        ],
        reason: 'and told again when it is joined back',
      );
      expect(graph.state.graph.linkInto(readBy('smith'))?.from, voiceOf('guard'));
    });

    test('a card the game does not speak is joined by the line drawn to it', () async {
      const intoTheMix = PipelinePort(PipelineNodeIds.mix, PipelineSocket.mixCast);
      // Taken out of the voices the game speaks, a card has no part of its
      // own: nothing of it reaches the mix, and there is no line to cut.
      graph.add(PipelineLinkCut(graph.state.graph.linkInto(heardIn('guard'))!));
      await pumpEvents();
      expect(
        graph.state.graph.links.any((link) => link.from == voiceOf('guard')),
        isFalse,
        reason: 'it lends its voice and speaks nothing of its own',
      );

      await drawLink(voiceOf('guard'), intoTheMix);

      // The line the player drew is the line they get: the card is one of
      // the voices the game speaks again, which is where its part comes
      // from, and that part goes to the mix.
      expect(graph.state.layout.cast.first.heard, isTrue);
      expect(
        graph.state.graph.links.any(
          (link) => link.from == voiceOf('guard') && link.to == intoTheMix,
        ),
        isTrue,
      );
    });

    test('a line drawn to a cut card puts that card back in the mix', () async {
      const intoTheMix = PipelinePort(PipelineNodeIds.mix, PipelineSocket.mixCast);
      graph.add(
        PipelineLinkCut(
          graph.state.graph.links.firstWhere(
            (link) => link.from == voiceOf('guard') && link.to == intoTheMix,
          ),
        ),
      );
      await pumpEvents();
      expect(graph.state.layout.silent, {'guard'});

      // Not the line that cut it, and not even one out of the card: a line
      // drawn to a card is the player wiring that card up.
      await drawLink(
        const PipelinePort(PipelineNodeIds.voice, PipelineSocket.voiceCast),
        heardIn('guard'),
      );

      expect(graph.state.layout.silent, isEmpty);
      expect(graph.state.graph.node(PipelineNodeIds.character('guard'))?.unrouted, isFalse);
      expect(graph.state.graph.linkInto(heardIn('guard'))?.from.nodeId, PipelineNodeIds.voice);
      expect(repository.heard.last, isEmpty, reason: 'and a running session is told');
    });

    test('and a step back puts it back too', () async {
      const intoTheMix = PipelinePort(PipelineNodeIds.mix, PipelineSocket.mixCast);
      graph.add(
        PipelineLinkCut(
          graph.state.graph.links.firstWhere((link) => link.to == intoTheMix),
        ),
      );
      await pumpEvents();
      expect(graph.state.layout.silent, isNotEmpty);

      graph.add(const PipelineGraphUndone());
      await pumpEvents();

      expect(graph.state.layout.silent, isEmpty);
      expect(repository.heard.last, isEmpty, reason: 'and the worker hears of the step back');
    });

    test('one step back still undoes what was done', () async {
      await drawLink(voiceOf('guard'), readBy('smith'));

      graph.add(const PipelineGraphUndone());
      await pumpEvents();

      expect(repository.stored.characters.first.voicedBy, isNull);
    });
  });

  group('the glossary in the line of text', () {
    const fire = GlossaryEntry(
      kind: GlossaryKind.phrase,
      source: 'Fire in the hole!',
      reading: 'Ложись!',
    );
    const vault = GlossaryEntry(kind: GlossaryKind.word, source: 'Хранилище', reading: 'Убежище');
    final lines = GlossaryPack(id: 'lines', name: 'Реплики наизусть', entryKeys: [fire.packKey]);
    final fallout = GlossaryPack(id: 'fallout', name: 'Fallout', entryKeys: [vault.packKey]);

    const heard = PipelinePort(PipelineNodeIds.recognition, PipelineSocket.speechText);
    const intoTranslator = PipelinePort(PipelineNodeIds.translation, PipelineSocket.translationIn);
    const translated = PipelinePort(PipelineNodeIds.translation, PipelineSocket.translatedText);
    const intoVoice = PipelinePort(PipelineNodeIds.voice, PipelineSocket.voiceIn);
    PipelinePort into(String nodeId) => PipelinePort(nodeId, PipelineSocket.glossaryIn);
    PipelinePort outOf(String nodeId) => PipelinePort(nodeId, PipelineSocket.glossaryOut);

    GlossaryPack packOf(String id) => cubits.glossaryRepository.glossary.packWithId(id)!;

    /// Puts [packId] on the canvas and answers with its node.
    Future<PipelineNode> place(String packId) async {
      graph.add(PipelineGlossaryPlaced(packId));
      await pumpEventQueue();
      return graph.state.graph.ofKind(PipelineNodeKind.glossary).last;
    }

    /// Draws a line and lets every write it makes land.
    Future<void> draw(PipelinePort from, PipelinePort to) async {
      await drawLink(from, to);
      await pumpEventQueue();
    }

    /// Where the text runs, stop by stop.
    List<String> line() {
      final next = {
        for (final link in graph.state.graph.links)
          if (link.signal == PipelineSignal.text) link.from.nodeId: link.to.nodeId,
      };
      final stops = [PipelineNodeIds.recognition];
      for (var after = next[stops.last]; after != null; after = next[after]) {
        stops.add(after);
      }
      return stops;
    }

    setUp(() async {
      cubits.stageGlossary(Glossary(entries: const [fire, vault], packs: [lines, fallout]));
      await pumpEventQueue();
    });

    test('puts a pack on the canvas out of the line, and opens its panel', () async {
      final node = await place('fallout');

      expect(node.feed, isNull);
      expect(node.unrouted, isTrue);
      expect(graph.state.selected, node.id);
      expect(line(), [
        PipelineNodeIds.recognition,
        PipelineNodeIds.translation,
        PipelineNodeIds.voice,
      ]);
      expect(packOf('fallout').active, isFalse, reason: 'putting it down switches nothing');
      expect(repository.layout.glossaries, hasLength(1), reason: 'kept with the arrangement');
    });

    test('chains packs Text into Text, after whisper and after the translator', () async {
      final a = await place('lines');
      final b = await place('lines');
      final c = await place('fallout');
      final d = await place('fallout');

      await draw(heard, into(a.id));
      await draw(outOf(a.id), into(b.id));
      await draw(translated, into(c.id));
      await draw(outOf(c.id), into(d.id));

      expect(line(), [
        PipelineNodeIds.recognition,
        a.id,
        b.id,
        PipelineNodeIds.translation,
        c.id,
        d.id,
        PipelineNodeIds.voice,
      ]);
      expect(packOf('lines').active, isTrue, reason: 'a pack in the line is switched on');
      expect(packOf('fallout').active, isTrue);
    });

    test('puts a pack in the line before the voice by a line out of it', () async {
      final node = await place('fallout');

      await draw(outOf(node.id), intoVoice);

      expect(line(), [
        PipelineNodeIds.recognition,
        PipelineNodeIds.translation,
        node.id,
        PipelineNodeIds.voice,
      ]);
      expect(repository.glossaries.last.entries, [vault], reason: 'a running session reads it');
    });

    test('tells a running session what a pack reads once it is moved along the line', () async {
      final node = await place('fallout');
      await draw(outOf(node.id), intoVoice);
      expect(repository.glossaries.last.entries, [vault]);

      await draw(heard, into(node.id));

      expect(graph.state.graph.node(node.id)?.feed, GlossaryFeed.recognition);
      expect(
        repository.glossaries.last.entries,
        isEmpty,
        reason: 'before the translator a pack answers with phrases, and this one has none',
      );
    });

    test(
      'takes a pack out of the line and switches it off, and a step back puts both back',
      () async {
        final node = await place('fallout');
        await draw(outOf(node.id), intoVoice);

        graph.add(PipelineLinkCut(graph.state.graph.linkInto(into(node.id))!));
        await pumpEventQueue();

        expect(line(), [
          PipelineNodeIds.recognition,
          PipelineNodeIds.translation,
          PipelineNodeIds.voice,
        ]);
        expect(graph.state.graph.node(node.id)?.feed, isNull);
        expect(packOf('fallout').active, isFalse);

        graph.add(const PipelineGraphUndone());
        await pumpEventQueue();

        expect(graph.state.graph.node(node.id)?.feed, GlossaryFeed.translation);
        expect(packOf('fallout').active, isTrue);
      },
    );

    test('takes out the packs a line from whisper to the translator passes over', () async {
      final node = await place('lines');
      await draw(heard, into(node.id));

      await draw(heard, intoTranslator);

      expect(graph.state.graph.node(node.id)?.feed, isNull);
      expect(packOf('lines').active, isFalse);
    });

    test(
      'switches a pack off on its node and leaves it in the line, the text passing through',
      () async {
        final node = await place('fallout');
        await draw(outOf(node.id), intoVoice);
        expect(repository.glossaries.last.entries, [vault]);

        graph.add(PipelineGlossarySwitched(node.id, active: false));
        await pumpEventQueue();

        final now = graph.state.graph.node(node.id)!;
        expect(now.active, isFalse);
        expect(now.feed, GlossaryFeed.translation, reason: 'a switch moves no drawing');
        expect(line(), [
          PipelineNodeIds.recognition,
          PipelineNodeIds.translation,
          node.id,
          PipelineNodeIds.voice,
        ]);
        expect(packOf('fallout').active, isFalse, reason: 'the glossary screen shows it off too');
        expect(
          repository.glossaries.last.entries,
          isEmpty,
          reason: 'the scheme draws the packs, and with none on nothing is read',
        );
      },
    );

    test('switches a pack back on, and a step back switches it off again', () async {
      final node = await place('fallout');
      await draw(outOf(node.id), intoVoice);
      graph.add(PipelineGlossarySwitched(node.id, active: false));
      await pumpEventQueue();

      graph.add(PipelineGlossarySwitched(node.id, active: true));
      await pumpEventQueue();
      expect(packOf('fallout').active, isTrue);
      expect(graph.state.graph.node(node.id)?.active, isTrue);
      expect(repository.glossaries.last.entries, [vault]);

      graph.add(const PipelineGraphUndone());
      await pumpEventQueue();
      expect(packOf('fallout').active, isFalse);
      expect(graph.state.graph.node(node.id)?.feed, GlossaryFeed.translation);
    });

    test('switches every drawing of the pack together, and no other pack', () async {
      final before = await place('fallout');
      final after = await place('fallout');
      final other = await place('lines');

      graph.add(PipelineGlossarySwitched(after.id, active: true));
      await pumpEventQueue();

      expect(graph.state.graph.node(before.id)?.active, isTrue);
      expect(graph.state.graph.node(other.id)?.active, isFalse);
      expect(
        [before, after].map((node) => graph.state.graph.node(node.id)?.feed),
        [isNull, isNull],
        reason: 'switched on out of the line, it still stands out of it',
      );
    });

    test('leaves a pack where it stands when it is switched on the glossary screen', () async {
      final node = await place('lines');

      cubits.stageGlossary(cubits.glossaryRepository.glossary.activating('lines', active: true));
      await pumpEventQueue();

      expect(graph.state.graph.node(node.id)?.active, isTrue);
      expect(graph.state.graph.node(node.id)?.feed, isNull, reason: 'a switch moves no drawing');
    });

    test('switches nothing for a node that draws no pack, or to what it is already', () async {
      final node = await place('fallout');

      graph.add(PipelineGlossarySwitched(node.id, active: false));
      graph.add(PipelineGlossarySwitched(PipelineNodeIds.voice, active: true));
      await pumpEventQueue();
      expect(cubits.glossaryRepository.glossary.activePacks, isEmpty);

      graph.add(const PipelineGraphUndone());
      await pumpEventQueue();
      expect(
        graph.state.graph.ofKind(PipelineNodeKind.glossary),
        isEmpty,
        reason: 'the step back takes the placing back, there being nothing else to take',
      );
      expect(
        PipelineGlossarySwitched(node.id, active: true),
        isNot(PipelineGlossarySwitched(node.id, active: false)),
      );
    });

    test('reads another pack in the same node, where it stands', () async {
      final node = await place('fallout');
      await draw(outOf(node.id), intoVoice);

      graph.add(PipelineGlossaryPackChosen(node.id, 'lines'));
      await pumpEventQueue();

      final now = graph.state.graph.node(node.id)!;
      expect(now.packId, 'lines');
      expect(now.position, node.position);
      expect(now.feed, GlossaryFeed.translation);
      expect(packOf('lines').active, isTrue);
      expect(packOf('fallout').active, isFalse, reason: 'it stands in the line nowhere now');
    });

    test('takes a pack off the canvas and out of the line with it', () async {
      final node = await place('fallout');
      await draw(outOf(node.id), intoVoice);

      graph.add(PipelineNodeRemoved(node.id));
      await pumpEventQueue();

      expect(graph.state.graph.ofKind(PipelineNodeKind.glossary), isEmpty);
      expect(line(), [
        PipelineNodeIds.recognition,
        PipelineNodeIds.translation,
        PipelineNodeIds.voice,
      ]);
      expect(packOf('fallout').active, isFalse, reason: 'a node deleted takes its work with it');
    });

    test('refuses a line between two packs that both stand out of the line', () async {
      final a = await place('lines');
      final b = await place('fallout');

      await draw(outOf(a.id), into(b.id));

      expect(graph.state.refusal, ConnectionRefusal.outOfLine);
    });

    test('keeps which packs were on with a scheme, and puts those on again', () async {
      final node = await place('fallout');
      await draw(outOf(node.id), intoVoice);
      graph.add(const PipelineSchemeSaved('Fallout'));
      await pumpEventQueue();
      expect(graph.state.schemes.single.activePacks, {'fallout'});

      graph.add(PipelineLinkCut(graph.state.graph.linkInto(into(node.id))!));
      await pumpEventQueue();
      cubits.stageGlossary(cubits.glossaryRepository.glossary.activating('lines', active: true));
      await pumpEventQueue();
      graph.add(PipelineSchemeChosen(graph.state.schemes.single.id));
      await pumpEventQueue();

      expect(packOf('fallout').active, isTrue);
      expect(packOf('lines').active, isFalse, reason: 'the scheme is the whole picture');
      expect(graph.state.graph.node(node.id)?.feed, GlossaryFeed.translation);
    });
  });
}

/// Lets the bloc work through what the gestures added. Events are handled
/// one at a time, and each one may write to the settings or the cast.
Future<void> pumpEvents() => Future<void>.delayed(Duration.zero);

/// The canvas's files and the cast with no disk behind them, and a worker
/// that only listens to what it is told. Each is what one repository reads;
/// they are kept on one object so a test reaches them in one place.
class _GraphRepository extends FakeSessionRepository {
  final cards = MemoryCharacters();
  final engine = TellingEngine();
  final schemes = MemorySchemes();
  final words = MemoryGlossary();

  /// Every glossary a running worker was handed, the part of it in use.
  List<Glossary> get glossaries => engine.glossaries;

  CharacterLibrary get stored => cards.stored;
  set stored(CharacterLibrary value) => cards.stored = value;
  PipelineLayout get layout => schemes.layout;
  set layout(PipelineLayout value) => schemes.layout = value;
  PipelineLibrary get shelf => schemes.shelf;
  set shelf(PipelineLibrary value) => schemes.shelf = value;
  List<(String, List<SavedPipeline>)> get exported => schemes.exported;
  List<SavedPipeline> get incoming => schemes.incoming;
  set incoming(List<SavedPipeline> value) => schemes.incoming = value;

  /// What a running worker was told to read anew, without a restart.
  List<(String, String?)> get told => engine.told;

  /// Every time a running worker was told which cards had left the mix.
  List<Set<String>> get heard => engine.heard;
}

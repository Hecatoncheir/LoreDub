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

  test('a card taken off the canvas keeps the voice that reads it', () async {
    await drawLink(voiceOf('guard'), readBy('smith'));

    graph.add(const PipelineCharacterRemoved('guard'));
    await pumpEvents();

    expect(graph.state.layout.characters, ['smith']);
    expect(repository.stored.characters.first.voicedBy, 'smith');
  });

  test('takes a card off the canvas even while it speaks for another', () async {
    await drawLink(voiceOf('guard'), readBy('smith'));

    graph.add(const PipelineCharacterRemoved('smith'));
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

  @override
  Future<CharacterLibrary> loadCharacters() async => stored;

  @override
  Future<void> saveCharacters(CharacterLibrary library) async => stored = library;

  @override
  Future<PipelineLayout> loadGraphLayout() async => layout;

  @override
  Future<void> saveGraphLayout(PipelineLayout value) async => layout = value;

  @override
  Future<void> voiceCharacterAs(String id, String? target) async {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

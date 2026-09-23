// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lore_dub/src/data/repositories/cast_repository.dart';
import 'package:lore_dub/src/data/repositories/glossary_repository.dart';
import 'package:lore_dub/src/data/repositories/model_repository.dart';
import 'package:lore_dub/src/data/repositories/runtime_repository.dart';
import 'package:lore_dub/src/data/repositories/settings_repository.dart';
import 'package:lore_dub/src/data/repositories/update_repository.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/data/services/model_storage_service.dart';
import 'package:lore_dub/src/data/services/notification_service.dart';
import 'package:lore_dub/src/data/services/runtime_storage_service.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/data/services/update_service.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/character.dart';
import 'package:lore_dub/src/domain/glossary.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/pipeline_graph.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart';
import 'package:lore_dub/src/ui/common/bloc/session_bloc.dart';
import 'package:lore_dub/src/ui/graph/bloc/pipeline_graph_bloc.dart';
import 'package:lore_dub/src/ui/graph/bloc/screen_scheme_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/fakes/fake_session_repository.dart';
import '../../../../support/memory_cast.dart';
import '../../../../support/staged_dashboard.dart';

/// The Screen page's canvas as a script of gestures: the same machine as
/// Эфир's, whose lines write the screen's own settings -- the voices behind
/// it, the language of its text -- and whose arrangement, shelf, cut and
/// glossary are kept for the screen session alone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Files files;
  late StagedDashboard cubits;
  late ScreenSchemeBloc graph;

  const guard = Character(id: 'guard', name: 'Стражник', vector: [0.2, 0.4]);

  const gameAudio = PipelinePort(PipelineNodeIds.source, PipelineSocket.gameAudio);
  const intoDetection = PipelinePort(PipelineNodeIds.detection, PipelineSocket.detectionIn);
  const speaker = PipelinePort(PipelineNodeIds.detection, PipelineSocket.detectedSpeaker);
  const intoVoiceSpeaker = PipelinePort(PipelineNodeIds.voice, PipelineSocket.voiceSpeaker);
  const screenText = PipelinePort(PipelineNodeIds.screen, PipelineSocket.screenText);
  const intoTranslator = PipelinePort(PipelineNodeIds.translation, PipelineSocket.translationIn);
  const intoVoice = PipelinePort(PipelineNodeIds.voice, PipelineSocket.voiceIn);
  const intoTheMix = PipelinePort(PipelineNodeIds.mix, PipelineSocket.mixCast);

  AppSettings settings() => cubits.settingsRepository.settings;

  /// Every package in the catalogue, the converter on disk or not.
  void install({bool converter = true, bool translator = true}) => cubits.stageInstalled(
    models: [
      for (final model in modelCatalog)
        ModelInstallState(
          model: model,
          installed: switch (model.kind) {
            ModelKind.voiceConversion => converter,
            ModelKind.translation => translator,
            _ => true,
          },
        ),
    ],
  );

  Future<void> drawLink(PipelinePort from, PipelinePort to) async {
    graph.add(PipelineLinkStarted(from, GraphPoint.zero));
    graph.add(PipelineLinkReleased(to));
    await pumpEventQueue();
  }

  Future<void> cut(PipelinePort into) async {
    graph.add(PipelineLinkCut(graph.state.graph.linkInto(into)!));
    await pumpEventQueue();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    files = _Files();
    final settingsRepository = SettingsRepository(SettingsService());
    cubits = StagedDashboard(
      files,
      settingsRepository,
      ModelRepository(ModelStorageService()),
      RuntimeRepository(RuntimeStorageService()),
      UpdateRepository(
        UpdateService(
          client: MockClient((_) async => http.Response('offline', 503)),
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
      cast: CastRepository(files.engine, files.cards),
      schemes: files.schemes,
      glossaryRepository: GlossaryRepository(settingsRepository, files.engine, files.words),
    );
    graph = cubits.screenGraph;
    files.cards.stored = const CharacterLibrary(characters: [guard]);
    await cubits.settingsRepository.load();
    await cubits.cast.load();
    install();
    graph.add(const PipelineGraphOpened());
    await pumpEventQueue();
  });

  tearDown(() async => cubits.dispose());

  test('draws the Screen page\'s stages, not Эфир\'s', () {
    final drawn = graph.state.graph;

    expect(drawn.scheme, PipelineScheme.screen);
    expect(drawn.node(PipelineNodeIds.screen), isNotNull);
    expect(drawn.node(PipelineNodeIds.detection), isNotNull);
    expect(drawn.node(PipelineNodeIds.recognition), isNull);
    expect(cubits.graph.state.graph.scheme, PipelineScheme.live, reason: 'Эфир\'s is its own');
  });

  group('the voices behind the screen', () {
    test('are listened for by either line of the detection, and cut by either', () async {
      await drawLink(gameAudio, intoDetection);

      expect(settings().screenVoices, isTrue);
      expect(graph.state.graph.linkInto(intoVoiceSpeaker)?.from, speaker);
      expect(graph.state.refusal, isNull);

      await cut(intoVoiceSpeaker);
      expect(settings().screenVoices, isFalse);
      expect(graph.state.graph.linkInto(intoDetection), isNull);

      await drawLink(intoVoiceSpeaker, speaker);
      expect(settings().screenVoices, isTrue, reason: 'drawn backwards, from the voice');
    });

    test('are the same setting the detection\'s switch throws', () async {
      graph.add(const PipelineVoicesSwitched(heard: true));
      await pumpEventQueue();
      expect(settings().screenVoices, isTrue);
      expect(graph.state.graph.node(PipelineNodeIds.detection)?.active, isTrue);

      graph.add(const PipelineVoicesSwitched(heard: false));
      await pumpEventQueue();
      expect(settings().screenVoices, isFalse);
      expect(graph.state.graph.node(PipelineNodeIds.detection)?.unrouted, isTrue);
    });

    test('are not listened for without the converter that hears them', () async {
      install(converter: false);

      await drawLink(gameAudio, intoDetection);

      expect(settings().screenVoices, isFalse);
      expect(graph.state.refusal, ConnectionRefusal.converterMissing);
    });

    test('stay as they are while a session runs', () async {
      cubits.stageSession(
        const SessionState(status: PipelineStatus.listening, session: PipelineSession.screen),
      );

      graph.add(const PipelineVoicesSwitched(heard: true));
      await pumpEventQueue();

      expect(settings().screenVoices, isFalse);
      expect(graph.state.refusal, ConnectionRefusal.locked);
    });

    test('come back with a step back', () async {
      await drawLink(gameAudio, intoDetection);
      await cut(intoDetection);
      expect(settings().screenVoices, isFalse);

      graph.add(const PipelineGraphUndone());
      await pumpEventQueue();

      expect(settings().screenVoices, isTrue);
    });

    test('leave Эфир\'s way in alone', () async {
      await drawLink(gameAudio, intoDetection);
      await cut(intoDetection);

      expect(settings().captureRouted, isTrue);
    });
  });

  group('the translator', () {
    test('cut, reads the text on the screen as the dubbing language', () async {
      await cut(intoTranslator);

      expect(settings().screenLanguage, 'ru');
      expect(settings().targetLanguage, 'ru', reason: 'the voice stays the one it was');
      expect(graph.state.graph.translates, isFalse);
      expect(graph.state.graph.linkInto(intoVoice)?.from, screenText);
    });

    test('drawn back, reads English into the dubbing language', () async {
      await cubits.settingsRepository.save(settings().copyWith(screenLanguage: 'ru'));
      await pumpEventQueue();

      await drawLink(screenText, intoTranslator);

      expect(settings().screenLanguage, 'en');
      expect(settings().targetLanguage, 'ru');
      expect(graph.state.graph.translates, isTrue);
    });

    test('is not drawn back with no translator on disk', () async {
      await cubits.settingsRepository.save(settings().copyWith(screenLanguage: 'ru'));
      install(translator: false);
      await pumpEventQueue();

      await drawLink(screenText, intoTranslator);

      expect(settings().screenLanguage, 'ru');
      expect(graph.state.refusal, ConnectionRefusal.translatorMissing);
    });
  });

  group('what the canvas keeps', () {
    test('is its own arrangement, beside Эфир\'s', () async {
      graph.add(const PipelineNodeGrabbed(PipelineNodeIds.detection));
      graph.add(const PipelineNodeMoved(PipelineNodeIds.detection, 20, 10));
      graph.add(const PipelineArrangementSettled());
      await pumpEventQueue();

      final moved = PipelineLayout.screenPositions[PipelineNodeIds.detection]!.translate(20, 10);
      expect(files.schemes.screenLayout.positions[PipelineNodeIds.detection], moved);
      expect(files.schemes.layout.positions.containsKey(PipelineNodeIds.detection), isFalse);
    });

    test('is its own shelf, whose schemes say whose they are', () async {
      await drawLink(gameAudio, intoDetection);

      graph.add(const PipelineSchemeSaved('Субтитры'));
      await pumpEventQueue();

      final kept = files.schemes.screenShelf.pipelines.single;
      expect(kept.scheme, PipelineScheme.screen);
      expect(kept.captureRouted, isTrue, reason: 'the voices, which are its route');
      expect(files.schemes.shelf.pipelines, isEmpty);
    });

    test('puts a kept scheme\'s voices back when it is chosen', () async {
      graph.add(const PipelineSchemeSaved('Без голосов'));
      await pumpEventQueue();
      await drawLink(gameAudio, intoDetection);
      expect(settings().screenVoices, isTrue);

      graph.add(PipelineSchemeChosen(graph.state.schemes.single.id));
      await pumpEventQueue();

      expect(settings().screenVoices, isFalse);
    });
  });

  group('what a running session is told', () {
    setUp(() async {
      graph.add(const PipelineCharacterPlaced('guard'));
      await pumpEventQueue();
      files.engine.heard.clear();
    });

    test('is the cut, where the screen session runs', () async {
      files.engine.running = PipelineSession.screen;

      await cut(intoTheMix);

      expect(graph.state.layout.silent, {'guard'});
      expect(files.engine.heard, [
        {'guard'},
      ]);
    });

    test('is nothing, where Эфир\'s session runs', () async {
      files.engine.running = PipelineSession.live;

      await cut(intoTheMix);

      expect(files.engine.heard, isEmpty, reason: 'the dubbing is cut on Эфир\'s canvas');
    });

    test('is what the packs it draws apply, where the screen session runs', () async {
      const vault = GlossaryEntry(kind: GlossaryKind.word, source: 'Хранилище', reading: 'Убежище');
      const fire = GlossaryEntry(
        kind: GlossaryKind.phrase,
        source: 'Fire in the hole!',
        reading: 'Ложись!',
      );
      cubits.stageGlossary(
        Glossary(
          entries: const [vault, fire],
          packs: [
            GlossaryPack(id: 'pack', name: 'Пакет', entryKeys: [vault.packKey, fire.packKey]),
          ],
        ),
      );
      files.engine.running = PipelineSession.screen;
      graph.add(const PipelineGlossaryPlaced('pack'));
      await pumpEventQueue();
      final pack = graph.state.graph.ofKind(PipelineNodeKind.glossary).single;

      await drawLink(screenText, PipelinePort(pack.id, PipelineSocket.glossaryIn));

      expect(cubits.glossaryRepository.glossary.packWithId('pack')!.active, isTrue);
      expect(
        files.engine.glossaries.last.entries,
        [fire],
        reason: 'before the translator, the screen\'s English meets the pack\'s phrases',
      );
    });
  });
}

/// The engine and the files the canvas reads and writes, in memory.
class _Files extends FakeSessionRepository {
  final cards = MemoryCharacters();
  final engine = TellingEngine();
  final schemes = MemorySchemes();
  final words = MemoryGlossary();
}

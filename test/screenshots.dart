// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// Draws the screenshots `README.md` and the landing page show, so a screen
/// that changes does not go on being illustrated by the one it replaced.
///
/// ```powershell
/// flutter test test/screenshots.dart --update-goldens
/// ```
///
/// It is a widget test rather than a running app: the state is staged, so
/// the pictures hold the same cast and the same phrases in both languages
/// and can be drawn again after any change. The name carries no `_test`
/// suffix, so a plain `flutter test` — the run CI makes — passes it by:
/// these are pictures to be looked at, not a golden anyone should have to
/// keep pixel-identical.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, MethodChannel, rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/l10n/app_localizations.dart';
import 'package:lore_dub/src/data/repositories/app_repository.dart';
import 'package:lore_dub/src/data/repositories/model_repository.dart';
import 'package:lore_dub/src/data/repositories/runtime_repository.dart';
import 'package:lore_dub/src/data/repositories/update_repository.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/data/services/model_storage_service.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:lore_dub/src/data/services/notification_service.dart';
import 'package:lore_dub/src/data/services/runtime_storage_service.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/data/services/update_service.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/app_release.dart';
import 'package:lore_dub/src/domain/character.dart';
import 'package:lore_dub/src/domain/game_process.dart';
import 'package:lore_dub/src/domain/glossary.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/ocr_region.dart';
import 'package:lore_dub/src/domain/pipeline_graph.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart';
import 'package:lore_dub/src/domain/saved_pipeline.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/characters_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/dashboard_cubits.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/glossary_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/downloads_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/pipeline_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/pipeline_graph_bloc.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/settings_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/shell_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/dashboard_view.dart';
import 'package:lore_dub/src/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The size the pictures have always been kept at, and the one the page and
/// the readme lay out for.
const shot = Size(1400, 920);

/// The cast the pictures are drawn with: a name in each language, so the
/// Russian and the English picture say the same thing.
const cast = {
  'ru': [
    Character(id: 'guard', name: 'Стражник', vector: [0.2, 0.4], seconds: 2.4, gender: 'male'),
    Character(
      id: 'smith',
      name: 'Кузнец',
      vector: [0.1, 0.9],
      seconds: 3.1,
      gender: 'male',
      voicedBy: 'guard',
    ),
    Character(
      id: 'herbalist',
      name: 'Травница',
      vector: [0.7, 0.3],
      seconds: 4.2,
      gender: 'female',
    ),
  ],
  'en': [
    Character(id: 'guard', name: 'Guard', vector: [0.2, 0.4], seconds: 2.4, gender: 'male'),
    Character(
      id: 'smith',
      name: 'Smith',
      vector: [0.1, 0.9],
      seconds: 3.1,
      gender: 'male',
      voicedBy: 'guard',
    ),
    Character(
      id: 'herbalist',
      name: 'Herbalist',
      vector: [0.7, 0.3],
      seconds: 4.2,
      gender: 'female',
    ),
  ],
};

/// One pack, so the picture shows what a set of cards passed on in a single
/// file looks like.
const packs = {
  'ru': [
    CharacterPack(id: 'port', name: 'Старый порт', characterIds: ['guard', 'smith']),
  ],
  'en': [
    CharacterPack(id: 'port', name: 'The old harbour', characterIds: ['guard', 'smith']),
  ],
};

/// What the player of the pictures has written down: one idiom the model
/// takes literally, and one name it leaves in Latin script.
const glossaryRu = Glossary(
  entries: [
    GlossaryEntry(
      kind: GlossaryKind.phrase,
      source: 'Fire in the hole!',
      reading: '\u041b\u043e\u0436\u0438\u0441\u044c!',
    ),
    GlossaryEntry(
      kind: GlossaryKind.phrase,
      source: 'Watch your six.',
      reading: '\u0421\u0437\u0430\u0434\u0438!',
    ),
    GlossaryEntry(
      kind: GlossaryKind.name,
      source: 'Hollowvale',
      reading: '\u0425\u043e\u043b\u043b\u043e\u0443\u0432\u0435\u0439\u043b',
    ),
  ],
);

const glossaryEn = Glossary(
  entries: [
    GlossaryEntry(
      kind: GlossaryKind.phrase,
      source: 'Fire in the hole!',
      reading: 'Take cover, grenade!',
    ),
    GlossaryEntry(
      kind: GlossaryKind.phrase,
      source: 'Watch your six.',
      reading: 'Behind you!',
    ),
    GlossaryEntry(kind: GlossaryKind.name, source: 'Hollowvale', reading: 'Hollow Vale'),
  ],
);

/// Where the game of the pictures writes its subtitles: a band across the
/// lower middle of the window, clear of the quest in the corner.
const subtitles = AppSettings(
  ocrRegion: OcrRegion(left: 0.12, top: 0.74, right: 0.88, bottom: 0.95),
);

/// The game the pictures are taken over: a name of nobody's, so no real
/// title is put in a place that would read as an endorsement.
const game = GameProcess(pid: 8124, name: 'HollowVale.exe', path: r'D:\Games\HollowVale.exe');

/// What the transcript reads in the picture: the original above, the dubbing
/// under it.
const lines = {
  'ru': [
    (
      'That armor will not stop an arrow.',
      'Эта броня не остановит стрелу.',
      'character:guard',
      1673,
    ),
    ('Archers on the wall.', 'Лучники на стене.', 'character:smith', 1563),
  ],
  'en': [
    (
      'That armor will not stop an arrow.',
      'Diese Rüstung hält keinen Pfeil auf.',
      'character:guard',
      1673,
    ),
    ('Archers on the wall.', 'Bogenschützen auf der Mauer.', 'character:smith', 1563),
  ],
};

/// What the snippet screen has been asked to read: a quest and a line of a
/// letter, the kind of text a game leaves on the screen rather than speaks.
const snippets = {
  'ru': [
    (
      'Return to the harbour before the tide turns.',
      'Вернитесь в гавань, пока не сменился прилив.',
    ),
    ('The seal is broken. Read it alone.', 'Печать сломана. Прочтите его в одиночестве.'),
  ],
  'en': [
    (
      'Kehre zum Hafen zurück, ehe die Flut wechselt.',
      'Return to the harbour before the tide turns.',
    ),
    ('Das Siegel ist gebrochen. Lies ihn allein.', 'The seal is broken. Read it alone.'),
  ],
};

/// The voices the session has heard, as the scene list shows them: two of
/// the player's own cards — one of them read by the other, the way the
/// graph was drawn — and one the game's bank founded by itself.
const heard = [
  SceneSpeaker(
    key: 'character:guard',
    line: 'That armor will not stop an arrow.',
    lines: 12,
    seconds: 2.4,
  ),
  SceneSpeaker(key: 'character:smith', line: 'Archers on the wall.', lines: 5, seconds: 1.8),
  SceneSpeaker(key: 'timbre:2', line: 'The gate holds until dawn.', lines: 3, seconds: 1.2),
];

/// Nothing here reaches the network or the notification centre.
final http.Client _offline = MockClient((_) async => http.Response('offline', 503));
final FlutterLocalNotificationsPlugin _silent = FlutterLocalNotificationsPlugin();

/// The sidebar reads the version off the platform, which a test has none of.
void nameTheVersion() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/package_info'),
    (call) async => <String, String>{
      'appName': 'LoreDub',
      'packageName': 'com.loredub.LoreDub',
      'version': '0.15.0',
      'buildNumber': '20',
    },
  );
}

/// A widget test draws text as boxes, and icons as empty squares, until the
/// real faces are loaded. The manifest carries them all — the three of the
/// interface and the Material icons with them.
Future<void> loadFonts() async {
  final manifest = (json.decode(await rootBundle.loadString('FontManifest.json')) as List<Object?>)
      .cast<Map<String, Object?>>();
  for (final family in manifest) {
    final loader = FontLoader(family['family']! as String);
    for (final font in (family['fonts']! as List<Object?>).cast<Map<String, Object?>>()) {
      loader.addFont(rootBundle.load(font['asset']! as String));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(loadFonts);
  setUp(nameTheVersion);

  DashboardCubits buildCubits() {
    SharedPreferences.setMockInitialValues({});
    final cubits = DashboardCubits(
      AppRepository(NativeEngineService(), SettingsService()),
      ModelRepository(ModelStorageService()),
      RuntimeRepository(RuntimeStorageService()),
      UpdateRepository(UpdateService(client: _offline), NotificationService(plugin: _silent)),
    );
    addTearDown(cubits.dispose);
    return cubits;
  }

  /// Draws [cubits] at the size the pictures are kept at and writes the
  /// frame to `docs/screenshots/<name>-<language>.png`.
  Future<void> shoot(
    WidgetTester tester,
    DashboardCubits cubits,
    String name,
    String language, {
    double scroll = 0,
  }) async {
    tester.view.physicalSize = shot;
    tester.view.devicePixelRatio = 1;
    // The window stands on a monitor, not on the window: the frame over the
    // game is drawn in the shape of the screen it would be read from.
    tester.view.display.size = const Size(1920, 1080);
    tester.view.display.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.display.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildLoreDubTheme(),
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: DashboardView(cubits: cubits),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    if (scroll != 0) {
      // Taken by the empty right margin of the page, which carries no slider
      // a drag could move instead.
      await tester.dragFrom(const Offset(1350, 700), Offset(0, -scroll));
      await tester.pumpAndSettle();
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../docs/screenshots/$name-$language.png'),
    );
  }

  /// A machine that has downloaded what it dubs with — one recognition
  /// build, the pair of the language it dubs into, and the converter that
  /// carries a timbre — rather than every language at once.
  List<ModelInstallState> catalogue(String language) => [
    for (final model in modelCatalog)
      ModelInstallState(
        model: model,
        installed: model.language == null
            ? model.id == 'whisper-small' || model.kind == ModelKind.voiceConversion
            : model.language == (language == 'ru' ? 'ru' : 'de'),
      ),
  ];

  DashboardCubits stage(
    String language, {
    required DashboardSection section,
    AppSettings settings = const AppSettings(),
    PipelineStatus status = PipelineStatus.idle,
    PipelineSession session = PipelineSession.live,
    List<TranscriptEntry> transcript = const [],
    List<SceneSpeaker> speakers = const [],
    List<TranscriptEntry> snapshots = const [],
    List<CastPlacement> placed = const [],
    Glossary glossary = Glossary.empty,
    Map<String, GraphPoint> where = const {},
    String? chosen,
  }) {
    final cubits = buildCubits();
    cubits.shell.seed(
      ShellState(
        section: section,
        initializing: false,
        updates: const UpdateState(currentVersion: '0.15.0'),
      ),
    );
    cubits.settings.seed(
      SettingsState(
        settings: settings.copyWith(
          interfaceLanguage: language,
          whisperModel: 'whisper-small',
          targetLanguage: language == 'ru' ? 'ru' : 'de',
          sourceLanguage: 'en',
          detectSourceLanguage: false,
          originalVoice: true,
          voiceBank: true,
        ),
      ),
    );
    cubits.downloads.seed(DownloadsState(models: catalogue(language)));
    cubits.pipeline.seed(
      LivePipelineState(
        status: status,
        session: session,
        transcript: transcript,
        speakers: speakers,
        snapshots: snapshots,
        processes: const [game],
        selectedProcess: game,
      ),
    );
    cubits.glossary.seed(GlossaryState(glossary: glossary, loaded: true));
    cubits.characters.seed(
      CharactersState(
        loading: false,
        characters: cast[language]!,
        packs: packs[language]!,
        clips: const {'guard', 'smith', 'herbalist'},
      ),
    );
    cubits.graph.seed(
      PipelineGraphState(
        loading: false,
        // Two kept schemes on the shelf, so the pictures on their cards are
        // in the screenshot the readme shows.
        schemes: [
          SavedPipeline(
            id: 's1',
            name: language == 'ru' ? 'Вечер в таверне' : 'An evening at the inn',
            layout: PipelineLayout(
              cast: placed,
              positions: {...PipelineLayout.standardPositions, ...where},
            ),
            readers: const {'smith': 'guard'},
          ),
          SavedPipeline(
            id: 's2',
            name: language == 'ru' ? 'Весь звук системы' : 'The whole output',
            layout: PipelineLayout.standard,
          ),
        ],
        // The node the panel is open on, where a shot wants one.
        selected: chosen,
        chosen: {?chosen},
        layout: PipelineLayout(
          cast: placed,
          // Placed by hand, so the wire runs the way the signal does: the
          // card whose part is handed on to the left of the card that reads
          // it, and the copy that takes the part next to the part itself.
          positions: {...PipelineLayout.standardPositions, ...where},
        ),
      ),
    );
    return cubits;
  }

  for (final language in ['ru', 'en']) {
    testWidgets('the graph, in $language', (tester) async {
      // The smith's part is read by the guard, whose card is drawn twice:
      // once among the voices the game speaks, and once beside the smith,
      // where it takes that part over. The copy is not one of the game's
      // own voices, so no dashed line reaches it.
      const copy = 'character:guard#2';
      await shoot(
        tester,
        stage(
          language,
          section: DashboardSection.pipeline,
          placed: [
            CastPlacement.of('smith'),
            const CastPlacement(nodeId: copy, characterId: 'guard', heard: false),
            CastPlacement.of('guard'),
          ],
          where: {
            PipelineNodeIds.character('smith'): PipelineLayout.castPlace(0),
            copy: PipelineLayout.castPlace(1),
            PipelineNodeIds.character('guard'): PipelineLayout.castPlace(2),
          },
        ),
        'pipeline',
        language,
      );
    });

    testWidgets('the node panel, in $language', (tester) async {
      // The same scheme with a card chosen, which is what the panel is
      // drawn from: it stands down the right edge in that card's own
      // colours, with that card's icon in its head.
      const copy = 'character:guard#2';
      await shoot(
        tester,
        stage(
          language,
          section: DashboardSection.pipeline,
          placed: [
            CastPlacement.of('smith'),
            const CastPlacement(nodeId: copy, characterId: 'guard', heard: false),
            CastPlacement.of('guard'),
          ],
          where: {
            PipelineNodeIds.character('smith'): PipelineLayout.castPlace(0),
            copy: PipelineLayout.castPlace(1),
            PipelineNodeIds.character('guard'): PipelineLayout.castPlace(2),
          },
          chosen: PipelineNodeIds.character('guard'),
        ),
        'inspector',
        language,
      );
    });

    testWidgets('the cast, in $language', (tester) async {
      await shoot(
        tester,
        stage(language, section: DashboardSection.characters),
        'characters',
        language,
      );
    });

    testWidgets('the glossary, in $language', (tester) async {
      await shoot(
        tester,
        stage(
          language,
          section: DashboardSection.glossary,
          glossary: language == 'ru' ? glossaryRu : glossaryEn,
        ),
        'glossary',
        language,
      );
    });

    testWidgets('the models, in $language', (tester) async {
      await shoot(tester, stage(language, section: DashboardSection.models), 'models', language);
    });

    testWidgets('the settings, in $language', (tester) async {
      await shoot(
        tester,
        stage(language, section: DashboardSection.settings),
        'settings',
        language,
      );
    });

    testWidgets('the snippet, in $language', (tester) async {
      await shoot(
        tester,
        stage(
          language,
          section: DashboardSection.snapshot,
          snapshots: [
            for (final snippet in snippets[language]!)
              TranscriptEntry(
                original: snippet.$1,
                english: snippet.$1,
                translated: snippet.$2,
                latency: const Duration(milliseconds: 940),
              ),
          ],
        ),
        'snapshot',
        language,
      );
    });

    testWidgets('the screen read, in $language', (tester) async {
      await shoot(
        tester,
        stage(
          language,
          section: DashboardSection.snapshot,
          settings: subtitles,
          status: PipelineStatus.listening,
          session: PipelineSession.screen,
          transcript: [
            for (final snippet in snippets[language]!)
              TranscriptEntry(
                original: snippet.$1,
                english: snippet.$1,
                translated: snippet.$2,
                latency: const Duration(milliseconds: 910),
              ),
          ],
          snapshots: [
            for (final snippet in snippets[language]!.take(1))
              TranscriptEntry(
                original: snippet.$1,
                english: snippet.$1,
                translated: snippet.$2,
                latency: const Duration(milliseconds: 940),
              ),
          ],
        ),
        'ocr-live',
        language,
      );
    });

    testWidgets('live, in $language', (tester) async {
      await shoot(
        tester,
        stage(
          language,
          section: DashboardSection.live,
          status: PipelineStatus.listening,
          speakers: heard,
          transcript: [
            for (final line in lines[language]!)
              TranscriptEntry(
                original: line.$1,
                english: line.$1,
                translated: line.$2,
                latency: Duration(milliseconds: line.$4),
                speaker: line.$3,
              ),
          ],
        ),
        'live',
        language,
      );
    });
  }
}

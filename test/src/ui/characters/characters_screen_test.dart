// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// The characters screen: the cards, the packs and what is dropped on them.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/character.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart' show PipelineStatus;
import 'package:lore_dub/src/domain/sound_files.dart';
import 'package:lore_dub/src/ui/characters/character_pack_area.dart';
import 'package:lore_dub/src/ui/characters/character_tile.dart';
import 'package:lore_dub/src/ui/characters/bloc/cast_bloc.dart';
import 'package:lore_dub/src/ui/shell/bloc/navigation_cubit.dart';
import 'package:lore_dub/src/ui/common/bloc/session_bloc.dart';
import 'package:lore_dub/src/ui/characters/bloc/voice_capture_bloc.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/dashboard_harness.dart';
import '../../../support/mock_blocs.dart';
import '../../../support/staged_dashboard.dart';

void main() {
  // What `captureAny` stands in with before anything is captured.
  setUpAll(registerEventFallbacks);

  group('the characters screen', () {
    const guard = Character(
      id: 'a1',
      name: 'Стражник',
      vector: [0.2, 0.4],
      gender: 'male',
      seconds: 2.5,
    );

    /// The screen over the cards and the capture a test says there are.
    /// What a press does is the blocs' (`cast_bloc_test.dart`,
    /// `voice_capture_bloc_test.dart`); what is looked at here is what the
    /// screen draws and which event a press sends.
    StagedDashboard stageCast({
      CastState cast = const CastState(loading: false),
      VoiceCaptureState capture = const VoiceCaptureState(),
      AppSettings settings = const AppSettings(),
    }) => stage(
      buildCubits(
        cast: castShowing(cast),
        capture: captureShowing(capture, carriesTimbre: settings.originalVoice),
      ),
      section: DashboardSection.characters,
      settings: settings,
      models: catalogue(),
    );

    testWidgets('sits before Settings and says how a voice is recorded', (tester) async {
      await pumpDashboard(tester, stageCast(), const Size(1280, 900));

      expect(find.text('03  /  СОСТАВ ПЕРСОНАЖЕЙ'), findsOneWidget);
      expect(find.text('Голоса персонажей'), findsOneWidget);
      expect(find.textContaining('Пока ни одного персонажа'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Запустить запись'), findsOneWidget);
    });

    testWidgets('keeps a full card inside its tile', (tester) async {
      // Name, what was recorded, whose voice reads it, and the packs it is
      // in — all at once, in a window narrow enough for the lines to wrap.
      await pumpDashboard(
        tester,
        stageCast(
          cast: const CastState(
            loading: false,
            characters: [
              Character(
                id: 'a1',
                name: 'Скарн',
                vector: [0.2, 0.4],
                gender: 'male',
                seconds: 6,
                voicedBy: 'b2',
              ),
              Character(id: 'b2', name: 'Кайра', vector: [0.3], gender: 'female', seconds: 4.8),
            ],
            packs: [
              CharacterPack(id: 'p1', name: 'Старый порт', characterIds: ['a1', 'b2']),
            ],
          ),
        ),
        const Size(1000, 900),
      );

      expect(tester.takeException(), isNull, reason: 'the tile holds its own content');
    });

    testWidgets('holds it at the narrowest window the app opens in', (tester) async {
      await pumpDashboard(
        tester,
        stageCast(
          cast: const CastState(
            loading: false,
            characters: [
              Character(
                id: 'a1',
                name: 'Персонаж с очень длинным именем',
                vector: [0.2, 0.4],
                gender: 'female',
                seconds: 12,
                voicedBy: 'b2',
              ),
              Character(id: 'b2', name: 'Кузнец', vector: [0.3], gender: 'male', seconds: 4),
            ],
            packs: [
              CharacterPack(id: 'p1', name: 'Таверна', characterIds: ['a1']),
              CharacterPack(id: 'p2', name: 'Рынок', characterIds: ['a1']),
            ],
          ),
        ),
        const Size(960, 640),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('shows what a card holds and waits for the session', (tester) async {
      await pumpDashboard(
        tester,
        stageCast(cast: const CastState(loading: false, characters: [guard])),
        const Size(1280, 900),
      );

      expect(find.text('Стражник'), findsOneWidget);
      expect(find.textContaining('Голос записан'), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.mic_rounded)).onPressed,
        isNull,
        reason: 'nothing is listening yet',
      );
    });

    testWidgets('records into a card once the session runs', (tester) async {
      final cubits = stageCast(
        cast: const CastState(loading: false, characters: [guard]),
        capture: const VoiceCaptureState(status: PipelineStatus.listening),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      final record = find.widgetWithIcon(IconButton, Icons.mic_rounded);
      expect(tester.widget<IconButton>(record).onPressed, isNotNull);

      await tester.tap(record);
      await tester.pumpAndSettle();

      verify(() => cubits.voices.add(const RecordingStarted('a1'))).called(1);
    });

    testWidgets('counts a take as it runs, and stops it by the same button', (tester) async {
      final cubits = stageCast(
        cast: const CastState(loading: false, characters: [guard]),
        capture: const VoiceCaptureState(
          status: PipelineStatus.listening,
          busy: {CardActivity.recording: 'a1'},
          heardSeconds: 3,
        ),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      // The take runs until it is stopped, so the card counts it rather than
      // saying only that something is going on.
      expect(find.textContaining('Записано'), findsOneWidget);

      // A take runs until it is stopped, so the test stops it — as the
      // player would, by the button that is now a square.
      await tester.tap(find.widgetWithIcon(IconButton, Icons.stop_rounded));
      await tester.pumpAndSettle();

      verify(() => cubits.voices.add(const RecordingStopped())).called(1);
    });

    testWidgets('makes a pack and says a card can be dropped into it', (tester) async {
      final cubits = stageCast(
        cast: const CastState(loading: false, characters: [guard]),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.textContaining('Пакетов пока нет'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('packsAdd')));
      await tester.pumpAndSettle();

      verify(() => cubits.cards.add(const PackAdded('Новый пакет'))).called(1);
    });

    testWidgets('says who reads a card, and leaves the setting to the graph', (tester) async {
      final cubits = stageCast(
        cast: const CastState(
          loading: false,
          characters: [
            Character(id: 'a1', name: 'Стражник', vector: [0.2], voicedBy: 'b2'),
            Character(id: 'b2', name: 'Кузнец', vector: [0.3]),
          ],
        ),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.text('Звучит как «Кузнец»'), findsOneWidget);
      // One scheme decides who speaks for whom. The card says what it is;
      // the graph is where it is drawn.
      expect(find.byKey(const ValueKey('voiceAs-a1')), findsNothing);
      expect(find.byIcon(Icons.published_with_changes_rounded), findsNothing);
    });

    testWidgets('turns the play button into a stop while a clip sounds', (tester) async {
      final cubits = stageCast(
        cast: const CastState(loading: false, characters: [guard]),
        capture: const VoiceCaptureState(clips: {'a1'}, busy: {CardActivity.playing: 'a1'}),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      // A recording may run for three minutes, so the button that started it
      // is the one that ends it.
      expect(find.byTooltip('Остановить воспроизведение'), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.descendant(
                of: find.byKey(const ValueKey('playClip-a1')),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNotNull,
        reason: 'the same button ends it',
      );
    });

    testWidgets('says on the button when a sample carries no timbre', (tester) async {
      // Without Original voice the dubbing reads every card in a plain
      // synthesized voice, and a sample that sounds like nobody in
      // particular is exactly right — so the button says why beforehand.
      final plain = stageCast(
        cast: const CastState(loading: false, characters: [guard]),
      );
      await pumpDashboard(tester, plain, const Size(1280, 900));

      expect(find.byTooltip('Послушать голос озвучки'), findsNothing);
      expect(
        find.byTooltip(
          'Послушать голос озвучки. Тембр персонажа не переносится: включите «Голос оригинала» '
          'на экране «Модели», иначе персонажа читает обычный голос синтеза',
        ),
        findsOneWidget,
      );

      final cloning = stageCast(
        cast: const CastState(loading: false, characters: [guard]),
        settings: const AppSettings(originalVoice: true),
      );
      await pumpDashboard(tester, cloning, const Size(1280, 900));

      expect(find.byTooltip('Послушать голос озвучки'), findsOneWidget);
    });

    testWidgets('holds the sample and the files back while dubbing runs', (tester) async {
      final cubits = stageCast(
        cast: const CastState(loading: false, characters: [guard]),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      IconButton sample() => tester.widget<IconButton>(
        find.descendant(
          of: find.byKey(const ValueKey('previewVoice-a1')),
          matching: find.byType(IconButton),
        ),
      );
      CharacterTile card() => tester.widget<CharacterTile>(find.byType(CharacterTile));

      expect(sample().onPressed, isNotNull);
      expect(card().actions.onFilesDropped, isNotNull);

      // One engine serves one session. Either of the two brings up a worker
      // of its own, and over a session that is dubbing it took that one's:
      // the capture went on, and every phrase after it failed.
      cubits.stageSession(const SessionState(status: PipelineStatus.listening));
      await tester.pump();
      await tester.pump();

      expect(sample().onPressed, isNull);
      expect(card().actions.onFilesDropped, isNull);
      // Said in so many words, rather than sending the player after a speech
      // model they already have.
      expect(find.byTooltip('Голос нельзя послушать, пока идёт озвучка'), findsOneWidget);
      expect(
        find.byTooltip('Нужна модель озвучки: загрузите её на экране «Модели»'),
        findsNothing,
      );

      // Stopped, and both are back.
      cubits.stageSession(const SessionState());
      await tester.pump();
      await tester.pump();

      expect(sample().onPressed, isNotNull);
      expect(card().actions.onFilesDropped, isNotNull);
    });

    testWidgets('puts the packs beside the cast, and under it in a narrow window', (
      tester,
    ) async {
      final cubits = stageCast(
        cast: const CastState(
          loading: false,
          characters: [guard],
          packs: [CharacterPack(id: 'p1', name: 'Таверна')],
        ),
      );
      await pumpDashboard(tester, cubits, const Size(1400, 900));

      // An empty pack says what it is for.
      expect(find.textContaining('Перетащите сюда'), findsOneWidget);

      final cast = tester.getRect(find.byType(CharacterTile));
      final packs = tester.getRect(find.byType(CharacterPackArea));
      expect(
        packs.left,
        greaterThan(cast.right),
        reason: 'a card is carried across to the pack rather than down a scroll',
      );
      expect(
        (packs.top - cast.top).abs(),
        lessThan(200),
        reason: 'and both ends of the journey are in sight at once',
      );

      // A window too narrow for two columns puts them back one under the
      // other, where the drag is longer but possible.
      await pumpDashboard(tester, cubits, const Size(840, 900));

      expect(
        tester.getRect(find.byType(CharacterPackArea)).top,
        greaterThan(tester.getRect(find.byType(CharacterTile)).top),
      );
    });

    testWidgets('drops a card into a pack and takes it back out', (tester) async {
      final cubits = stageCast(
        cast: const CastState(
          loading: false,
          characters: [guard],
          packs: [CharacterPack(id: 'p1', name: 'Таверна')],
        ),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      final card = find.byType(CharacterTile);
      final pack = find.byType(CharacterPackArea);
      final distance = tester.getCenter(pack) - tester.getCenter(card);
      await tester.timedDrag(card, distance, const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      verify(() => cubits.cards.add(const CardPacked('p1', 'a1'))).called(1);
    });

    testWidgets('takes a card out of a pack by the cross on it', (tester) async {
      final cubits = stageCast(
        cast: const CastState(
          loading: false,
          characters: [guard],
          packs: [
            CharacterPack(id: 'p1', name: 'Таверна', characterIds: ['a1']),
          ],
        ),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      await tester.tap(find.byTooltip('Убрать из пакета'));
      await tester.pumpAndSettle();

      verify(() => cubits.cards.add(const CardUnpacked('p1', 'a1'))).called(1);
    });

    testWidgets('keeps saving and throwing away a card behind its menu', (tester) async {
      final cubits = stageCast(
        cast: const CastState(loading: false, characters: [guard]),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      // Neither of the two is a further unlabelled icon beside the
      // microphone, where delete sat a slip away from record.
      expect(find.text('Удалить персонажа'), findsNothing);

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Сохранить карточку в файл'), findsOneWidget);

      await tester.tap(find.text('Удалить персонажа'));
      await tester.pumpAndSettle();
      expect(find.text('Удалить персонажа?'), findsOneWidget);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      verifyNever(() => cubits.cards.add(const CardRemoved('a1')));
    });
  });

  testWidgets('takes only sound out of what is dropped on a card', (tester) async {
    // Windows decodes what it can play, so a card takes the game's own
    // ogg and an mp3 beside it; a folder or a screenshot dropped by
    // mistake is left where it was.
    expect(
      soundAmong(const [
        r'C:\game\vo\guard_01.OGG',
        r'C:\music\theme.mp3',
        r'C:\shots\screen.png',
        r'C:\game\vo',
      ]),
      [
        r'C:\game\vo\guard_01.OGG',
        r'C:\music\theme.mp3',
      ],
    );
  });
}

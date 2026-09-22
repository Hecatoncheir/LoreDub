// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// The models screen: recognition, the languages and the downloads.

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart' show PipelineStatus;
import 'package:lore_dub/src/ui/models/bloc/downloads_bloc.dart';
import 'package:lore_dub/src/ui/shell/bloc/navigation_cubit.dart';
import 'package:lore_dub/src/ui/settings/bloc/settings_bloc.dart';
import 'package:lore_dub/src/ui/theme.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/dashboard_harness.dart';
import '../../../support/mock_blocs.dart';
import '../../../support/staged_dashboard.dart';

void main() {
  // What `captureAny` stands in with before anything is captured.
  setUpAll(registerEventFallbacks);

  testWidgets('splits the models screen into recognition, languages and the converter', (
    tester,
  ) async {
    final cubits = stage(
      buildCubits(),
      section: DashboardSection.models,
      models: catalogue(installed: false),
    );
    await pumpDashboard(tester, cubits, const Size(1280, 900));

    expect(find.text('РАСПОЗНАВАНИЕ РЕЧИ'), findsOneWidget);
    expect(find.text('base'), findsOneWidget, reason: 'the whisper builds are bars on a chart');

    // The tiles sit below the fold of a lazy list.
    await tester.scrollUntilVisible(find.text('ЯЗЫКИ ОЗВУЧКИ'), 400, scrollable: modelsScroller());
    expect(find.text('ЯЗЫКИ ОЗВУЧКИ'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('ГОЛОС ОРИГИНАЛА'),
      400,
      scrollable: modelsScroller(),
    );
    expect(find.text('ГОЛОС ОРИГИНАЛА'), findsOneWidget);
    final selection = cubits.selection;
    expect(selection.recognitionModels.length, greaterThan(1), reason: 'the model is a choice');
    expect(selection.languagePairs.map((pair) => pair.language), ['ru', 'en']);
  });

  group('the language tiles', () {
    Future<StagedDashboard> pumpTiles(
      WidgetTester tester, {
      List<ModelInstallState>? models,
      AppSettings settings = const AppSettings(),
      PipelineStatus status = PipelineStatus.idle,
    }) async {
      final rows = models ?? catalogue();
      final cubits = stage(
        buildCubits(downloads: downloadsShowing(DownloadsState(models: rows))),
        section: DashboardSection.models,
        settings: settings,
        models: rows,
        status: status,
      );
      await pumpDashboard(tester, cubits, const Size(1280, 1000));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('languageTile-ru')),
        300,
        scrollable: modelsScroller(),
      );
      await tester.pumpAndSettle();
      return cubits;
    }

    Finder tile(String language) => find.byKey(ValueKey('languageTile-$language'));
    Finder on(String language, Finder what) => find.descendant(of: tile(language), matching: what);

    testWidgets('holds a translator and a voice in one tile, for Russian alone', (tester) async {
      await pumpTiles(tester);

      expect(find.byKey(const ValueKey('languageTile-de')), findsNothing);
      expect(on('ru', find.text('Русский')), findsOneWidget);
      expect(on('ru', find.text('перевод')), findsOneWidget);
      expect(on('ru', find.text('голос')), findsOneWidget);
      expect(on('ru', find.byTooltip('Удалить')), findsOneWidget);
    });

    testWidgets('offers the pair for download while it is missing', (tester) async {
      await pumpTiles(tester, models: catalogue(missingLanguage: 'ru'));

      expect(on('ru', find.byTooltip('Скачать')), findsOneWidget);
      expect(on('ru', find.byTooltip('Удалить')), findsNothing);
    });

    testWidgets('marks the language in use dark', (tester) async {
      await pumpTiles(tester);

      final face = tester
          .widget<Material>(find.descendant(of: tile('ru'), matching: find.byType(Material)).first)
          .color;
      expect(face, LoreDubPalette.graphite);
    });

    testWidgets('shows a pair downloading as one ring with its controls', (tester) async {
      final translation = translationModelFor('ru')!;
      final speech = speechModelFor('ru')!;
      await pumpTiles(
        tester,
        models: [
          for (final model in modelCatalog)
            model.id == speech.id
                ? ModelInstallState(model: model, progress: 0.5)
                : ModelInstallState(model: model, installed: true),
        ],
      );

      final share =
          (translation.downloadBytes + speech.downloadBytes * 0.5) /
          (translation.downloadBytes + speech.downloadBytes);
      expect(on('ru', find.text('${(share * 100).round()}%')), findsOneWidget);
      expect(on('ru', find.byTooltip('Приостановить')), findsOneWidget);
      expect(on('ru', find.byTooltip('Отменить')), findsOneWidget);
      expect(on('ru', find.byTooltip('Удалить')), findsNothing, reason: 'not while it downloads');
    });

    testWidgets('asks before deleting a language', (tester) async {
      final cubits = await pumpTiles(tester);

      await tester.tap(on('ru', find.byTooltip('Удалить')));
      await tester.pumpAndSettle();
      expect(find.text('Удалить язык?'), findsOneWidget);
      expect(find.textContaining('языка «Русский»'), findsOneWidget);

      await tester.tap(find.text('Оставить'));
      await tester.pumpAndSettle();
      verifyNever(() => cubits.downloads.add(any<DownloadsEvent>()));
    });

    testWidgets('keeps the language in use while dubbing runs', (tester) async {
      await pumpTiles(tester, status: PipelineStatus.listening);

      final locked = on('ru', find.byTooltip('Выбранную модель нельзя удалить, пока идёт озвучка'));
      expect(locked, findsOneWidget);
      expect(
        // The button builds its tooltip inside itself.
        tester
            .widget<IconButton>(find.ancestor(of: locked, matching: find.byType(IconButton)))
            .onPressed,
        isNull,
      );
    });

    testWidgets('draws the converter as a tile in use with the original voice', (tester) async {
      await pumpTiles(tester, settings: const AppSettings().withVoiceMode(VoiceMode.original));
      final converter = find.byKey(const ValueKey('converterTile-$voiceConverterModelId'));
      await tester.scrollUntilVisible(converter, 300, scrollable: modelsScroller());
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: converter, matching: find.text('конвертер голоса')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Material>(find.descendant(of: converter, matching: find.byType(Material)).first)
            .color,
        LoreDubPalette.graphite,
      );
    });
  });

  testWidgets('needs only the pair of the chosen language', (tester) async {
    final cubits = stage(
      buildCubits(),
      models: [
        for (final model in modelCatalog)
          ModelInstallState(
            model: model,
            installed: model.language == null || model.language == 'ru',
          ),
      ],
    );
    await pumpDashboard(tester, cubits, const Size(1280, 720));

    expect(cubits.settings.settings.targetLanguage, 'ru');
    expect(cubits.selection.requiredModelsInstalled, isTrue);

    cubits.settings.add(const TargetLanguageChosen('de'));
    await tester.pump();

    expect(
      cubits.selection.requiredModelsInstalled,
      isFalse,
      reason: 'the German pair has not been downloaded',
    );
  });

  group('stopping a download from the interface', () {
    Future<StagedDashboard> pumpDownloading(
      WidgetTester tester, {
      required bool paused,
    }) async {
      final whisper = modelCatalog.firstWhere((model) => model.kind == ModelKind.recognition);
      final rows = [
        for (final model in modelCatalog)
          ModelInstallState(
            model: model,
            progress: model.id == whisper.id ? 0.42 : null,
            paused: model.id == whisper.id && paused,
          ),
      ];
      final cubits = stage(
        buildCubits(downloads: downloadsShowing(DownloadsState(models: rows))),
        section: DashboardSection.models,
        models: rows,
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));
      await tester.pumpAndSettle();
      return cubits;
    }

    testWidgets('offers pause and cancel while a download runs', (tester) async {
      await pumpDownloading(tester, paused: false);

      expect(find.byTooltip('Приостановить'), findsOneWidget);
      expect(find.byTooltip('Отменить'), findsOneWidget);
      expect(find.byTooltip('Продолжить'), findsNothing);
    });

    testWidgets('offers resume once it is paused', (tester) async {
      await pumpDownloading(tester, paused: true);

      expect(find.byTooltip('Продолжить'), findsOneWidget);
      expect(find.byTooltip('Приостановить'), findsNothing);
      expect(find.text('42%'), findsOneWidget, reason: 'the ring keeps where it stopped');
    });

    testWidgets('sends the pause and the cancel for the bar they are on', (tester) async {
      final cubits = await pumpDownloading(tester, paused: false);
      final bar = find.byKey(const ValueKey('whisperBar-$whisperModelId'));

      await tester.tap(find.descendant(of: bar, matching: find.byTooltip('Приостановить')));
      await tester.pumpAndSettle();
      verify(() => cubits.downloads.add(const DownloadPaused(whisperModelId))).called(1);

      await tester.tap(find.descendant(of: bar, matching: find.byTooltip('Отменить')));
      await tester.pumpAndSettle();
      verify(() => cubits.downloads.add(const DownloadCancelled(whisperModelId))).called(1);
    });

    testWidgets('fetches a model from its own bar', (tester) async {
      final cubits = await pumpDownloading(tester, paused: false);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('whisperBar-whisper-small')),
          matching: find.byTooltip('Скачать'),
        ),
      );
      await tester.pumpAndSettle();

      final sent =
          verify(() => cubits.downloads.add(captureAny())).captured.single as ModelInstallAsked;
      expect(sent.install.model.id, 'whisper-small');
    });

    testWidgets('a paused download is resumed from its own bar', (tester) async {
      await pumpDownloading(tester, paused: true);

      final bar = find.byKey(const ValueKey('whisperBar-$whisperModelId'));

      // The smallest bar spends its room on the ring; the pause shows as the
      // play button in place of the pause one.
      expect(find.descendant(of: bar, matching: find.text('42%')), findsOneWidget);
      expect(find.descendant(of: bar, matching: find.byTooltip('Продолжить')), findsOneWidget);
      expect(find.descendant(of: bar, matching: find.byTooltip('Отменить')), findsOneWidget);
      expect(
        find.descendant(of: bar, matching: find.byTooltip('Скачать')),
        findsNothing,
        reason: 'resuming is the download button of a paused bar',
      );
    });

    testWidgets('fills the bar of a download from the bottom', (tester) async {
      await pumpDownloading(tester, paused: false);

      final fill = tester.widget<AnimatedFractionallySizedBox>(
        find.descendant(
          of: find.byKey(const ValueKey('whisperBar-$whisperModelId')),
          matching: find.byType(AnimatedFractionallySizedBox),
        ),
      );
      expect(fill.heightFactor, 0.42);
      // The figure sits inside the ring, even on the smallest bar.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('whisperDial-$whisperModelId')),
          matching: find.text('42%'),
        ),
        findsOneWidget,
      );
    });
  });

  group('choosing a recognition model', () {
    Future<StagedDashboard> pumpModels(
      WidgetTester tester, {
      AppSettings settings = const AppSettings(),
    }) async {
      final cubits = stage(
        buildCubits(downloads: downloadsShowing(DownloadsState(models: catalogue()))),
        section: DashboardSection.models,
        settings: settings,
        models: catalogue(),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 1000));
      await tester.pumpAndSettle();
      return cubits;
    }

    testWidgets('lists every whisper build and marks the default', (tester) async {
      final cubits = await pumpModels(tester);

      expect(find.text('base'), findsOneWidget);
      expect(find.text('small'), findsOneWidget);
      expect(find.text('large-v3-turbo'), findsOneWidget);
      expect(
        cubits.selection.recognition?.model.id,
        whisperModelId,
        reason: 'an unset choice falls back to the smallest',
      );
      // The build in use is the dark bar; the others stay light.
      Color barColour(String id) => tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byKey(ValueKey('whisperBar-$id')),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color!;
      expect(barColour(whisperModelId), LoreDubPalette.graphite);
      expect(barColour('whisper-small'), LoreDubPalette.panel);
    });

    testWidgets('draws every bar to the size of its download', (tester) async {
      await pumpModels(tester);

      double height(String id) => tester.getSize(find.byKey(ValueKey('whisperBar-$id'))).height;
      final small = modelCatalog.firstWhere((model) => model.id == 'whisper-small');
      final turbo = modelCatalog.firstWhere((model) => model.id == 'whisper-large-v3-turbo-q5');

      expect(
        height('whisper-large-v3-turbo-q5') / height('whisper-small'),
        closeTo(turbo.downloadBytes / small.downloadBytes, 0.01),
      );
      expect(height(whisperModelId), lessThan(height('whisper-small')));
      expect(find.text('465 МБ'), findsOneWidget, reason: 'each size is written on the axis');
      expect(find.text('хорошо'), findsOneWidget);
      expect(find.text('без перевода'), findsOneWidget, reason: 'turbo only transcribes');
    });

    testWidgets('keeps a button on every bar for what can be done with it', (tester) async {
      final cubits = stage(
        buildCubits(),
        section: DashboardSection.models,
        models: [
          for (final state in catalogue())
            state.model.id == 'whisper-small' ? ModelInstallState(model: state.model) : state,
        ],
      );
      await pumpDashboard(tester, cubits, const Size(1280, 1000));
      await tester.pumpAndSettle();

      Finder on(String id, String tooltip) => find.descendant(
        of: find.byKey(ValueKey('whisperBar-$id')),
        matching: find.byTooltip(tooltip),
      );
      expect(on('whisper-small', 'Скачать'), findsOneWidget);
      expect(on(whisperModelId, 'Удалить'), findsOneWidget);
      expect(on('whisper-large-v3-turbo-q5', 'Удалить'), findsOneWidget);
    });

    testWidgets('asks before deleting a downloaded model', (tester) async {
      final cubits = await pumpModels(tester);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('whisperBar-whisper-small')),
          matching: find.byTooltip('Удалить'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Удалить модель?'), findsOneWidget);
      expect(find.textContaining('Whisper small (465 МБ)'), findsOneWidget);

      await tester.tap(find.text('Оставить'));
      await tester.pumpAndSettle();

      expect(find.text('Удалить модель?'), findsNothing);
      verifyNever(() => cubits.downloads.add(any<DownloadsEvent>()));
    });

    testWidgets('deletes it once asked twice', (tester) async {
      final cubits = await pumpModels(tester);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('whisperBar-whisper-small')),
          matching: find.byTooltip('Удалить'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Удалить')),
      );
      await tester.pumpAndSettle();

      final sent = verify(() => cubits.downloads.add(captureAny())).captured.single as ModelRemoved;
      expect(sent.install.model.id, 'whisper-small');
    });

    testWidgets('keeps the model in use while dubbing runs', (tester) async {
      final cubits = stage(
        buildCubits(),
        section: DashboardSection.models,
        models: catalogue(),
        status: PipelineStatus.listening,
      );
      await pumpDashboard(tester, cubits, const Size(1280, 1000));
      await tester.pumpAndSettle();

      final locked = find.descendant(
        of: find.byKey(const ValueKey('whisperBar-$whisperModelId')),
        matching: find.byTooltip('Выбранную модель нельзя удалить, пока идёт озвучка'),
      );
      expect(locked, findsOneWidget);
      expect(
        tester
            // The button builds its tooltip inside itself.
            .widget<IconButton>(find.ancestor(of: locked, matching: find.byType(IconButton)))
            .onPressed,
        isNull,
      );
    });

    testWidgets('grows a bar a little under the pointer', (tester) async {
      await pumpModels(tester);
      final bar = find.byKey(const ValueKey('whisperBar-whisper-small'));
      double scale() => tester
          .widget<AnimatedScale>(find.descendant(of: bar, matching: find.byType(AnimatedScale)))
          .scale;
      expect(scale(), 1);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(bar));
      await tester.pumpAndSettle();

      expect(scale(), greaterThan(1));
      expect(scale(), lessThan(1.1), reason: 'a little, not a zoom');
    });

    testWidgets('remembers the model tapped in the list', (tester) async {
      final cubits = await pumpModels(tester);

      await tester.tap(find.text('small'));
      await tester.pumpAndSettle();

      expect(cubits.selection.recognition?.model.id, 'whisper-small');
      expect((await SettingsService().load()).whisperModel, 'whisper-small');
    });

    testWidgets('falls back when the stored choice names a model that is gone', (tester) async {
      final cubits = await pumpModels(
        tester,
        settings: const AppSettings(whisperModel: 'whisper-from-an-older-build'),
      );

      expect(cubits.selection.recognition?.model.id, whisperModelId);
    });

    testWidgets('asks turbo to transcribe rather than translate', (tester) async {
      final cubits = await pumpModels(
        tester,
        settings: const AppSettings(whisperModel: 'whisper-large-v3-turbo-q5'),
      );

      expect(cubits.selection.recognitionTranslatesSpeech, isFalse);
      // Auto-detection is on by default, so nothing is claimed about the
      // original yet and no warning is due.
      expect(cubits.selection.recognitionNeedsEnglish, isFalse);
    });

    testWidgets('warns when a transcribe-only model meets a named foreign original', (
      tester,
    ) async {
      final cubits = await pumpModels(
        tester,
        settings: const AppSettings(
          whisperModel: 'whisper-large-v3-turbo-q5',
          detectSourceLanguage: false,
          sourceLanguage: 'de',
        ),
      );

      expect(cubits.selection.recognitionNeedsEnglish, isTrue);
      expect(find.textContaining('не переводит речь'), findsWidgets);
    });

    testWidgets('says nothing when that model is pointed at English', (tester) async {
      final cubits = await pumpModels(
        tester,
        settings: const AppSettings(
          whisperModel: 'whisper-large-v3-turbo-q5',
          detectSourceLanguage: false,
          sourceLanguage: 'en',
        ),
      );

      expect(cubits.selection.recognitionNeedsEnglish, isFalse);
    });
  });
}

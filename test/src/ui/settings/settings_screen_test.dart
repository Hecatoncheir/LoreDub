// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// The settings screen: the interface, the devices, the voice and the keys.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/repositories/voice_bank_repository.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/data/services/runtime_catalog.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:lore_dub/src/domain/failure.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/runtime_package.dart';
import 'package:lore_dub/src/ui/models/bloc/downloads_bloc.dart';
import 'package:lore_dub/src/ui/shell/bloc/navigation_cubit.dart';
import 'package:lore_dub/src/ui/common/keyed_text.dart';
import 'package:lore_dub/src/ui/settings/voice_choice_field.dart';
import 'package:lore_dub/src/ui/settings/bloc/settings_bloc.dart';
import 'package:lore_dub/src/ui/settings/voice_card.dart';
import 'package:lore_dub/src/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/dashboard_harness.dart';
import '../../../support/key_finders.dart';
import '../../../support/mock_blocs.dart';
import '../../../support/staged_dashboard.dart';
import '../../../support/fakes/fake_runtime_repository.dart';

void main() {
  // What `captureAny` stands in with before anything is captured.
  setUpAll(registerEventFallbacks);

  testWidgets('starts in Russian and remembers a switch to English', (tester) async {
    await pumpLoreDub(tester, const Size(1280, 900));

    expect(find.text('Дубляж'), findsOneWidget);
    expect((await SettingsService().load()).interfaceLanguage, 'ru');

    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('Signal setup'), findsOneWidget);
    expect(find.text('Interface language'), findsOneWidget);
    expect((await SettingsService().load()).interfaceLanguage, 'en');

    await tester.tap(find.text('Live'));
    await tester.pumpAndSettle();
    expect(find.text('Dubbing'), findsOneWidget);
    expect(find.text('Start dubbing'), findsOneWidget);
  });

  testWidgets('puts the downloads and the paths side by side at the foot', (tester) async {
    await pumpLoreDub(tester, const Size(1280, 900));
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();

    final downloads = find.text('ЗАГРУЗКА');
    await tester.scrollUntilVisible(downloads, 300, scrollable: settingsScroller());
    await tester.pumpAndSettle();

    expect(find.text('ПУТИ'), findsOneWidget);
    expect(find.text('Загрузка моделей'), findsOneWidget, reason: 'nothing is folded away');
    expect(
      tester.getTopLeft(find.text('ПУТИ')).dx,
      greaterThan(tester.getTopLeft(downloads).dx),
      reason: 'the paths stand beside the downloads, not under them',
    );
  });

  testWidgets('saves a model download proxy from settings', (tester) async {
    await pumpLoreDub(tester, const Size(1280, 900));
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();

    final proxyField = find.widgetWithText(
      TextFormField,
      'HTTP / SOCKS5 proxy',
    );
    // Scrolled to rather than dragged by a fixed distance: the settings list
    // grows with every card added to it.
    await tester.scrollUntilVisible(proxyField, 300, scrollable: settingsScroller());
    await tester.pumpAndSettle();
    await tester.enterText(
      proxyField,
      'http://127.0.0.1:7890',
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Сохранить'));
    await tester.pumpAndSettle();

    // What is on disk, read the way the next start reads it.
    expect((await SettingsService().load()).modelProxyUrl, 'http://127.0.0.1:7890');
  });

  testWidgets('offers the compute device presets and a row per stage', (tester) async {
    await pumpLoreDub(tester, const Size(1280, 900));
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();

    final section = find.text('Вычислительное устройство');
    await tester.scrollUntilVisible(section, 300, scrollable: settingsScroller());
    await tester.pumpAndSettle();

    expect(section, findsOneWidget);
    for (final preset in ['Автоматически', 'GPU', 'CPU']) {
      expect(find.text(preset), findsWidgets, reason: preset);
    }
    // One row per stage, named as the player knows them.
    expect(find.text('Whisper'), findsOneWidget);
    expect(find.text('Перевод'), findsOneWidget);
    expect(find.text('Озвучка'), findsOneWidget);
  });

  testWidgets('says what the compute choice leaves to say, and nothing else', (tester) async {
    Future<void> open(WidgetTester tester, ComputeDevice device) async {
      final cubits = stage(
        buildCubits(),
        section: DashboardSection.settings,
        settings: AppSettings(computeDevice: device),
        models: catalogue(),
        availability: const ComputeAvailability(
          adapters: [GraphicsAdapter(name: 'RTX 4070', vendor: GraphicsVendor.nvidia)],
        ),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 1000));
      final section = find.text('Вычислительное устройство');
      await tester.scrollUntilVisible(section, 300, scrollable: settingsScroller());
      await tester.pumpAndSettle();
    }

    // Automatic says neither: the table under it already shows where every
    // stage ended up, which is the answer either line would have given.
    await open(tester, ComputeDevice.auto);
    expect(find.textContaining('RTX 4070'), findsNothing);
    expect(find.byKey(const ValueKey('cpuThreads')), findsNothing);

    await open(tester, ComputeDevice.gpu);
    expect(find.textContaining('RTX 4070'), findsOneWidget);
    expect(find.byKey(const ValueKey('cpuThreads')), findsNothing);

    // Everything on the processor: how much of it to use is the question
    // left, and it is asked here rather than in a card of its own.
    await open(tester, ComputeDevice.cpu);
    expect(find.textContaining('RTX 4070'), findsNothing);
    expect(find.byKey(const ValueKey('cpuThreads')), findsOneWidget);
    expect(find.textContaining('Распознавание занимает'), findsOneWidget);
  });

  testWidgets('offers speech the card but never Vulkan', (tester) async {
    await pumpLoreDub(tester, const Size(1280, 900));
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();

    final speech = find.text('Озвучка');
    await tester.scrollUntilVisible(speech, 300, scrollable: settingsScroller());
    await tester.pumpAndSettle();

    // Silero rides on the worker's torch, which has no Vulkan build at all.
    // CUDA it would take; this machine simply has no card to give it.
    Finder cell(String backend) => find.byKey(ValueKey('backendCell-speech-$backend'));
    expect(
      find.descendant(
        of: cell('vulkan'),
        matching: find.byTooltip('Не поддерживается этой моделью'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: cell('cuda'),
        matching: find.byTooltip('Нет подходящей видеокарты или драйвера'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: cell('cpu'), matching: find.byTooltip('Стадия считается здесь')),
      findsOneWidget,
    );
  });

  group('the stage-by-device table', () {
    // The Vulkan whisper.cpp ships inside the installer rather than the
    // catalogue, so it is named here the way the storage service names it.
    const nvidia = ComputeAvailability(
      adapters: [
        GraphicsAdapter(name: 'NVIDIA GeForce RTX 3080 Ti', vendor: GraphicsVendor.nvidia),
      ],
      cudaDriver: true,
      vulkanLoader: true,
      installedRuntimes: {whisperCudaRuntimeId, 'whisper-vulkan'},
    );
    late FakeRuntimeRepository runtimes;

    Future<StagedDashboard> pumpTable(
      WidgetTester tester, {
      ComputeAvailability availability = nvidia,
    }) async {
      SharedPreferences.setMockInitialValues({});
      runtimes = FakeRuntimeRepository(installed: {whisperCudaRuntimeId});
      final cubits = stage(
        buildCubits(runtimes: runtimes),
        section: DashboardSection.settings,
        availability: availability,
        runtimes: [
          RuntimeInstallState(package: runtimePackageById(whisperCudaRuntimeId)!, installed: true),
          RuntimeInstallState(package: runtimePackageById(torchCudaRuntimeId)!),
        ],
      );
      await pumpDashboard(tester, cubits, const Size(1280, 1000));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('runtimeTile-$torchCudaRuntimeId')),
        300,
        scrollable: settingsScroller(),
      );
      await tester.pumpAndSettle();
      return cubits;
    }

    Finder cell(String stage, String backend) =>
        find.byKey(ValueKey('backendCell-$stage-$backend'));

    testWidgets('marks the device each stage runs on', (tester) async {
      await pumpTable(tester);

      Color colour(Finder finder) => tester
          .widget<Material>(find.descendant(of: finder, matching: find.byType(Material)).first)
          .color!;
      // Automatic puts Whisper on the CUDA it has, and translation, still
      // without its package, on the processor.
      expect(colour(cell('recognition', 'cuda')), LoreDubPalette.graphite);
      expect(colour(cell('recognition', 'cpu')), LoreDubPalette.panel);
      expect(colour(cell('translation', 'cpu')), LoreDubPalette.graphite);
      expect(
        find.descendant(of: cell('translation', 'cuda'), matching: find.text('2.7 ГБ')),
        findsOneWidget,
        reason: 'the missing package names its size',
      );
    });

    testWidgets('picks a ready device by tapping its cell', (tester) async {
      final cubits = await pumpTable(tester);

      await tester.ensureVisible(cell('recognition', 'vulkan'));
      await tester.pumpAndSettle();
      await tester.tap(cell('recognition', 'vulkan'));
      await tester.pumpAndSettle();

      expect(
        cubits.settings.settings.backendOverride(ComputeStage.recognition),
        ComputeBackend.vulkan,
      );
    });

    testWidgets('fetches a missing package from its cell', (tester) async {
      await pumpTable(tester);

      await tester.ensureVisible(cell('translation', 'cuda'));
      await tester.pumpAndSettle();
      await tester.tap(cell('translation', 'cuda'));
      await tester.pumpAndSettle();

      expect(runtimes.installs, [torchCudaRuntimeId]);
    });

    // A copy built without the Vulkan SDK carries no Vulkan whisper, and
    // nothing in the catalogue would fetch one. The cell used to read as
    // ready and swallow the press that followed.
    testWidgets('says when a build this copy has not got is asked for', (tester) async {
      final cubits = await pumpTable(
        tester,
        availability: nvidia.copyWith(installedRuntimes: const {whisperCudaRuntimeId}),
      );

      await tester.ensureVisible(cell('recognition', 'vulkan'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: cell('recognition', 'vulkan'),
          matching: find.byTooltip(
            'Этой сборки нет в вашей копии: сборка Whisper с Vulkan входит в '
            'установщик, только если её удалось собрать',
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(cell('recognition', 'vulkan'));
      await tester.pumpAndSettle();
      expect(
        cubits.settings.settings.backendOverride(ComputeStage.recognition),
        isNull,
        reason: 'a cell that cannot be chosen must not store a pin either',
      );
    });

    testWidgets('draws the packages as tiles with their buttons', (tester) async {
      await pumpTable(tester);

      Finder on(String id, String tooltip) => find.descendant(
        of: find.byKey(ValueKey('runtimeTile-$id')),
        matching: find.byTooltip(tooltip),
      );
      expect(on(whisperCudaRuntimeId, 'Удалить'), findsOneWidget);
      expect(on(torchCudaRuntimeId, 'Скачать'), findsOneWidget);
    });
  });

  testWidgets('remembers the compute preset the user pressed', (tester) async {
    await pumpLoreDub(tester, const Size(1280, 900));
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();

    final section = find.text('Вычислительное устройство');
    await tester.scrollUntilVisible(section, 300, scrollable: settingsScroller());
    await tester.pumpAndSettle();

    final preset = find.descendant(
      of: find.byType(SegmentedButton<ComputeDevice>),
      matching: find.text('CPU'),
    );
    await tester.tap(preset);
    await tester.pumpAndSettle();

    expect((await SettingsService().load()).computeDevice, ComputeDevice.cpu);
  });

  testWidgets('says why a GPU runtime did not install instead of looking untouched', (
    tester,
  ) async {
    final failed = [
      RuntimeInstallState(package: runtimePackageById(whisperCudaRuntimeId)!),
      RuntimeInstallState(
        package: runtimePackageById(torchCudaRuntimeId)!,
        error: const LoreDubFailure(
          FailureCode.runtimeInstallFailed,
          detail: '1\nERROR: Could not install packages due to an OSError',
        ),
      ),
    ];
    const nvidiaDriver = ComputeAvailability(
      adapters: [
        GraphicsAdapter(name: 'NVIDIA GeForce RTX 3080 Ti', vendor: GraphicsVendor.nvidia),
      ],
      cudaDriver: true,
    );
    // A failure is a row's own, which only a download under way leaves: the
    // rows are the mock's.
    final cubits = stage(
      buildCubits(
        downloads: downloadsShowing(DownloadsState(runtimes: failed, availability: nvidiaDriver)),
      ),
      section: DashboardSection.settings,
      availability: nvidiaDriver,
      runtimes: failed,
    );
    await pumpDashboard(tester, cubits, const Size(1280, 1000));

    final message = find.textContaining('Не удалось установить GPU-рантайм');
    await tester.scrollUntilVisible(message, 300, scrollable: settingsScroller());
    await tester.pumpAndSettle();

    expect(message, findsOneWidget);
    expect(find.textContaining('OSError'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('runtimeTile-$torchCudaRuntimeId')),
        matching: find.byTooltip('Скачать'),
      ),
      findsOneWidget,
      reason: 'the button stays, so the install can be tried again',
    );
  });

  group('removing a GPU runtime', () {
    /// Records what the interface asked for instead of touching the disk.
    /// Real file futures never complete inside a widget test's fake async
    /// zone, and what is under test here is the question, not the delete —
    /// the delete itself is covered in the runtime store's own tests.
    late FakeRuntimeRepository runtimes;

    /// The delete button of the CUDA Whisper tile.
    Finder removeButton() => find.descendant(
      of: find.byKey(const ValueKey('runtimeTile-$whisperCudaRuntimeId')),
      matching: find.byTooltip('Удалить'),
    );

    Future<void> stageInstalledRuntime(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      runtimes = FakeRuntimeRepository(installed: {whisperCudaRuntimeId});
      final cubits = stage(
        buildCubits(runtimes: runtimes),
        section: DashboardSection.settings,
        availability: const ComputeAvailability(installedRuntimes: {whisperCudaRuntimeId}),
        runtimes: [
          RuntimeInstallState(
            package: runtimePackageById(whisperCudaRuntimeId)!,
            installed: true,
          ),
        ],
      );

      await pumpDashboard(tester, cubits, const Size(1280, 1000));
      await tester.scrollUntilVisible(
        removeButton(),
        300,
        scrollable: settingsScroller(),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('asks before giving hundreds of megabytes back', (tester) async {
      await stageInstalledRuntime(tester);

      await tester.tap(removeButton());
      await tester.pumpAndSettle();

      expect(find.text('Точно удалить?'), findsOneWidget);
      expect(find.text('Удалить полностью'), findsOneWidget);
      expect(find.text('Оставить'), findsOneWidget);
      expect(runtimes.removed, isEmpty, reason: 'asking must not act');
    });

    testWidgets('names the size that is about to be freed', (tester) async {
      await stageInstalledRuntime(tester);

      await tester.tap(removeButton());
      await tester.pumpAndSettle();

      expect(find.textContaining('436 МБ'), findsWidgets);
    });

    testWidgets('keeps the runtime when the question is declined', (tester) async {
      await stageInstalledRuntime(tester);

      await tester.tap(removeButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Оставить'));
      await tester.pumpAndSettle();

      expect(find.text('Точно удалить?'), findsNothing);
      expect(runtimes.removed, isEmpty);
      expect(removeButton(), findsOneWidget);
    });

    testWidgets('removes it once the question is answered', (tester) async {
      await stageInstalledRuntime(tester);

      await tester.tap(removeButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить полностью'));
      await tester.pumpAndSettle();

      expect(find.text('Точно удалить?'), findsNothing);
      expect(runtimes.removed, [whisperCudaRuntimeId]);
      expect(
        removeButton(),
        findsNothing,
        reason: 'the offer goes away with the runtime',
      );
    });
  });

  group('the dubbing voice', () {
    /// A dashboard with every model in place, sitting on the settings screen.
    /// The bootstrap's own load never finishes inside a widget test, so the
    /// state the card reads is put there directly.
    Future<StagedDashboard> pumpSettings(
      WidgetTester tester, {
      AppSettings settings = const AppSettings(),
      List<ModelInstallState>? models,
      VoiceBankRepository? voiceBank,
    }) async {
      final cubits = stage(
        buildCubits(voiceBank: voiceBank),
        settings: settings,
        models: models ?? catalogue(),
      );
      // Counts the kept voices, as opening the application does.
      cubits.settings.add(const SettingsOpened());
      await pumpDashboard(tester, cubits, const Size(1280, 1000));
      await tester.scrollUntilVisible(
        find.text('Голос озвучки'),
        300,
        scrollable: liveScroller(),
      );
      await tester.pumpAndSettle();
      return cubits;
    }

    /// The voice picked by hand, which is keyed by the language and the voice
    /// it shows and so is found by what it is.
    final voicePicker = find.descendant(
      of: find.byType(VoiceChoiceField),
      matching: find.byType(DropdownButtonFormField<String>),
    );

    testWidgets('offers automatic and a hand-picked voice', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Голос озвучки'), findsOneWidget);
      expect(find.text('Выбрать'), findsOneWidget);
      expect(
        voicePicker,
        findsNothing,
        reason: 'automatic is the default, so there is nothing to pick from',
      );
    });

    testWidgets('lists the voices of the language once one is chosen by hand', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Выбрать'));
      await tester.pumpAndSettle();

      final picker = voicePicker;
      expect(picker, findsOneWidget);
      final field = tester.widget<DropdownButtonFormField<String>>(picker);
      expect(field.initialValue, 'female_1', reason: 'the catalogue default for Russian');

      field.onChanged!('male_0');
      await tester.pumpAndSettle();

      final saved = await SettingsService().load();
      expect(saved.automaticVoice, isFalse);
      expect(saved.voice, 'male_0');
    });

    testWidgets('names the gender beside every voice', (tester) async {
      await pumpSettings(tester, settings: const AppSettings(automaticVoice: false));

      await tester.tap(voicePicker);
      await tester.pumpAndSettle();

      expect(find.text('Male 0 (мужской)'), findsWidgets);
      expect(find.text('Female 1 (женский)'), findsWidgets);
    });

    testWidgets('says why a one-gender language cannot follow either', (tester) async {
      // A Russian package with men's voices alone, as Silero's Spanish was.
      final vosk = speechModelFor('ru')!;
      final menOnly = ModelPackage(
        id: vosk.id,
        artifacts: vosk.artifacts,
        kind: ModelKind.speech,
        language: 'ru',
        speaker: 'male_0',
        voices: const [VoiceOption('male_0', gender: VoiceGender.male)],
      );
      final cubits = await pumpSettings(
        tester,
        models: [
          for (final state in catalogue())
            state.model.id == vosk.id ? ModelInstallState(model: menOnly, installed: true) : state,
        ],
      );

      expect(cubits.selection.canFollowSpeaker, isFalse);
      expect(find.textContaining('одного пола'), findsOneWidget);
    });

    testWidgets('re-voices in the original timbre once asked', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Голос оригинала'));
      await tester.pumpAndSettle();

      expect((await SettingsService().load()).originalVoice, isTrue);
      expect(find.textContaining('Тембр оригинала накладывается'), findsOneWidget);
      expect(
        find.textContaining('получает свой голос Vosk'),
        findsOneWidget,
        reason: 'the characters are remembered from the start',
      );
    });

    testWidgets('offers to remember the characters without the original voice', (tester) async {
      // Automatic voice with the converter downloaded: it is what hears who
      // is speaking, so each character can be given a voice of their own.
      await pumpSettings(tester);

      expect(find.text('Запоминать голоса персонажей'), findsOneWidget);

      // The label is not the control; the switch beside it is.
      final remember = find.descendant(
        of: find
            .ancestor(
              of: find.text('Запоминать голоса персонажей'),
              matching: find.byType(Row),
            )
            .first,
        matching: find.byType(Switch),
      );
      await tester.ensureVisible(remember);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(remember).value, isTrue, reason: 'on from the start');
      expect(find.textContaining('получает свой голос Vosk'), findsOneWidget);
    });

    testWidgets('asks for the converter before re-voicing', (tester) async {
      final cubits = await pumpSettings(
        tester,
        settings: const AppSettings(originalVoice: true),
        models: [
          for (final state in catalogue())
            state.model.kind == ModelKind.voiceConversion
                ? ModelInstallState(model: state.model)
                : state,
        ],
      );

      expect(find.textContaining('Нужен конвертер голоса'), findsOneWidget);
      expect(
        cubits.selection.requiredModelsInstalled,
        isFalse,
        reason: 'the start button waits for the download',
      );
    });

    testWidgets('offers overlapping characters only when voices can differ', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Накладывать реплики разных персонажей'), findsOneWidget);
      final row = find.ancestor(
        of: find.text('Накладывать реплики разных персонажей'),
        matching: find.byType(Row),
      );
      await tester.tap(find.descendant(of: row.first, matching: find.byType(Switch)));
      await tester.pumpAndSettle();

      // Off to begin with, so the press is what turns overlapping on.
      expect((await SettingsService().load()).overlapVoices, isTrue);
    });

    testWidgets('hides overlapping when one voice reads every line', (tester) async {
      await pumpSettings(tester, settings: const AppSettings(automaticVoice: false));

      expect(find.text('Накладывать реплики разных персонажей'), findsNothing);
    });

    Finder clearButton() => find.descendant(
      of: find.byType(VoiceCard),
      matching: find.ancestor(
        of: find.text('Очистить'),
        matching: find.byWidgetPredicate((widget) => widget is TextButton),
      ),
    );

    testWidgets('remembers the characters until told otherwise', (tester) async {
      await pumpSettings(tester, settings: const AppSettings(originalVoice: true));

      expect(find.text('Сохранённых голосов нет'), findsOneWidget);
      expect(
        tester.widget<TextButton>(clearButton()).onPressed,
        isNull,
        reason: 'there is nothing to clear',
      );
      expect(find.textContaining('У каждой игры свой банк'), findsOneWidget);

      final row = find.ancestor(
        of: find.text('Запоминать голоса персонажей'),
        matching: find.byType(Row),
      );
      await tester.tap(find.descendant(of: row.first, matching: find.byType(Switch)));
      await tester.pumpAndSettle();

      expect((await SettingsService().load()).voiceBank, isFalse);
      expect(find.textContaining('Персонажи не запоминаются'), findsOneWidget);
    });

    testWidgets('asks before clearing the kept voices', (tester) async {
      final bank = MemoryVoiceBank(3);
      final cubits = await pumpSettings(
        tester,
        settings: const AppSettings(originalVoice: true, voiceBank: true),
        voiceBank: bank,
      );

      expect(find.text('Сохранено 3 голоса'), findsOneWidget);
      await tester.tap(clearButton());
      await tester.pumpAndSettle();
      expect(find.text('Очистить банк голосов?'), findsOneWidget);

      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      expect(find.text('Очистить банк голосов?'), findsNothing);
      expect(cubits.settings.state.voiceBankSize, 3, reason: 'a cancel keeps every voice');
      expect(bank.cleared, isFalse);

      await tester.tap(clearButton());
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Очистить')),
      );
      await tester.pumpAndSettle();

      expect(bank.cleared, isTrue);
      expect(cubits.settings.state.voiceBankSize, 0, reason: 'counted again once cleared');
    });

    testWidgets('leaves OpenVoice out of the devices without the original voice', (tester) async {
      await pumpDashboard(
        tester,
        stage(buildCubits(), section: DashboardSection.settings, models: catalogue()),
        const Size(1280, 1000),
      );
      await tester.scrollUntilVisible(
        find.textContaining('Vosk на видеокарте быстрее только на повторах'),
        300,
        scrollable: settingsScroller(),
      );

      expect(find.text('OpenVoice'), findsNothing);
    });

    testWidgets('gives OpenVoice a device of its own with the original voice', (tester) async {
      await pumpDashboard(
        tester,
        stage(
          buildCubits(),
          section: DashboardSection.settings,
          settings: const AppSettings(originalVoice: true),
          models: catalogue(),
        ),
        const Size(1280, 1000),
      );
      await tester.scrollUntilVisible(
        find.text('OpenVoice'),
        300,
        scrollable: settingsScroller(),
      );
      expect(find.text('OpenVoice'), findsOneWidget);
    });
  });

  group('the hotkeys', () {
    Future<StagedDashboard> pumpHotkeys(WidgetTester tester) async {
      final cubits = stage(
        buildCubits(),
        section: DashboardSection.settings,
        settings: const AppSettings(),
        models: catalogue(),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 1000));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('snapshotHotkey')),
        300,
        scrollable: settingsScroller(),
      );
      await tester.pumpAndSettle();
      return cubits;
    }

    Finder field(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(OutlinedButton),
    );

    Future<void> press(WidgetTester tester, List<LogicalKeyboardKey> keys) async {
      for (final key in keys) {
        await tester.sendKeyDownEvent(key);
      }
      for (final key in keys.reversed) {
        await tester.sendKeyUpEvent(key);
      }
      await tester.pumpAndSettle();
    }

    testWidgets('comes with a combination for each action', (tester) async {
      await pumpHotkeys(tester);

      expect(find.text('Горячие клавиши'), findsOneWidget);
      expect(keysHeld('Ctrl + Alt + P'), findsOneWidget);
      expect(keysHeld('Ctrl + Alt + R'), findsOneWidget);
      expect(keysHeld('Ctrl + Alt + S'), findsOneWidget);
    });

    testWidgets('refuses for selection the combination pausing has', (tester) async {
      await pumpHotkeys(tester);

      await tester.ensureVisible(field('snapshotHotkey'));
      await tester.pumpAndSettle();
      await tester.tap(field('snapshotHotkey'));
      await tester.pump();
      await press(tester, [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.keyP,
      ]);

      expect(find.text('Это сочетание уже назначено на «Пауза»'), findsOneWidget);
      expect((await SettingsService().load()).snapshotHotkey, Hotkey.defaultSnapshot);
    });

    testWidgets('records the combination pressed on the field', (tester) async {
      await pumpHotkeys(tester);

      await tester.ensureVisible(field('pauseHotkey'));
      await tester.pumpAndSettle();
      await tester.tap(field('pauseHotkey'));
      await tester.pump();
      expect(find.textContaining('Нажмите сочетание…'), findsOneWidget);
      expect(keyCap('Esc'), findsOneWidget, reason: 'the key that gives up, drawn as a key');

      await press(tester, [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.f9,
      ]);

      expect(keysHeld('Ctrl + Shift + F9'), findsOneWidget);
      expect((await SettingsService().load()).pauseHotkey?.display, 'Ctrl + Shift + F9');
    });

    testWidgets('refuses a bare letter, which would leave the game', (tester) async {
      await pumpHotkeys(tester);

      await tester.ensureVisible(field('pauseHotkey'));
      await tester.pumpAndSettle();
      await tester.tap(field('pauseHotkey'));
      await tester.pump();
      await press(tester, [LogicalKeyboardKey.keyK]);

      // Every bound combination holds a Ctrl too, so the keys are looked
      // for inside the note alone.
      final problem = find.byWidgetPredicate(
        (widget) => widget is KeyedText && widget.text.startsWith('Добавьте'),
      );
      expect(problem, findsOneWidget);
      expect([
        for (final key in ['Ctrl', 'Alt', 'Win'])
          find.descendant(of: problem, matching: keyCap(key)),
      ], everyElement(findsOneWidget));
      expect((await SettingsService().load()).pauseHotkey, Hotkey.defaultPause);
    });

    testWidgets('refuses the combination the other action has', (tester) async {
      await pumpHotkeys(tester);

      await tester.ensureVisible(field('pauseHotkey'));
      await tester.pumpAndSettle();
      await tester.tap(field('pauseHotkey'));
      await tester.pump();
      await press(tester, [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.keyR,
      ]);

      expect(find.text('Это сочетание уже назначено на «Восстановление»'), findsOneWidget);
    });

    testWidgets('lets a combination be removed', (tester) async {
      await pumpHotkeys(tester);

      final clear = find.descendant(
        of: find.byKey(const ValueKey('pauseHotkey')),
        matching: find.byTooltip('Убрать сочетание'),
      );
      await tester.ensureVisible(clear);
      await tester.pumpAndSettle();
      await tester.tap(clear);
      await tester.pumpAndSettle();

      expect(find.text('Не назначено'), findsOneWidget);
      expect((await SettingsService().load()).pauseHotkey, isNull);
    });
  });
}

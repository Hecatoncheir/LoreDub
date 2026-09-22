// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

// The frame around the screens: the shell, the navigation and the version button.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/app.dart';
import 'package:lore_dub/src/domain/app_release.dart';
import 'package:lore_dub/src/ui/characters/bloc/cast_bloc.dart';
import 'package:lore_dub/src/ui/models/bloc/downloads_bloc.dart';
import 'package:lore_dub/src/ui/shell/bloc/failure_cubit.dart';
import 'package:lore_dub/src/ui/glossary/bloc/glossary_bloc.dart';
import 'package:lore_dub/src/ui/shell/bloc/navigation_cubit.dart';
import 'package:lore_dub/src/ui/graph/bloc/pipeline_facts_bloc.dart';
import 'package:lore_dub/src/ui/graph/bloc/pipeline_graph_bloc.dart';
import 'package:lore_dub/src/ui/common/bloc/session_bloc.dart';
import 'package:lore_dub/src/ui/settings/bloc/settings_bloc.dart';
import 'package:lore_dub/src/ui/common/bloc/sources_bloc.dart';
import 'package:lore_dub/src/ui/shell/bloc/startup_cubit.dart';
import 'package:lore_dub/src/ui/common/bloc/transcript_bloc.dart';
import 'package:lore_dub/src/ui/shell/bloc/update_bloc.dart';
import 'package:lore_dub/src/ui/characters/bloc/voice_capture_bloc.dart';
import 'package:lore_dub/src/ui/shell/dashboard_scaffold.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/dashboard_harness.dart';
import '../../../support/fakes/memory_native.dart';
import '../../../support/mock_blocs.dart';
import '../../../support/staged_dashboard.dart';

void main() {
  // What `captureAny` stands in with before anything is captured.
  setUpAll(registerEventFallbacks);

  testWidgets('renders the branded desktop shell', (tester) async {
    await pumpLoreDub(tester, const Size(1280, 720));

    expect(find.text('LoreDub'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Эфир'), findsOneWidget);
    // The title of this screen is the switch between its two halves.
    expect(find.text('Дубляж'), findsOneWidget);
    expect(find.text('Схема'), findsOneWidget);
    expect(find.text('01  /  ЖИВОЙ ГОЛОС'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('builds every screen out of the repositories above it', (tester) async {
    // Each one is made in its own `create` with its arguments read off the
    // context by type, which the compiler cannot check: a repository left
    // unprovided is found only when the application starts.
    await pumpLoreDub(tester, const Size(1280, 720));
    final context = tester.element(find.byType(DashboardScaffold));

    expect(context.read<FailureCubit>(), isNotNull);
    expect(context.read<NavigationCubit>(), isNotNull);
    expect(context.read<StartupCubit>(), isNotNull);
    expect(context.read<UpdateBloc>(), isNotNull);
    expect(context.read<SettingsBloc>(), isNotNull);
    expect(context.read<DownloadsBloc>(), isNotNull);
    expect(context.read<SourcesBloc>(), isNotNull);
    expect(context.read<SessionBloc>(), isNotNull);
    expect(context.read<TranscriptBloc>(), isNotNull);
    expect(context.read<CastBloc>(), isNotNull);
    expect(context.read<VoiceCaptureBloc>(), isNotNull);
    expect(context.read<GlossaryBloc>(), isNotNull);
    expect(context.read<PipelineGraphBloc>(), isNotNull);
    expect(context.read<PipelineFactsBloc>(), isNotNull);
  });

  testWidgets('draws a scaled interface inside the window it was given', (tester) async {
    // A magnified interface reflows in a smaller window and is drawn back
    // over the real one. Laid out at the window's own size first, it was
    // magnified past the edge and the right of every screen was lost.
    SharedPreferences.setMockInitialValues({'interfaceScale': 1.25});
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(LoreDubBootstrap(native: MemoryNative()));
    await tester.pump();

    expect(tester.getSize(find.byType(DashboardScaffold)), const Size(1120, 720));
  });

  testWidgets('scrolls the navigation rather than overflowing a short window', (tester) async {
    // Six entries under two headings are taller than a short window, and the
    // panel used to overflow rather than let them scroll. The pump itself is
    // the assertion -- an overflow is an exception the test would fail on.
    await pumpLoreDub(tester, const Size(1280, 560));

    expect(find.text('Эфир'), findsOneWidget);
    expect(find.text('Настройки'), findsOneWidget);
  });

  testWidgets('uses compact navigation in a narrow window', (tester) async {
    await pumpLoreDub(tester, const Size(760, 720));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Эфир'), findsOneWidget);
    expect(find.text('Модели'), findsOneWidget);
    expect(find.text('Настройки'), findsOneWidget);
  });

  testWidgets('marks the live section with the audio capture drawing', (tester) async {
    // Material Icons has no audio_capture, so it is an SVG rather than a font
    // glyph; a missing asset would otherwise only show as a blank square.
    await pumpLoreDub(tester, const Size(1280, 900));

    final sidebar = find.byType(SvgPicture);
    expect(sidebar, findsOneWidget);
    expect(
      find.descendant(of: find.widgetWithText(InkWell, 'Эфир'), matching: sidebar),
      findsOneWidget,
    );
  });

  testWidgets('carries the same drawing into the compact navigation', (tester) async {
    await pumpLoreDub(tester, const Size(760, 720));

    expect(
      find.descendant(of: find.byType(NavigationBar), matching: find.byType(SvgPicture)),
      findsWidgets,
    );
  });

  group('the version button', () {
    StagedDashboard withUpdates(UpdateState updates) => stage(buildCubits(), updates: updates);

    testWidgets('shows the version this build carries', (tester) async {
      final cubits = withUpdates(
        const UpdateState(status: UpdateStatus.current, currentVersion: '0.2.1'),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.text('Версия 0.2.1'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_outward_rounded), findsNothing);
    });

    testWidgets('lines the version icon up with the status caption', (tester) async {
      final cubits = withUpdates(
        const UpdateState(status: UpdateStatus.current, currentVersion: '0.2.1'),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      final icon = tester.getTopLeft(find.byIcon(Icons.verified_outlined));
      final status = tester.getTopLeft(find.text('WINDOWS · LOCAL PROCESSING'));

      expect(
        (icon.dx - status.dx).abs(),
        lessThanOrEqualTo(0.5),
        reason: 'the foot of the panel reads down one left edge',
      );
      expect(tester.getTopLeft(find.text('Версия 0.2.1')).dx, greaterThan(icon.dx));
    });

    testWidgets('spins while the check is running', (tester) async {
      final cubits = withUpdates(
        const UpdateState(status: UpdateStatus.checking, currentVersion: '0.2.1'),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = tester.widget<TextButton>(
        find.ancestor(of: find.text('Версия 0.2.1'), matching: find.byType(TextButton)),
      );
      expect(button.onPressed, isNull, reason: 'no second check on top of the first');
    });

    final release = AppRelease(
      version: '0.3.0',
      page: Uri.parse('https://github.com/Hecatoncheir/LoreDub/releases/tag/v0.3.0'),
      installer: ReleaseInstaller(
        name: 'LoreDub-0.3.0-windows-x64-setup.exe',
        url: Uri.parse(
          'https://github.com/Hecatoncheir/LoreDub/releases/download/v0.3.0/setup.exe',
        ),
        size: 181234513,
      ),
    );

    testWidgets('puts the update where the version was once a newer one exists', (tester) async {
      final cubits = withUpdates(
        UpdateState(status: UpdateStatus.available, currentVersion: '0.2.1', release: release),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.text('Текущая версия v0.2.1 → v0.3.0'), findsOneWidget);
      expect(find.text('Версия 0.2.1'), findsNothing, reason: 'the version steps aside');
      // This test build was not put in place by the setup, so it points at
      // the release page instead of installing over itself.
      expect(find.byTooltip('Открыть страницу версии 0.3.0'), findsOneWidget);
    });

    group('installing it', () {
      StagedDashboard withInstaller(UpdateBloc updates) => stage(buildCubits(updates: updates));

      final available = UpdateState(
        status: UpdateStatus.available,
        currentVersion: '0.2.1',
        release: release,
        installable: true,
      );

      // What the download and the restart do is the bloc's, and is pinned in
      // `update_bloc_test.dart`; here, what each step is drawn as and sends.
      testWidgets('asks for the setup from the row that offers it', (tester) async {
        final updates = updatesShowing(available);
        await pumpDashboard(tester, withInstaller(updates), const Size(1280, 900));

        expect(find.byTooltip('Нажмите, чтобы скачать и установить обновление'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('updateAvailable')));
        await tester.pumpAndSettle();

        verify(() => updates.add(const UpdateInstallAsked())).called(1);
      });

      testWidgets('shows a bar and the share in place of the text while it downloads', (
        tester,
      ) async {
        final updates = updatesShowing(available.copyWith(installProgress: 0.42));
        await pumpDashboard(tester, withInstaller(updates), const Size(1280, 900));

        expect(find.text('42%'), findsOneWidget);
        expect(find.text('Текущая версия v0.2.1 → v0.3.0'), findsNothing);
      });

      testWidgets('offers the restart once the setup is down, and asks for it', (tester) async {
        final updates = updatesShowing(
          available.copyWith(installerPath: r'C:\updates\LoreDub-0.3.0-windows-x64-setup.exe'),
        );
        await pumpDashboard(tester, withInstaller(updates), const Size(1280, 900));

        expect(find.text('Текущая версия v0.2.1 → v0.3.0'), findsNothing);
        expect(find.text('Обновлено'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('updateRestart')));
        await tester.pumpAndSettle();

        verify(() => updates.add(const UpdateRestartAsked())).called(1);
      });
    });

    testWidgets('says the check failed rather than claiming to be current', (tester) async {
      final cubits = withUpdates(
        const UpdateState(status: UpdateStatus.failed, currentVersion: '0.2.1'),
      );
      await pumpDashboard(tester, cubits, const Size(1280, 900));

      expect(find.byTooltip('Не удалось проверить обновления'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('asks for the newest release once the first load is back', (tester) async {
      final updates = updatesShowing(const UpdateState());
      final cubits = stage(buildCubits(updates: updates));
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      cubits.startup.emit(true);
      await pumpDashboard(tester, cubits, const Size(1280, 900));
      verifyNever(() => updates.add(any()));

      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      cubits.startup.emit(false);
      await tester.pump();

      verify(() => updates.add(const UpdatesChecked(announce: true))).called(1);
    });

    testWidgets('words the toast about news in the interface language', (tester) async {
      const before = UpdateState(status: UpdateStatus.current, currentVersion: '0.2.1');
      final news = UpdateState(
        status: UpdateStatus.available,
        currentVersion: '0.2.1',
        release: release,
        announce: true,
      );
      final updates = updatesShowing(before, then: Stream.value(news));
      await pumpDashboard(tester, stage(buildCubits(updates: updates)), const Size(1280, 900));

      verify(
        () => updates.add(
          const UpdateAnnounced(
            title: 'Вышла новая версия LoreDub',
            body:
                'Доступна версия 0.3.0. Нажмите на строку с версиями внизу слева, '
                'чтобы обновиться.',
          ),
        ),
      ).called(1);
    });

    testWidgets('checks again when the version is tapped', (tester) async {
      final updates = updatesShowing(
        const UpdateState(status: UpdateStatus.current, currentVersion: '0.2.1'),
      );
      await pumpDashboard(tester, stage(buildCubits(updates: updates)), const Size(1280, 900));

      await tester.tap(find.text('Версия 0.2.1'));
      await tester.pump();

      verify(() => updates.add(const UpdatesChecked())).called(1);
    });
  });
}

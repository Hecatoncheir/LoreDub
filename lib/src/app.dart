// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import 'data/repositories/session_repository.dart';
import 'domain/app_settings.dart';
import 'data/repositories/model_repository.dart';
import 'data/repositories/runtime_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/update_repository.dart';
import 'data/services/model_storage_service.dart';
import 'data/services/native_engine_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/runtime_storage_service.dart';
import 'data/services/update_service.dart';
import 'data/services/settings_service.dart';
import 'data/repositories/cast_repository.dart';
import 'data/repositories/install_repository.dart';
import 'data/repositories/sources_repository.dart';
import 'domain/session_coordinator.dart';
import 'ui/common/file_dialogs.dart';
import 'ui/dashboard/cubits/settings_cubit.dart';
import 'ui/shell/dashboard_providers.dart';
import 'ui/shell/dashboard_scaffold.dart';
import 'ui/graph/node_faces.dart';
import 'ui/theme.dart';
import 'ui/app/interface_scale.dart';
import 'data/repositories/glossary_repository.dart';
import 'data/repositories/scheme_repository.dart';
import 'data/repositories/system_repository.dart';
import 'data/repositories/voice_bank_repository.dart';

class LoreDubBootstrap extends StatefulWidget {
  const LoreDubBootstrap({super.key});

  @override
  State<LoreDubBootstrap> createState() => _LoreDubBootstrapState();
}

class _LoreDubBootstrapState extends State<LoreDubBootstrap> {
  /// One settings file, read and published in one place: everything
  /// that follows a setting listens here rather than being told.
  final settingsRepository = SettingsRepository(SettingsService());

  /// The one engine, which the sessions run on and several repositories
  /// tell what changed while one runs.
  final engine = NativeEngineService();

  /// The sessions that engine runs.
  late final sessionRepository = SessionRepository(engine);

  /// What this machine has: the processes, the monitors, the adapters.
  late final systemRepository = SystemRepository(engine);
  final voiceBankRepository = VoiceBankRepository();
  final schemeRepository = SchemeRepository();
  late final glossaryRepository = GlossaryRepository(settingsRepository, engine);
  final modelRepository = ModelRepository(ModelStorageService());
  final runtimeRepository = RuntimeRepository(RuntimeStorageService());
  final updateRepository = UpdateRepository(UpdateService(), NotificationService());

  /// What is on disk and what the machine can run it on, read once and
  /// told to everyone who cares.
  late final installRepository = InstallRepository(modelRepository, runtimeRepository);

  /// The player's own cards, which two screens work on.
  late final castRepository = CastRepository(engine);

  /// The game every screen listens to, and where the monitors stand.
  late final sourcesRepository = SourcesRepository(systemRepository);

  /// Which screen may hold the one worker, and what the engine is doing.
  final sessions = SessionCoordinator();

  /// The repositories are this state's, not any one screen's. The screens'
  /// providers sit below and have been told to close by the time this
  /// runs, so the engine they share is let go of last.
  @override
  void dispose() {
    unawaited(
      Future.wait([
        sessions.dispose(),
        sourcesRepository.dispose(),
        castRepository.dispose(),
        installRepository.dispose(),
        settingsRepository.dispose(),
      ]).whenComplete(sessionRepository.dispose),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider.value(value: sessionRepository),
      RepositoryProvider.value(value: systemRepository),
      RepositoryProvider.value(value: voiceBankRepository),
      RepositoryProvider.value(value: schemeRepository),
      RepositoryProvider.value(value: glossaryRepository),
      RepositoryProvider.value(value: modelRepository),
      RepositoryProvider.value(value: runtimeRepository),
      RepositoryProvider.value(value: settingsRepository),
      RepositoryProvider.value(value: updateRepository),
      RepositoryProvider.value(value: installRepository),
      RepositoryProvider.value(value: castRepository),
      RepositoryProvider.value(value: sourcesRepository),
      RepositoryProvider.value(value: sessions),
      RepositoryProvider.value(value: const FileDialogs()),
    ],
    // Above the application rather than under it, so a dialog pushed on the
    // navigator reads the same screens the page it came from does.
    child: DashboardProviders(
      child: BlocBuilder<SettingsCubit, SettingsState>(
        // Only the settings are watched here, so switching the interface
        // language takes effect without a restart and nothing else rebuilds the
        // application above the dashboard.
        buildWhen: (previous, current) =>
            previous.settings.interfaceLanguage != current.settings.interfaceLanguage ||
            previous.settings.chosenScale != current.settings.chosenScale ||
            previous.settings.interfaceTheme != current.settings.interfaceTheme,
        builder: (context, state) => MaterialApp(
          title: 'LoreDub',
          debugShowCheckedModeBanner: false,
          // The faces of the canvas ride on the theme rather than in the
          // theme layer: what a node looks like is the graph screen's own.
          theme: AppTheme.light.withNodeFaces(),
          darkTheme: AppTheme.dark.withNodeFaces(NodeFaces.from(LoreDubColors.dark)),
          themeMode: switch (state.settings.interfaceTheme) {
            InterfaceTheme.system => ThemeMode.system,
            InterfaceTheme.light => ThemeMode.light,
            InterfaceTheme.dark => ThemeMode.dark,
          },
          locale: Locale(state.settings.interfaceLanguage),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: InterfaceScale(
            scale: state.settings.chosenScale,
            child: const DashboardScaffold(),
          ),
        ),
      ),
    ),
  );
}

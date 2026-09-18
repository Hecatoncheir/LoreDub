// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import 'data/repositories/app_repository.dart';
import 'data/repositories/model_repository.dart';
import 'data/repositories/runtime_repository.dart';
import 'data/repositories/update_repository.dart';
import 'data/services/model_storage_service.dart';
import 'data/services/native_engine_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/runtime_storage_service.dart';
import 'data/services/update_service.dart';
import 'data/services/settings_service.dart';
import 'ui/dashboard/cubits/dashboard_cubits.dart';
import 'ui/dashboard/cubits/settings_cubit.dart';
import 'ui/shell/dashboard_view.dart';
import 'ui/theme.dart';
import 'ui/app/interface_scale.dart';

class LoreDubBootstrap extends StatefulWidget {
  const LoreDubBootstrap({super.key});

  @override
  State<LoreDubBootstrap> createState() => _LoreDubBootstrapState();
}

class _LoreDubBootstrapState extends State<LoreDubBootstrap> {
  final appRepository = AppRepository(NativeEngineService(), SettingsService());
  final modelRepository = ModelRepository(ModelStorageService());
  final runtimeRepository = RuntimeRepository(RuntimeStorageService());
  final updateRepository = UpdateRepository(UpdateService(), NotificationService());
  late final DashboardCubits cubits;

  @override
  void initState() {
    super.initState();
    cubits = DashboardCubits(
      appRepository,
      modelRepository,
      runtimeRepository,
      updateRepository,
    )..initialize();
  }

  /// The repositories are this state's, not any one cubit's: every cubit
  /// closes first, and only then is the engine they share let go of.
  @override
  void dispose() {
    unawaited(cubits.dispose().whenComplete(appRepository.dispose));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider.value(value: appRepository),
      RepositoryProvider.value(value: modelRepository),
      RepositoryProvider.value(value: runtimeRepository),
      RepositoryProvider.value(value: updateRepository),
    ],
    child: BlocBuilder<SettingsCubit, SettingsState>(
      // Only the settings are watched here, so switching the interface
      // language takes effect without a restart and nothing else rebuilds the
      // application above the dashboard.
      bloc: cubits.settings,
      buildWhen: (previous, current) =>
          previous.settings.interfaceLanguage != current.settings.interfaceLanguage ||
          previous.settings.chosenScale != current.settings.chosenScale,
      builder: (context, state) => MaterialApp(
        title: 'LoreDub',
        debugShowCheckedModeBanner: false,
        theme: buildLoreDubTheme(),
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
          child: DashboardView(cubits: cubits),
        ),
      ),
    ),
  );
}

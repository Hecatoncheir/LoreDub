// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

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
import 'ui/dashboard/dashboard_view.dart';
import 'ui/theme.dart';

class LoreDubBootstrap extends StatefulWidget {
  const LoreDubBootstrap({super.key});

  @override
  State<LoreDubBootstrap> createState() => _LoreDubBootstrapState();
}

class _LoreDubBootstrapState extends State<LoreDubBootstrap> {
  late final DashboardCubits cubits;

  @override
  void initState() {
    super.initState();
    cubits = DashboardCubits(
      AppRepository(NativeEngineService(), SettingsService()),
      ModelRepository(ModelStorageService()),
      RuntimeRepository(RuntimeStorageService()),
      UpdateRepository(UpdateService(), NotificationService()),
    )..initialize();
  }

  @override
  void dispose() {
    cubits.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<SettingsCubit, SettingsState>(
    // Only the settings are watched here, so switching the interface
    // language takes effect without a restart and nothing else rebuilds the
    // application above the dashboard.
    bloc: cubits.settings,
    buildWhen: (previous, current) =>
        previous.settings.interfaceLanguage != current.settings.interfaceLanguage,
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
      home: DashboardView(cubits: cubits),
    ),
  );
}

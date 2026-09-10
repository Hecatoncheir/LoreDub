// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import 'data/repositories/app_repository.dart';
import 'data/repositories/model_repository.dart';
import 'data/repositories/runtime_repository.dart';
import 'data/services/model_storage_service.dart';
import 'data/services/native_engine_service.dart';
import 'data/services/runtime_storage_service.dart';
import 'data/services/settings_service.dart';
import 'ui/dashboard/dashboard_view.dart';
import 'ui/dashboard/dashboard_view_model.dart';
import 'ui/theme.dart';

class LoreDubBootstrap extends StatefulWidget {
  const LoreDubBootstrap({super.key});

  @override
  State<LoreDubBootstrap> createState() => _LoreDubBootstrapState();
}

class _LoreDubBootstrapState extends State<LoreDubBootstrap> {
  late final DashboardViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = DashboardViewModel(
      AppRepository(NativeEngineService(), SettingsService()),
      ModelRepository(ModelStorageService()),
      RuntimeRepository(RuntimeStorageService()),
    )..initialize();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    // Rebuilt with the view model so switching the interface language takes
    // effect without a restart.
    listenable: viewModel,
    builder: (context, _) => MaterialApp(
      title: 'LoreDub',
      debugShowCheckedModeBanner: false,
      theme: buildLoreDubTheme(),
      locale: Locale(viewModel.settings.interfaceLanguage),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: DashboardView(viewModel: viewModel),
    ),
  );
}

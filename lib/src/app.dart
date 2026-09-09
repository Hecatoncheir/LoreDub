// Copyright (c) 2026 GameLingo contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import 'data/repositories/app_repository.dart';
import 'data/repositories/model_repository.dart';
import 'data/services/model_storage_service.dart';
import 'data/services/native_engine_service.dart';
import 'data/services/settings_service.dart';
import 'ui/dashboard/dashboard_view.dart';
import 'ui/dashboard/dashboard_view_model.dart';
import 'ui/theme.dart';

class GameLingoBootstrap extends StatefulWidget {
  const GameLingoBootstrap({super.key});

  @override
  State<GameLingoBootstrap> createState() => _GameLingoBootstrapState();
}

class _GameLingoBootstrapState extends State<GameLingoBootstrap> {
  late final DashboardViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = DashboardViewModel(
      AppRepository(NativeEngineService(), SettingsService()),
      ModelRepository(ModelStorageService()),
    )..initialize();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GameLingo',
    debugShowCheckedModeBanner: false,
    theme: buildGameLingoTheme(),
    home: DashboardView(viewModel: viewModel),
  );
}

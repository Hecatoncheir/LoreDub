// Copyright (c) 2026 LoreDub contributors.
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
    )..initialize();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'LoreDub',
    debugShowCheckedModeBanner: false,
    theme: buildLoreDubTheme(),
    home: DashboardView(viewModel: viewModel),
  );
}

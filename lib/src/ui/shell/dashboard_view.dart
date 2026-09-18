// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../dashboard/cubits/dashboard_cubits.dart';
import 'dashboard_scaffold.dart';

/// The application's one screen: the cubits it is handed, provided to
/// everything under it.
class DashboardView extends StatelessWidget {
  const DashboardView({super.key, required this.cubits});

  final DashboardCubits cubits;

  /// Everything below reads the cubits it needs off the context, so a
  /// widget's dependencies are the providers it looks up rather than one bag
  /// handed down through every constructor.
  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider.value(value: cubits.shell),
      BlocProvider.value(value: cubits.settings),
      BlocProvider.value(value: cubits.downloads),
      BlocProvider.value(value: cubits.pipeline),
      BlocProvider.value(value: cubits.characters),
      BlocProvider.value(value: cubits.glossary),
      BlocProvider.value(value: cubits.graph),
    ],
    child: const DashboardScaffold(),
  );
}

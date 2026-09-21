// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../app_icons.dart';
import '../theme.dart';
import '../dashboard/cubits/navigation_cubit.dart';

/// The sections along the foot of a window too narrow for the sidebar.
class BottomNavigation extends StatelessWidget {
  const BottomNavigation({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<NavigationCubit, NavigationState>(
    builder: (context, shell) => _build(context, shell.section),
  );

  Widget _build(BuildContext context, DashboardSection section) {
    final scheme = Theme.of(context).colorScheme;
    return NavigationBar(
      height: 68,
      backgroundColor: context.colors.panel,
      indicatorColor: context.colors.accent,
      selectedIndex: section.index,
      onDestinationSelected: (index) =>
          context.read<NavigationCubit>().selectSection(DashboardSection.values[index]),
      destinations: [
        NavigationDestination(
          // The bar tints its font icons itself, which leaves the drawing
          // untouched, so it is handed the same two colours by hand.
          icon: LoreDubIcons.audioCapture(color: scheme.onSurfaceVariant),
          selectedIcon: LoreDubIcons.audioCapture(color: scheme.onSecondaryContainer),
          label: AppLocalizations.of(context).navLive,
        ),
        NavigationDestination(
          icon: const Icon(Icons.highlight_alt_rounded),
          label: AppLocalizations.of(context).navSnapshot,
        ),
        NavigationDestination(
          icon: const Icon(Icons.groups_rounded),
          label: AppLocalizations.of(context).navCharacters,
        ),
        NavigationDestination(
          icon: const Icon(Icons.account_tree_rounded),
          label: AppLocalizations.of(context).navPipeline,
        ),
        NavigationDestination(
          icon: const Icon(Icons.memory_rounded),
          label: AppLocalizations.of(context).navModels,
        ),
        NavigationDestination(
          icon: const Icon(Icons.tune_rounded),
          label: AppLocalizations.of(context).navSettings,
        ),
      ],
    );
  }
}

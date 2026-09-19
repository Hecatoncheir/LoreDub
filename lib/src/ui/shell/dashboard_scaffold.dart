// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../common/ease.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../failure_messages.dart';
import '../dashboard/cubits/shell_cubit.dart';
import '../glossary/glossary_panel.dart';
import '../common/error_banner.dart';
import 'side_navigation.dart';
import 'bottom_navigation.dart';
import 'dashboard_header.dart';
import '../live/live_panel.dart';
import '../screen_text/snapshot_panel.dart';
import '../characters/characters_panel.dart';
import '../models/models_panel.dart';
import '../settings/settings_panel.dart';
import '../graph/pipeline_panel.dart';
import 'shell_layout.dart';

/// The frame every screen stands in: the sidebar, or the bottom bar in a
/// narrow window, the header, the failure banner, and the screen of the
/// section chosen.
class DashboardScaffold extends StatelessWidget {
  const DashboardScaffold({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < ShellLayout.compactWidth;
        final content = SafeArea(
          child: Column(
            children: [
              DashboardHeader(),
              BlocBuilder<ShellCubit, ShellState>(
                builder: (context, shell) => switch (shell.error) {
                  final error? => ErrorBanner(
                    message: describeFailure(AppLocalizations.of(context), error),
                  ),
                  _ => const SizedBox.shrink(),
                },
              ),
              Expanded(
                child: BlocBuilder<ShellCubit, ShellState>(
                  builder: (context, shell) => AnimatedSwitcher(
                    duration: ease(context, 180),
                    child: switch (shell.section) {
                      DashboardSection.live => LivePanel(
                        key: const ValueKey('live'),
                      ),
                      DashboardSection.pipeline => PipelinePanel(
                        key: const ValueKey('pipeline'),
                      ),
                      DashboardSection.snapshot => SnapshotPanel(
                        key: const ValueKey('snapshot'),
                      ),
                      DashboardSection.models => ModelsPanel(
                        key: const ValueKey('models'),
                      ),
                      DashboardSection.characters => CharactersPanel(
                        key: const ValueKey('characters'),
                      ),
                      DashboardSection.glossary => GlossaryPanel(
                        key: const ValueKey('glossary'),
                      ),
                      DashboardSection.settings => SettingsPanel(
                        key: const ValueKey('settings'),
                      ),
                    },
                  ),
                ),
              ),
            ],
          ),
        );
        if (compact) {
          return Column(
            children: [
              Expanded(child: content),
              BottomNavigation(),
            ],
          );
        }
        return Row(
          children: [
            SideNavigation(),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        );
      },
    ),
  );
}

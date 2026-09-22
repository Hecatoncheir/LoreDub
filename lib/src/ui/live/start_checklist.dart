// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/start_requirements.dart';
import '../../../l10n/app_localizations.dart';
import '../theme.dart';
import '../models/bloc/downloads_bloc.dart';
import '../settings/bloc/settings_bloc.dart';
import '../shell/bloc/navigation_cubit.dart';
import '../common/dashboard_context.dart';
import 'start_step_row.dart';
import '../../domain/capture_sources.dart';
import '../common/bloc/sources_bloc.dart';

/// What still stands between the player and the first press of Start.
///
/// The three reasons `canStart` refuses for used to be told separately --
/// one notice for the packages, another for a route taken apart, and
/// nothing at all for a game not yet chosen, which left the button dead
/// with no word about what it waited on. They are one card now, numbered in
/// the order they are met, and it is gone the moment nothing is left in it.
class StartChecklist extends StatelessWidget {
  const StartChecklist({super.key});

  // Whether a package is there rather than how far its download has got:
  // the card must not redraw through the hundred ticks of one.
  @override
  Widget build(BuildContext context) => BlocBuilder<DownloadsBloc, DownloadsState>(
    buildWhen: whenChanged((downloads) => downloads.installed),
    builder: (context, _) => BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, _) => BlocSelector<SourcesBloc, CaptureSources, bool>(
        selector: (sources) => sources.selected != null,
        builder: (context, gameChosen) =>
            _build(context, stepsBeforeStart(context.selection, gameChosen: gameChosen)),
      ),
    ),
  );

  Widget _build(BuildContext context, List<StartStep> steps) {
    if (steps.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.checklist_rounded, color: context.colors.warning, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    l10n.startChecklistTitle,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              for (final (index, step) in steps.indexed)
                StartStepRow(
                  number: index + 1,
                  title: switch (step) {
                    StartStep.models => l10n.modelsNeededTitle,
                    StartStep.route => l10n.routeNeededTitle,
                    StartStep.game => l10n.startStepGame,
                  },
                  action: switch (step) {
                    StartStep.models => l10n.modelsNeededAction,
                    StartStep.route => l10n.routeNeededAction,
                    StartStep.game => null,
                  },
                  // The picker the game is chosen in stands on this same
                  // screen, a finger's width above, so that step leads
                  // nowhere and only says what is missing.
                  onPressed: switch (step) {
                    StartStep.models => () => context.read<NavigationCubit>().selectSection(
                      DashboardSection.models,
                    ),
                    StartStep.route => () => context.read<NavigationCubit>().showOnLive(
                      LiveView.scheme,
                    ),
                    StartStep.game => null,
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

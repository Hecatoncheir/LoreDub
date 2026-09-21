// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'section_mark.dart';

import '../live/live_title_switch.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/pipeline_state.dart';
import '../../../l10n/app_localizations.dart';
import '../theme.dart';
import '../dashboard/cubits/session_bloc.dart';
import '../dashboard/cubits/shell_cubit.dart';
import '../common/status_chip.dart';

/// The top of every screen: where the section stands, its title, and how
/// the session is doing.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 22, 28, 12),
    child: Row(
      children: [
        Expanded(
          child: BlocBuilder<ShellCubit, ShellState>(
            builder: (context, shell) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // The marking over the title reads in the player's own
                  // language: it is a strap rather than a brand, and half
                  // the screens already named their areas in Russian.
                  shell.section.mark(AppLocalizations.of(context), liveView: shell.liveView),
                  style: context.textStyles.monoMarking,
                ),
                const SizedBox(height: 5),
                if (shell.section == DashboardSection.live)
                  // The title is the switch between the two halves of this
                  // screen: what is up is the heading, what is not stands
                  // beside it.
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: LiveTitleSwitch(),
                  )
                else
                  Text(
                    switch (shell.section) {
                      // The scheme is the other half of Эфир, and says so.
                      DashboardSection.live when shell.liveView == LiveView.scheme =>
                        AppLocalizations.of(context).titlePipeline,
                      DashboardSection.live => AppLocalizations.of(context).titleLive,
                      DashboardSection.snapshot => AppLocalizations.of(context).titleSnapshot,
                      DashboardSection.models => AppLocalizations.of(context).titleModels,
                      DashboardSection.characters => AppLocalizations.of(context).titleCharacters,
                      DashboardSection.glossary => AppLocalizations.of(context).titleGlossary,
                      DashboardSection.settings => AppLocalizations.of(context).titleSettings,
                    },
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
              ],
            ),
          ),
        ),
        BlocSelector<SessionBloc, SessionState, (PipelineStatus, String, bool)>(
          selector: (pipeline) => (
            pipeline.status,
            pipeline.startupStage,
            pipeline.session == PipelineSession.screen,
          ),
          builder: (context, chip) =>
              StatusChip(status: chip.$1, stage: chip.$2, snapshot: chip.$3),
        ),
      ],
    ),
  );
}

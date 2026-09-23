// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'section_mark.dart';

import '../live/live_title_switch.dart';
import '../screen_text/screen_title_switch.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/pipeline_state.dart';
import '../../../l10n/app_localizations.dart';
import '../theme.dart';
import '../common/bloc/session_bloc.dart';
import 'bloc/navigation_cubit.dart';
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
          child: BlocBuilder<NavigationCubit, NavigationState>(
            builder: (context, shell) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // The marking over the title reads in the player's own
                  // language: it is a strap rather than a brand, and half
                  // the screens already named their areas in Russian.
                  shell.section.mark(
                    AppLocalizations.of(context),
                    liveView: shell.liveView,
                    screenView: shell.screenView,
                  ),
                  style: context.textStyles.monoMarking,
                ),
                const SizedBox(height: 5),
                switch (shell.section) {
                  // On the two screens that have two halves the title is the
                  // switch between them: what is up is the heading, what is
                  // not stands beside it.
                  DashboardSection.live => const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: LiveTitleSwitch(),
                  ),
                  DashboardSection.snapshot => const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: ScreenTitleSwitch(),
                  ),
                  final section => Text(
                    section.title(AppLocalizations.of(context)),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                },
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

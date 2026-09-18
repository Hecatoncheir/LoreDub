// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'section_mark.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/pipeline_state.dart';
import '../../../l10n/app_localizations.dart';
import '../theme.dart';
import '../dashboard/cubits/pipeline_cubit.dart';
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
                  shell.section.mark(AppLocalizations.of(context)),
                  style: const TextStyle(
                    fontFamily: LoreDubFonts.mono,
                    color: LoreDubPalette.mutedInk,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  switch (shell.section) {
                    DashboardSection.live => AppLocalizations.of(context).titleLive,
                    DashboardSection.pipeline => AppLocalizations.of(context).titlePipeline,
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
        BlocSelector<PipelineCubit, LivePipelineState, (PipelineStatus, String, bool)>(
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

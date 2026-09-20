// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../app_icons.dart';
import '../theme.dart';
import '../dashboard/cubits/shell_cubit.dart';
import 'footer_insets.dart';
import 'navigation_group.dart';
import 'navigation_item.dart';
import 'version_button.dart';

/// The sidebar of a wide window: the sections in groups, and the version
/// with the update line at its foot.
class SideNavigation extends StatelessWidget {
  const SideNavigation({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 236,
    color: context.colors.panel,
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: Row(
            children: [
              Image.asset(
                'assets/branding/loredub-icon.png',
                width: 48,
                height: 48,
                semanticLabel: 'LoreDub',
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LoreDub',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'VOICE UNIT 01',
                      style: context.textStyles.monoMarking,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // The list scrolls rather than pushing the version off the foot of
        // the panel: six entries under two headings are taller than a short
        // window, and taller still under a raised interface scale.
        Expanded(
          child: BlocBuilder<ShellCubit, ShellState>(
            builder: (context, shell) => SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NavigationGroup(label: AppLocalizations.of(context).navGroupDubbing),
                  NavigationItem(
                    icon: (color) => LoreDubIcons.audioCapture(color: color, size: 21),
                    label: AppLocalizations.of(context).navLive,
                    selected: shell.section == DashboardSection.live,
                    onTap: () => context.read<ShellCubit>().selectSection(DashboardSection.live),
                  ),
                  NavigationItem(
                    icon: (color) => Icon(Icons.highlight_alt_rounded, size: 21, color: color),
                    label: AppLocalizations.of(context).navSnapshot,
                    selected: shell.section == DashboardSection.snapshot,
                    onTap: () =>
                        context.read<ShellCubit>().selectSection(DashboardSection.snapshot),
                  ),
                  NavigationGroup(label: AppLocalizations.of(context).navGroupSetup),
                  NavigationItem(
                    icon: (color) => Icon(Icons.groups_rounded, size: 21, color: color),
                    label: AppLocalizations.of(context).navCharacters,
                    selected: shell.section == DashboardSection.characters,
                    onTap: () =>
                        context.read<ShellCubit>().selectSection(DashboardSection.characters),
                  ),
                  NavigationItem(
                    icon: (color) => Icon(Icons.menu_book_rounded, size: 21, color: color),
                    label: AppLocalizations.of(context).navGlossary,
                    selected: shell.section == DashboardSection.glossary,
                    onTap: () =>
                        context.read<ShellCubit>().selectSection(DashboardSection.glossary),
                  ),
                  NavigationItem(
                    icon: (color) => Icon(Icons.memory_rounded, size: 21, color: color),
                    label: AppLocalizations.of(context).navModels,
                    selected: shell.section == DashboardSection.models,
                    onTap: () => context.read<ShellCubit>().selectSection(DashboardSection.models),
                  ),
                  NavigationItem(
                    icon: (color) => Icon(Icons.tune_rounded, size: 21, color: color),
                    label: AppLocalizations.of(context).navSettings,
                    selected: shell.section == DashboardSection.settings,
                    onTap: () =>
                        context.read<ShellCubit>().selectSection(DashboardSection.settings),
                  ),
                ],
              ),
            ),
          ),
        ),
        VersionButton(),
        Padding(
          // Starts where the version's icon does, so the foot of the panel
          // reads down one left edge.
          padding: EdgeInsets.fromLTRB(FooterInsets.start, 0, 12, 12),
          child: Text(
            'WINDOWS · LOCAL PROCESSING',
            maxLines: 1,
            // The monospaced face is wider than the label had room for.
            style: TextStyle(
              fontFamily: LoreDubFonts.mono,
              color: context.colors.mutedInk,
              fontSize: 9,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    ),
  );
}

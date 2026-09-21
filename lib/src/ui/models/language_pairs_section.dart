// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/model_selection.dart';
import '../common/module_label.dart';
import '../common/section_note.dart';
import '../dashboard/cubits/downloads_bloc.dart';
import '../dashboard/cubits/settings_cubit.dart';
import 'language_pair_tile.dart';
import 'model_failure_row.dart';
import '../common/tile_grid.dart';

/// The languages a line can be dubbed into. A translator and a voice are
/// only ever useful together, so a language is one tile: downloaded, picked
/// and deleted as a pair.
class LanguagePairsSection extends StatelessWidget {
  const LanguagePairsSection({
    super.key,
    required this.selection,
    required this.downloads,
    required this.running,
  });

  final ModelSelection selection;
  final DownloadsState downloads;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DownloadsBloc>();
    final settings = context.read<SettingsCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModuleLabel(number: '02', label: l10n.sectionLanguages),
        const SizedBox(height: 4),
        SectionNote(l10n.sectionLanguagesNote),
        const SizedBox(height: 12),
        TileGrid(
          children: [
            for (final pair in selection.languagePairs)
              LanguagePairTile(
                key: ValueKey('languageTile-${pair.language}'),
                pair: pair,
                selected: pair.language == selection.settings.targetLanguage,
                running: running,
                isStopping: downloads.isStopping,
                onSelect: running ? null : () => settings.selectTargetLanguage(pair.language),
                onInstall: (state) => cubit.add(ModelInstallAsked(state)),
                onPause: (state) => cubit.add(DownloadPaused(state.model.id)),
                onCancel: (state) => cubit.add(DownloadCancelled(state.model.id)),
                onRemove: (state) => cubit.add(ModelRemoved(state)),
              ),
          ],
        ),
        for (final pair in selection.languagePairs)
          for (final part in pair.parts)
            if (part.error != null) ...[
              const SizedBox(height: 10),
              ModelFailureRow(state: part),
            ],
      ],
    );
  }
}

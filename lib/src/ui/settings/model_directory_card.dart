// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../common/setting_card.dart';
import '../dashboard/cubits/downloads_cubit.dart';
import 'settings_layout.dart';

/// Where the downloaded models are kept, and a way to open that folder.
class ModelDirectoryCard extends StatelessWidget {
  const ModelDirectoryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final path = BlocSelector<DownloadsCubit, DownloadsState, String>(
      selector: (downloads) => downloads.modelDirectoryPath,
      builder: (context, directory) =>
          SelectableText(directory, style: Theme.of(context).textTheme.bodyMedium),
    );
    final open = OutlinedButton.icon(
      onPressed: context.read<DownloadsCubit>().openModelDirectory,
      icon: const Icon(Icons.folder_open_rounded),
      label: Text(l10n.openInExplorer),
    );
    return SettingCard(
      title: l10n.settingsModelDirectory,
      subtitle: l10n.modelDirectoryNote,
      child: LayoutBuilder(
        builder: (context, constraints) =>
            constraints.maxWidth < SettingsLayout.fieldBesideButtonWidth
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  path,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: open),
                ],
              )
            : Row(
                children: [
                  Expanded(child: path),
                  const SizedBox(width: 16),
                  open,
                ],
              ),
      ),
    );
  }
}

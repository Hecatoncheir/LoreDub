// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/screen_reading.dart';
import '../common/module_label.dart';
import '../dashboard/cubits/settings_cubit.dart';
import 'snapshot_hotkey_line.dart';
import 'snapshot_start_button.dart';

/// The session that reads nothing until it is asked: the key picks a
/// piece of the screen out, and that piece alone is translated and voiced.
///
/// It is the reading for a game whose subtitles stand nowhere in
/// particular, and for a player who would rather ask than be read to.
class SnippetOnlyCard extends StatelessWidget {
  const SnippetOnlyCard({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<SettingsCubit, SettingsState>(
    builder: (context, state) => Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModuleLabel(number: '02', label: AppLocalizations.of(context).areaSnippetOnly),
            const SizedBox(height: 14),
            SnapshotHotkeyLine(settings: state.settings),
            const SizedBox(height: 14),
            SnapshotStartButton(reading: ScreenReading.snippets),
          ],
        ),
      ),
    ),
  );
}

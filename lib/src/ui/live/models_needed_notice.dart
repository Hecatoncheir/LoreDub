// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/model_selection.dart';
import '../../../l10n/app_localizations.dart';
import '../theme.dart';
import '../dashboard/cubits/downloads_bloc.dart';
import '../dashboard/cubits/settings_cubit.dart';
import '../dashboard/cubits/shell_cubit.dart';
import '../dashboard/dashboard_context.dart';

/// Says the packages a screen needs are missing, and leads to them. What
/// counts as missing is the screen's own question: the snapshot session
/// does without whisper.
class ModelsNeededNotice extends StatelessWidget {
  const ModelsNeededNotice({super.key, required this.ready});

  final bool Function(ModelSelection selection) ready;

  // What is missing is decided by the packages and the chosen language
  // together, so this notice watches both.
  @override
  Widget build(BuildContext context) => BlocBuilder<DownloadsBloc, DownloadsState>(
    buildWhen: whenChanged((downloads) => downloads.installed),
    builder: (context, _) => BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, _) => ready(context.selection)
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Card(
                child: ListTile(
                  leading: Icon(Icons.download_rounded, color: context.colors.warning),
                  title: Text(AppLocalizations.of(context).modelsNeededTitle),
                  subtitle: Text(AppLocalizations.of(context).modelsNeededNote),
                  trailing: TextButton(
                    onPressed: () =>
                        context.read<ShellCubit>().selectSection(DashboardSection.models),
                    child: Text(AppLocalizations.of(context).modelsNeededAction),
                  ),
                ),
              ),
            ),
    ),
  );
}

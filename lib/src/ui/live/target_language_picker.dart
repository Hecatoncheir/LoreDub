// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/services/model_catalog.dart';
import '../../../l10n/app_localizations.dart';
import '../language_names.dart';
import '../dashboard/cubits/downloads_bloc.dart';
import '../dashboard/cubits/session_bloc.dart';
import '../dashboard/cubits/settings_bloc.dart';
import '../dashboard/dashboard_context.dart';
import '../common/language_row.dart';
import 'start_button.dart';

/// The language the game is dubbed into. Picking it here is the same choice
/// the models screen offers: it selects the translator and the voice together
/// and is remembered between runs.
class TargetLanguagePicker extends StatelessWidget {
  const TargetLanguagePicker({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<SettingsBloc, SettingsState>(
    // Which languages read as ready depends on what is downloaded.
    builder: (context, settings) => BlocBuilder<DownloadsBloc, DownloadsState>(
      buildWhen: whenChanged((downloads) => downloads.installed),
      builder: (context, _) => BlocBuilder<SessionBloc, SessionState>(
        buildWhen: whenChanged((pipeline) => pipeline.running),
        builder: (context, pipeline) =>
            _build(context, settings.settings.targetLanguage, running: pipeline.running),
      ),
    ),
  );

  Widget _build(BuildContext context, String selected, {required bool running}) {
    final l10n = AppLocalizations.of(context);
    final languages = dubbingLanguages;
    final selection = context.selection;
    return LanguageRow(
      field: DropdownButtonFormField<String>(
        key: const ValueKey('targetLanguage'),
        // A value stored by an older build may no longer be on offer.
        initialValue: languages.contains(selected) ? selected : languages.first,
        isDense: true,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.targetLanguageLabel, isDense: true),
        items: [
          for (final language in languages)
            DropdownMenuItem(
              value: language,
              child: Text(
                selection.isLanguageReady(language)
                    ? spokenLanguageName(l10n, language)
                    : l10n.languageWithoutModels(spokenLanguageName(l10n, language)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: running
            ? null
            : (value) {
                if (value != null) context.read<SettingsBloc>().add(TargetLanguageChosen(value));
              },
      ),
      action: StartButton(),
    );
  }
}

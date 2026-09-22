// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/app_settings.dart';
import '../../domain/model_selection.dart';
import '../../../l10n/app_localizations.dart';
import '../language_names.dart';
import '../common/bloc/session_bloc.dart';
import '../models/bloc/downloads_bloc.dart';
import '../settings/bloc/settings_bloc.dart';
import '../common/dashboard_context.dart';
import '../common/language_row.dart';

/// What the text on the screen is in and what it is said in, picked as one:
/// a language whose voice is on disk, read as it is, or English translated
/// into one. Windows OCR detects nothing, so the text's language is named
/// rather than found, and what it is said in is the dubbing language itself
/// -- the one the models screen shows, which the user asked for this choice
/// to move with it.
class TextLanguagePicker extends StatelessWidget {
  const TextLanguagePicker({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<SettingsBloc, SettingsState>(
    // Which languages are on offer depends on which voices are downloaded.
    builder: (context, state) => BlocBuilder<DownloadsBloc, DownloadsState>(
      buildWhen: whenChanged((downloads) => downloads.installed),
      builder: (context, _) => BlocBuilder<SessionBloc, SessionState>(
        buildWhen: whenChanged((pipeline) => pipeline.running),
        builder: (context, pipeline) => _build(context, state.settings, locked: pipeline.running),
      ),
    ),
  );

  /// A language read as it is by its name, and English translated into one
  /// the way its translator is named.
  static String _named(AppLocalizations l10n, ScreenLanguages languages) =>
      languages.text == languages.dubbing
      ? spokenLanguageName(l10n, languages.text)
      : l10n.modelTranslationTitle(spokenLanguageName(l10n, languages.dubbing));

  Widget _build(BuildContext context, AppSettings settings, {required bool locked}) {
    final l10n = AppLocalizations.of(context);
    final chosen = (text: settings.textLanguage, dubbing: settings.targetLanguage);
    return LanguageRow(
      // Wide enough for the translation's arrow and both of its languages.
      fieldWidth: 260,
      field: DropdownButtonFormField<ScreenLanguages>(
        // Keyed by the value: the dubbing language picked elsewhere, or a
        // voice taken off the disk, changes it from outside the field.
        key: ValueKey('textLanguage-${chosen.text}-${chosen.dubbing}'),
        initialValue: chosen,
        isDense: true,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.textLanguageLabel, isDense: true),
        items: [
          for (final languages in context.selection.screenLanguages)
            DropdownMenuItem(value: languages, child: Text(_named(l10n, languages))),
        ],
        onChanged: locked
            ? null
            : (value) {
                if (value == null) return;
                context.read<SettingsBloc>().add(
                  ScreenLanguageChosen(text: value.text, dubbing: value.dubbing),
                );
              },
      ),
      action: Text(
        l10n.textLanguageNote,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

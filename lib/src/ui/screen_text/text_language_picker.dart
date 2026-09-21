// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/app_settings.dart';
import '../../domain/spoken_language.dart';
import '../../../l10n/app_localizations.dart';
import '../language_names.dart';
import '../dashboard/cubits/session_bloc.dart';
import '../dashboard/cubits/settings_bloc.dart';
import '../dashboard/dashboard_context.dart';
import '../common/language_row.dart';

/// The language of text read off the screen. Windows OCR detects nothing and
/// the translators read only English, so the choice is English or the
/// dubbing language itself, which is then voiced as it is.
class TextLanguagePicker extends StatelessWidget {
  const TextLanguagePicker({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<SettingsBloc, SettingsState>(
    builder: (context, state) => BlocBuilder<SessionBloc, SessionState>(
      buildWhen: whenChanged((pipeline) => pipeline.running),
      builder: (context, pipeline) => _build(context, state.settings, locked: pipeline.running),
    ),
  );

  Widget _build(BuildContext context, AppSettings settings, {required bool locked}) {
    final l10n = AppLocalizations.of(context);
    final languages = {fallbackSpokenLanguage, settings.targetLanguage};
    return LanguageRow(
      field: DropdownButtonFormField<String>(
        // Keyed by the value: a new dubbing language can change it from
        // outside the field.
        key: ValueKey('textLanguage-${settings.textLanguage}'),
        initialValue: settings.textLanguage,
        isDense: true,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.textLanguageLabel, isDense: true),
        items: [
          for (final language in languages)
            DropdownMenuItem(value: language, child: Text(spokenLanguageName(l10n, language))),
        ],
        onChanged: locked
            ? null
            : (value) {
                if (value != null) {
                  context.read<SettingsBloc>().add(
                    SettingsChanged(settings.copyWith(screenLanguage: value)),
                  );
                }
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

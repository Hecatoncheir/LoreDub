// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/app_settings.dart';
import '../../domain/spoken_language.dart';
import '../../../l10n/app_localizations.dart';
import '../language_names.dart';
import '../dashboard/cubits/session_bloc.dart';
import '../dashboard/cubits/settings_cubit.dart';
import '../dashboard/dashboard_context.dart';
import '../common/language_row.dart';

/// Language of the original speech. Naming it skips whisper's detection pass,
/// which is a noticeable share of the delay before a phrase is voiced.
class LanguageControls extends StatelessWidget {
  const LanguageControls({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<SettingsCubit, SettingsState>(
    builder: (context, state) => BlocBuilder<SessionBloc, SessionState>(
      buildWhen: whenChanged((pipeline) => (pipeline.running, pipeline.detectedLanguage)),
      builder: (context, pipeline) => _build(context, state.settings, pipeline),
    ),
  );

  Widget _build(BuildContext context, AppSettings settings, SessionState pipeline) {
    final l10n = AppLocalizations.of(context);
    final locked = pipeline.running;
    final detected = settings.detectSourceLanguage ? pipeline.detectedLanguage : null;
    return LanguageRow(
      field: DropdownButtonFormField<String>(
        key: const ValueKey('sourceLanguage'),
        initialValue: settings.sourceLanguage,
        isDense: true,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.sourceLanguageLabel, isDense: true),
        items: [
          for (final language in spokenLanguages)
            DropdownMenuItem(
              value: language,
              child: Text(spokenLanguageName(l10n, language)),
            ),
        ],
        onChanged: locked || settings.detectSourceLanguage
            ? null
            : (value) {
                if (value != null) {
                  context.read<SettingsCubit>().update(settings.copyWith(sourceLanguage: value));
                }
              },
      ),
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: settings.detectSourceLanguage,
            onChanged: locked
                ? null
                : (value) => context.read<SettingsCubit>().update(
                    settings.copyWith(detectSourceLanguage: value),
                  ),
          ),
          const SizedBox(width: 6),
          Flexible(
            // Once whisper has decided, its answer takes the label's place:
            // the switch itself already says that detection is on.
            child: Text(
              detected == null
                  ? l10n.detectLanguage
                  : l10n.detectedLanguage(spokenLanguageName(l10n, detected)),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: detected == null ? null : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../../domain/spoken_language.dart';
import '../common/setting_card.dart';
import '../dashboard/cubits/settings_cubit.dart';
import '../language_names.dart';

/// The language LoreDub speaks to the player in. Where the original comes
/// from is no longer a setting: the game's sound is dubbed on Live, and the
/// screen is read on its own page, which keeps the frame it reads.
class InterfaceLanguageCard extends StatelessWidget {
  const InterfaceLanguageCard({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingCard(
      title: l10n.settingsInterfaceLanguage,
      subtitle: l10n.interfaceLanguageNote,
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<String>(
          segments: [
            for (final language in interfaceLanguages)
              ButtonSegment(value: language, label: Text(interfaceLanguageName(language))),
          ],
          selected: {settings.interfaceLanguage},
          onSelectionChanged: (selection) => context.read<SettingsCubit>().update(
            settings.copyWith(interfaceLanguage: selection.first),
          ),
        ),
      ),
    );
  }
}

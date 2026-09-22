// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../common/setting_card.dart';
import 'bloc/settings_bloc.dart';

/// How large the interface itself is drawn, beside the language it speaks:
/// the two things a player sets once, for their own eyes rather than for the
/// dubbing.
class ScaleCard extends StatelessWidget {
  const ScaleCard({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = l10n.scaleValue((settings.chosenScale * 100).round());
    return SettingCard(
      title: l10n.settingsScale,
      subtitle: value,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Slider(
            key: const ValueKey('interfaceScale'),
            value: settings.chosenScale,
            min: AppSettings.smallestScale,
            max: AppSettings.largestScale,
            divisions: AppSettings.scaleDivisions,
            label: value,
            onChanged: (scale) => context.read<SettingsBloc>().add(
              SettingsChanged(settings.copyWith(interfaceScale: scale)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.scaleNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

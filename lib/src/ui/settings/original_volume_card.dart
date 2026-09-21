// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../common/labeled_switch.dart';
import '../common/setting_card.dart';
import '../dashboard/cubits/settings_bloc.dart';

/// How far the game is turned down under the dubbing, and whether only while
/// a line is spoken.
///
/// The floor is the capture's: the game is heard through this same volume,
/// and silenced outright it would never be dubbed at all. Only the screen
/// session, which has no ear in the game, may take it all the way down -- and
/// it asks for that on its own page.
class OriginalVolumeCard extends StatelessWidget {
  const OriginalVolumeCard({super.key, required this.settings, required this.running});

  final AppSettings settings;
  final bool running;

  void _update(BuildContext context, AppSettings value) =>
      context.read<SettingsBloc>().add(SettingsChanged(value));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final percent = (settings.duckedVolume * 100).round();
    return SettingCard(
      title: l10n.settingsOriginalVolume,
      subtitle: l10n.originalVolumeValue(percent),
      child: Column(
        children: [
          Slider(
            key: const ValueKey('originalVolume'),
            value: settings.duckedVolume,
            min: AppSettings.audibleDuck,
            max: AppSettings.loudestDuck,
            divisions: AppSettings.duckDivisions,
            label: '$percent%',
            onChanged: running
                ? null
                : (value) => _update(context, settings.copyWith(originalVolume: value)),
          ),
          const SizedBox(height: 4),
          LabeledSwitch(
            value: settings.duckWhileSpeaking,
            label: l10n.duckWhileSpeaking,
            onChanged: running
                ? null
                : (value) => _update(context, settings.copyWith(duckWhileSpeaking: value)),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.duckWhileSpeakingNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

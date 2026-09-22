// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../common/labeled_switch.dart';
import '../common/setting_card.dart';
import 'bloc/settings_bloc.dart';

/// How fast a line is read, and whether the voice hurries while lines queue
/// up for it.
class SpeechPaceCard extends StatelessWidget {
  const SpeechPaceCard({super.key, required this.settings, required this.running});

  final AppSettings settings;
  final bool running;

  void _update(BuildContext context, AppSettings value) =>
      context.read<SettingsBloc>().add(SettingsChanged(value));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pace = l10n.speedValue(settings.chosenSpeed.toStringAsFixed(2));
    return SettingCard(
      title: l10n.settingsTtsSpeed,
      subtitle: pace,
      child: Column(
        children: [
          Slider(
            key: const ValueKey('ttsSpeed'),
            value: settings.chosenSpeed,
            min: AppSettings.slowestSpeech,
            max: AppSettings.fastestSpeech,
            divisions: AppSettings.speechDivisions,
            label: pace,
            onChanged: running
                ? null
                : (value) => _update(context, settings.copyWith(ttsSpeed: value)),
          ),
          const SizedBox(height: 4),
          LabeledSwitch(
            switchKey: const ValueKey('hurryWhenQueued'),
            value: settings.hurryWhenQueued,
            label: l10n.hurryWhenQueued,
            onChanged: running
                ? null
                : (value) => _update(context, settings.copyWith(hurryWhenQueued: value)),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.hurryWhenQueuedNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

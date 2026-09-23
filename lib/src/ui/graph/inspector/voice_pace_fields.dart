// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/app_settings.dart';
import '../../settings/bloc/settings_bloc.dart';
import '../canvas/pipeline_facts.dart';
import 'inspector_field.dart';
import 'inspector_note.dart';
import 'inspector_toggle.dart';

/// How fast the voice reads, and whether it hurries while lines wait for
/// it: the part of a voice's panel both schemes' voices share, a line of
/// the screen being read at the same pace as a line of the game.
class VoicePaceFields extends StatelessWidget {
  const VoicePaceFields({super.key, required this.facts});

  final PipelineFacts facts;

  void _update(BuildContext context, AppSettings value) =>
      context.read<SettingsBloc>().add(SettingsChanged(value));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = facts.settings;
    final locked = facts.running;
    final pace = l10n.speedValue(settings.chosenSpeed.toStringAsFixed(2));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorField(
          label: '${l10n.settingsTtsSpeed} · $pace',
          // The same range as the settings screen, for the same reason as the
          // volume: a pace set here is one the other screen can set again.
          child: Slider(
            key: const ValueKey('graphTtsSpeed'),
            value: settings.chosenSpeed,
            min: AppSettings.slowestSpeech,
            max: AppSettings.fastestSpeech,
            divisions: AppSettings.speechDivisions,
            // What rises over the thumb while it is dragged: without it
            // Material draws no value at all, and the number over the pointer
            // is what the hand is watching rather than the caption above.
            label: pace,
            onChanged: locked
                ? null
                : (value) => _update(context, settings.copyWith(ttsSpeed: value)),
          ),
        ),
        InspectorToggle(
          label: l10n.hurryWhenQueued,
          value: settings.hurryWhenQueued,
          enabled: !locked,
          onChanged: (value) => _update(context, settings.copyWith(hurryWhenQueued: value)),
        ),
        InspectorNote(text: l10n.hurryWhenQueuedNote),
      ],
    );
  }
}

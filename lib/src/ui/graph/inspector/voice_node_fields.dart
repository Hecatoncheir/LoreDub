// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/app_settings.dart';
import '../../../domain/compute_device.dart';
import '../../settings/bloc/settings_bloc.dart';
import '../canvas/pipeline_facts.dart';
import 'inspector_choices.dart';
import 'inspector_field.dart';
import 'inspector_toggle.dart';
import 'stage_device_picker.dart';
import 'voice_glossary_note.dart';
import 'voice_pace_fields.dart';
import 'voice_picker_field.dart';

/// The voice node's panel: the voice mode, the voice picked by hand, the
/// pace, the converter's device, whether the characters are remembered, and
/// what the lines are read with while no pack of the glossary is on.
class VoiceNodeFields extends StatelessWidget {
  const VoiceNodeFields({super.key, required this.facts, required this.availability});

  final PipelineFacts facts;
  final ComputeAvailability availability;

  void _update(BuildContext context, AppSettings value) =>
      context.read<SettingsBloc>().add(SettingsChanged(value));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = facts.settings;
    final locked = facts.running;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorField(
          label: l10n.settingsVoice,
          child: InspectorChoices<VoiceMode>(
            value: settings.voiceMode,
            enabled: !locked,
            options: {
              VoiceMode.automatic: l10n.voiceAutomatic,
              VoiceMode.chosen: l10n.voiceFixed,
              VoiceMode.original: l10n.voiceOriginal,
            },
            onChanged: (value) => _update(context, settings.withVoiceMode(value)),
          ),
        ),
        if (settings.voiceMode == VoiceMode.chosen) VoicePickerField(facts: facts),
        VoicePaceFields(facts: facts),
        if (facts.selection.needsVoiceConverter)
          StageDevicePicker(
            stage: ComputeStage.voiceConversion,
            facts: facts,
            availability: availability,
          ),
        InspectorToggle(
          label: l10n.voiceBank,
          value: settings.voiceBank,
          enabled: !locked,
          onChanged: (value) => _update(context, settings.copyWith(voiceBank: value)),
        ),
        VoiceGlossaryNote(facts: facts),
      ],
    );
  }
}

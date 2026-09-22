// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/app_settings.dart';
import '../../../domain/compute_device.dart';
import '../../../domain/pipeline_graph.dart';
import '../../compute_names.dart';
import '../../settings/bloc/settings_bloc.dart';
import '../bloc/pipeline_graph_bloc.dart';
import '../canvas/pipeline_facts.dart';
import 'inspector_choices.dart';
import 'inspector_field.dart';
import 'inspector_note.dart';
import 'inspector_toggle.dart';
import 'stage_device_picker.dart';

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
    final pace = l10n.speedValue(settings.chosenSpeed.toStringAsFixed(2));
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
        if (settings.voiceMode == VoiceMode.chosen)
          InspectorField(
            label: l10n.voiceFieldLabel,
            child: DropdownButtonFormField<String>(
              key: ValueKey('graph-voice-${facts.selection.voice}'),
              initialValue: facts.selection.voice,
              isExpanded: true,
              items: [
                for (final option in facts.selection.availableVoices)
                  DropdownMenuItem(
                    value: option.id,
                    child: Text(voiceLabel(l10n, option), maxLines: 1),
                  ),
              ],
              onChanged: locked
                  ? null
                  : (voice) {
                      if (voice != null) _update(context, settings.copyWith(voice: voice));
                    },
            ),
          ),
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
        if (_glossaryNote(
              l10n,
              drawn: context.select<PipelineGraphBloc, bool>(
                (graph) => graph.state.graph.ofKind(PipelineNodeKind.glossary).isNotEmpty,
              ),
            )
            case final note?)
          InspectorNote(text: note),
      ],
    );
  }

  /// What the lines are read with while no pack is switched on, when
  /// something is written down: nothing at all once the scheme [drawn]
  /// glossaries -- it says what is read then -- and otherwise everything.
  String? _glossaryNote(AppLocalizations l10n, {required bool drawn}) {
    if (facts.glossary.activePacks.isNotEmpty || facts.glossary.isEmpty) return null;
    return drawn ? l10n.pipelineVoiceNoGlossary : l10n.pipelineVoiceWholeGlossary;
  }
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/compute_device.dart';
import '../bloc/pipeline_graph_bloc.dart';
import '../canvas/pipeline_facts.dart';
import 'inspector_note.dart';
import 'inspector_toggle.dart';
import 'stage_device_picker.dart';

/// The character detection's panel: whether the voices behind the screen
/// are told apart -- the switch, with what it says under it on the subtitle
/// frame's card -- and where the converter that hears them runs.
///
/// The switch is the node's route as well: thrown here, on the card or by
/// drawing either of the node's lines, it is the one setting, and the
/// canvas answers each the same way.
class DetectionNodeFields extends StatelessWidget {
  const DetectionNodeFields({super.key, required this.facts, required this.availability});

  final PipelineFacts facts;
  final ComputeAvailability availability;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // It is the converter that hears who is speaking, so the switch waits
    // for it, as it does on the subtitle frame's card.
    final ready = facts.selection.measuresVoices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorToggle(
          key: const ValueKey('graphScreenVoices'),
          label: l10n.screenVoices,
          value: facts.settings.screenVoices && ready,
          enabled: ready && !facts.running,
          onChanged: (heard) =>
              context.read<PipelineGraphBloc>().add(PipelineVoicesSwitched(heard: heard)),
        ),
        InspectorNote(text: ready ? l10n.screenVoicesNote : l10n.voiceOriginalMissing),
        if (ready)
          StageDevicePicker(
            stage: ComputeStage.voiceConversion,
            facts: facts,
            availability: availability,
          ),
      ],
    );
  }
}

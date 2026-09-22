// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/compute_device.dart';
import '../../settings/bloc/settings_bloc.dart';
import '../../model_names.dart';
import '../canvas/pipeline_facts.dart';
import 'inspector_field.dart';
import 'inspector_note.dart';
import 'inspector_toggle.dart';
import 'stage_device_picker.dart';

/// The recognition node's panel: the Whisper build among those on disk, what
/// it runs on, and the shorter window it may listen over.
class RecognitionNodeFields extends StatelessWidget {
  const RecognitionNodeFields({super.key, required this.facts, required this.availability});

  final PipelineFacts facts;
  final ComputeAvailability availability;

  void _choose(BuildContext context, String? model) {
    if (model == null) return;
    context.read<SettingsBloc>().add(RecognitionModelChosen(model));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selection = facts.selection;
    final settings = facts.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorField(
          label: l10n.pipelineModelLabel,
          child: DropdownButtonFormField<String>(
            key: ValueKey('graph-model-${selection.recognition?.model.id}'),
            initialValue: selection.recognition?.model.id,
            isExpanded: true,
            items: [
              for (final install in selection.recognitionModels)
                if (install.installed)
                  DropdownMenuItem(
                    value: install.model.id,
                    child: Text(whisperShortName(install.model), maxLines: 1),
                  ),
            ],
            onChanged: facts.running ? null : (model) => _choose(context, model),
          ),
        ),
        StageDevicePicker(
          stage: ComputeStage.recognition,
          facts: facts,
          availability: availability,
        ),
        InspectorToggle(
          label: l10n.roughRecognition,
          value: settings.roughRecognition,
          enabled: !facts.running,
          onChanged: (value) => context.read<SettingsBloc>().add(
            SettingsChanged(
              settings.copyWith(roughRecognition: value),
            ),
          ),
        ),
        InspectorNote(text: l10n.roughRecognitionNote),
      ],
    );
  }
}

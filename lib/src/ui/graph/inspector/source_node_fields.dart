// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/app_settings.dart';
import '../../dashboard/cubits/settings_bloc.dart';
import '../canvas/pipeline_facts.dart';
import 'inspector_choices.dart';
import 'inspector_field.dart';
import 'inspector_note.dart';
import '../../common/game_picker.dart';

/// The source node's panel: which game is listened to, and whether to it
/// alone or to the whole output.
class SourceNodeFields extends StatelessWidget {
  const SourceNodeFields({super.key, required this.facts});

  final PipelineFacts facts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = facts.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          // The characters screen holds the game it records through, and
          // this is the same choice under another window.
          child: GamePicker(enabled: !facts.running && !facts.recordingVoice),
        ),
        InspectorField(
          label: l10n.settingsAudioSource,
          child: InspectorChoices<AudioCaptureSource>(
            value: settings.audioCaptureSource,
            enabled: !facts.running,
            options: {
              AudioCaptureSource.process: l10n.sourceProcess,
              AudioCaptureSource.system: l10n.sourceSystem,
            },
            onChanged: (value) => context.read<SettingsBloc>().add(
              SettingsChanged(
                settings.copyWith(audioCaptureSource: value),
              ),
            ),
          ),
        ),
        InspectorNote(
          text: settings.audioCaptureSource == AudioCaptureSource.process
              ? l10n.captureProcessNote
              : l10n.captureSystemNote,
        ),
      ],
    );
  }
}

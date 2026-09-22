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

/// The output node's panel: how far the game is turned down under the
/// dubbing, and whether only while a line is spoken.
class OutputNodeFields extends StatelessWidget {
  const OutputNodeFields({super.key, required this.facts});

  final PipelineFacts facts;

  void _update(BuildContext context, AppSettings value) =>
      context.read<SettingsBloc>().add(SettingsChanged(value));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = facts.settings;
    final locked = facts.running;
    final percent = (settings.duckedVolume * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorField(
          label: '${l10n.settingsOriginalVolume} · ${l10n.originalVolumeValue(percent)}',
          // The same range as the settings screen: a number set here is one
          // the other screen can set again.
          child: Slider(
            key: const ValueKey('graphOriginalVolume'),
            value: settings.duckedVolume,
            min: AppSettings.audibleDuck,
            max: AppSettings.loudestDuck,
            divisions: AppSettings.duckDivisions,
            label: '$percent%',
            onChanged: locked
                ? null
                : (value) => _update(context, settings.copyWith(originalVolume: value)),
          ),
        ),
        InspectorToggle(
          label: l10n.duckWhileSpeaking,
          value: settings.duckWhileSpeaking,
          enabled: !locked,
          onChanged: (value) => _update(context, settings.copyWith(duckWhileSpeaking: value)),
        ),
        InspectorNote(text: l10n.duckWhileSpeakingNote),
        InspectorNote(text: l10n.pipelineOutputNote),
      ],
    );
  }
}

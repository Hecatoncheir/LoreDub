// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../compute_names.dart';
import '../../settings/bloc/settings_bloc.dart';
import '../canvas/pipeline_facts.dart';
import 'inspector_field.dart';

/// The voice every line is read in where nothing chooses another, out of
/// those the dubbing language's package ships.
class VoicePickerField extends StatelessWidget {
  const VoicePickerField({super.key, required this.facts});

  final PipelineFacts facts;

  void _choose(BuildContext context, String? voice) {
    if (voice == null) return;
    context.read<SettingsBloc>().add(SettingsChanged(facts.settings.copyWith(voice: voice)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InspectorField(
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
        onChanged: facts.running ? null : (voice) => _choose(context, voice),
      ),
    );
  }
}

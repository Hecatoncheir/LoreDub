// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/model_selection.dart';
import '../compute_names.dart';
import 'bloc/settings_bloc.dart';

/// The voice picked by hand out of those the language's package ships.
///
/// It can be picked at any moment, a session running or not: the worker is
/// told, and the next line is read in it.
class VoiceChoiceField extends StatelessWidget {
  const VoiceChoiceField({super.key, required this.selection, this.dense = false});

  final ModelSelection selection;

  /// As low as the language field it stands in a row with.
  final bool dense;

  void _choose(BuildContext context, String? voice) {
    if (voice == null) return;
    context.read<SettingsBloc>().add(SettingsChanged(selection.settings.copyWith(voice: voice)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DropdownButtonFormField<String>(
      // Keyed by the language, which is picked a field away on the pages
      // this stands on: the voices change under the field, and the value it
      // held would name one no longer on the list. And by the voice, which
      // is changed elsewhere too -- on Live, in the node panel.
      key: ValueKey('voice-${selection.settings.targetLanguage}-${selection.voice}'),
      initialValue: selection.voice,
      isDense: dense,
      decoration: InputDecoration(labelText: l10n.voiceFieldLabel, isDense: dense),
      items: [
        for (final voice in selection.availableVoices)
          DropdownMenuItem(value: voice.id, child: Text(voiceLabel(l10n, voice))),
      ],
      onChanged: (value) => _choose(context, value),
    );
  }
}

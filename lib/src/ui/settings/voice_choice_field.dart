// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/model_selection.dart';
import '../compute_names.dart';
import '../dashboard/cubits/settings_bloc.dart';

/// The voice picked by hand out of those the language's package ships.
///
/// It can be picked at any moment, a session running or not: the worker is
/// told, and the next line is read in it.
class VoiceChoiceField extends StatelessWidget {
  const VoiceChoiceField({super.key, required this.selection});

  final ModelSelection selection;

  void _choose(BuildContext context, String? voice) {
    if (voice == null) return;
    context.read<SettingsBloc>().add(SettingsChanged(selection.settings.copyWith(voice: voice)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DropdownButtonFormField<String>(
      key: const ValueKey('voice'),
      initialValue: selection.voice,
      decoration: InputDecoration(labelText: l10n.voiceFieldLabel),
      items: [
        for (final voice in selection.availableVoices)
          DropdownMenuItem(value: voice.id, child: Text(voiceLabel(l10n, voice))),
      ],
      onChanged: (value) => _choose(context, value),
    );
  }
}

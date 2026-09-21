// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/compute_device.dart';
import '../../../domain/spoken_language.dart';
import '../../dashboard/cubits/settings_bloc.dart';
import '../../language_names.dart';
import '../canvas/pipeline_facts.dart';
import 'inspector_choices.dart';
import 'inspector_field.dart';
import 'inspector_note.dart';
import 'stage_device_picker.dart';

/// The translation node's panel: English in, the dubbing language out, and
/// what the translator runs on.
///
/// What comes in is settled by what feeds this node: whisper is run with -tr
/// and hands English over whatever the game speaks, so the language the game
/// is listened to in -- a setting of Live's, and one that says nothing about
/// this stage -- is not what is shown here.
class TranslationNodeFields extends StatelessWidget {
  const TranslationNodeFields({super.key, required this.facts, required this.availability});

  final PipelineFacts facts;
  final ComputeAvailability availability;

  void _choose(BuildContext context, String? language) {
    if (language == null) return;
    context.read<SettingsBloc>().add(TargetLanguageChosen(language));
  }

  String _languageLabel(AppLocalizations l10n, String language) {
    final name = translationTargetName(l10n, language);
    return facts.selection.isLanguageReady(language) ? name : l10n.languageWithoutModels(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final target = facts.settings.targetLanguage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorField(
          label: l10n.translationFromLabel,
          child: InspectorChoices<String>(
            value: fallbackSpokenLanguage,
            enabled: false,
            options: {fallbackSpokenLanguage: spokenLanguageName(l10n, fallbackSpokenLanguage)},
            onChanged: (_) {},
          ),
        ),
        InspectorNote(text: l10n.translationFromWhisper),
        const SizedBox(height: 14),
        InspectorField(
          label: l10n.translationToLabel,
          child: DropdownButtonFormField<String>(
            key: ValueKey('graph-language-$target'),
            initialValue: target,
            isExpanded: true,
            items: [
              for (final pair in facts.selection.languagePairs)
                DropdownMenuItem(
                  value: pair.language,
                  enabled: facts.selection.isLanguageReady(pair.language),
                  child: Text(_languageLabel(l10n, pair.language), maxLines: 1),
                ),
            ],
            onChanged: facts.running ? null : (language) => _choose(context, language),
          ),
        ),
        StageDevicePicker(
          stage: ComputeStage.translation,
          facts: facts,
          availability: availability,
        ),
      ],
    );
  }
}

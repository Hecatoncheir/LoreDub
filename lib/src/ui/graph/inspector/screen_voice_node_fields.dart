// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../canvas/pipeline_facts.dart';
import 'inspector_note.dart';
import 'voice_glossary_note.dart';
import 'voice_pace_fields.dart';
import 'voice_picker_field.dart';

/// The voice node's panel on the Screen page's scheme: the one voice every
/// line of the screen is read in, the pace, and what the lines are read
/// with while no pack of the glossary is on.
///
/// There is no mode to choose. A line on a screen has no sound of its own to
/// follow a speaker by, so it is read in the voice picked here -- with the
/// timbre of whoever was speaking laid over it, where the character
/// detection hears them.
class ScreenVoiceNodeFields extends StatelessWidget {
  const ScreenVoiceNodeFields({super.key, required this.facts});

  final PipelineFacts facts;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      VoicePickerField(facts: facts),
      InspectorNote(text: AppLocalizations.of(context).pipelineScreenVoiceNote),
      VoicePaceFields(facts: facts),
      VoiceGlossaryNote(facts: facts),
    ],
  );
}

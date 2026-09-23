// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../common/game_picker.dart';
import '../../screen_text/screen_source_picker.dart';
import '../canvas/pipeline_facts.dart';
import 'inspector_note.dart';

/// The screen node's panel: whether the game's window is read or the whole
/// screen, which game that window is, and where the text comes from.
///
/// The language the text is in is not chosen here: it is the line drawn out
/// of the node -- through the translator, English; past it, the dubbing
/// language, read as it is -- as the Screen page's own picker chooses it.
class ScreenNodeFields extends StatelessWidget {
  const ScreenNodeFields({super.key, required this.facts});

  final PipelineFacts facts;

  @override
  Widget build(BuildContext context) {
    final settings = facts.settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: ScreenSourcePicker(settings: settings, locked: facts.running),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          // Nothing is read out of a window while the whole screen is what
          // is read, so there is nothing to choose; and the characters
          // screen holds the game it records through.
          child: GamePicker(
            enabled: !facts.running && !facts.recordingVoice && !settings.readsWholeScreen,
          ),
        ),
        InspectorNote(text: AppLocalizations.of(context).pipelineScreenNodeNote),
      ],
    );
  }
}

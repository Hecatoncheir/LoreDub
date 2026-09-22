// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../common/dashboard_context.dart';
import '../settings/bloc/settings_bloc.dart';
import '../settings/voice_choice_field.dart';
import 'screen_layout.dart';
import 'text_language_picker.dart';

/// What the page reads and says, and in which voice: the language on the
/// left, and the voice in the room the row has left, out to the edge the
/// start button above stands on. Both readings are read in that one voice,
/// so it is chosen here once, as the user asked, while each keeps its own
/// start button in its own card. Narrower than the two of them, the voice
/// goes under the language.
class ScreenLanguageAndVoice extends StatelessWidget {
  const ScreenLanguageAndVoice({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // The voices are the dubbing language's, which the language beside
      // it picks.
      final voice = BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, _) => VoiceChoiceField(selection: context.selection, dense: true),
      );
      return constraints.maxWidth < ScreenLayout.voiceBesideLanguageWidth
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [const TextLanguagePicker(), const SizedBox(height: 14), voice],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TextLanguagePicker(),
                const SizedBox(width: 24),
                Expanded(child: voice),
              ],
            );
    },
  );
}

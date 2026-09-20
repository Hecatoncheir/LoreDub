// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../dashboard/cubits/pipeline_cubit.dart';
import '../dashboard/cubits/settings_cubit.dart';
import '../settings/original_volume_card.dart';
import '../settings/paired_cards.dart';
import '../settings/settings_layout.dart';
import '../settings/speech_pace_card.dart';
import '../settings/voice_card.dart';

/// How the dubbing sounds: how far the game is turned down under it, how
/// fast it is read, and in which voice.
///
/// These stood among the settings, a screen away from the button that
/// starts the dubbing -- and the voice, at least, is something the player
/// changes while listening to it.
class DubbingCards extends StatelessWidget {
  const DubbingCards({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<SettingsCubit, SettingsState>(
    builder: (context, state) => BlocSelector<PipelineCubit, LivePipelineState, bool>(
      selector: (pipeline) => pipeline.running,
      builder: (context, running) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Two sliders with a switch under each: side by side they are
          // read at a glance, and one under the other only where the
          // window is too narrow to set either without squeezing its notes.
          PairedCards(
            first: OriginalVolumeCard(settings: state.settings, running: running),
            second: SpeechPaceCard(settings: state.settings, running: running),
          ),
          const SizedBox(height: SettingsLayout.cardGap),
          const VoiceCard(),
        ],
      ),
    ),
  );
}

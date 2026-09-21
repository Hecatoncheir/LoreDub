// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../common/setting_card.dart';
import '../dashboard/cubits/downloads_bloc.dart';
import '../dashboard/cubits/session_bloc.dart';
import '../dashboard/cubits/settings_bloc.dart';
import '../dashboard/dashboard_context.dart';
import 'voice_card_body.dart';

/// Which voice reads the dubbing, and whether it follows the original.
///
/// The automatic half only makes sense when the language's package ships
/// both a man's and a woman's voice and there is audio to hear, so when it
/// does not, the option is disabled and the reason is written out rather
/// than left for the user to guess at. Which voices exist comes from the
/// downloaded package, so the card listens to what is on disk as well.
class VoiceCard extends StatelessWidget {
  const VoiceCard({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<SettingsBloc, SettingsState>(
    builder: (context, state) => BlocBuilder<DownloadsBloc, DownloadsState>(
      buildWhen: whenChanged((downloads) => downloads.installed),
      builder: (context, _) => BlocBuilder<SessionBloc, SessionState>(
        buildWhen: whenChanged((pipeline) => (pipeline.running, pipeline.spokenVoice)),
        builder: (context, pipeline) {
          final l10n = AppLocalizations.of(context);
          return SettingCard(
            title: l10n.settingsVoice,
            subtitle: l10n.voiceNote,
            child: VoiceCardBody(
              selection: context.selection,
              voiceBankSize: state.voiceBankSize,
              running: pipeline.running,
              spokenVoice: pipeline.spokenVoice,
            ),
          );
        },
      ),
    ),
  );
}

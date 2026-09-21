// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/app_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../dashboard/cubits/session_bloc.dart';
import '../dashboard/cubits/settings_bloc.dart';
import '../dashboard/dashboard_context.dart';
import 'language_controls.dart';
import 'target_language_picker.dart';
import '../common/game_picker.dart';
import '../dashboard/cubits/voice_capture_bloc.dart';

/// The card that picks the game and the source of its sound, with the
/// dubbing language and the start button beside them.
class SourceControls extends StatelessWidget {
  const SourceControls({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => BlocBuilder<SettingsBloc, SettingsState>(
    builder: (context, state) => BlocBuilder<SessionBloc, SessionState>(
      buildWhen: whenChanged(
        (pipeline) => pipeline.running,
      ),
      // Only whether a card is being recorded: the seconds it has heard tick
      // as it goes, and this screen must not be redrawn for them.
      builder: (context, pipeline) => BlocSelector<VoiceCaptureBloc, VoiceCaptureState, bool>(
        selector: (capture) => capture.running,
        builder: (context, recording) =>
            _build(context, state.settings, pipeline, recording: recording),
      ),
    ),
  );

  Widget _build(
    BuildContext context,
    AppSettings settings,
    SessionState pipeline, {
    required bool recording,
  }) {
    final l10n = AppLocalizations.of(context);
    final running = pipeline.running;
    final requiresProcess = settings.audioCaptureSource == AudioCaptureSource.process;
    // A card recording on the characters screen listens to the game it
    // started with; the choice is shared, so it is held there.
    final selector = GamePicker(enabled: !running && requiresProcess && !recording);
    final helper = Text(
      requiresProcess ? l10n.captureProcessNote : l10n.captureSystemNote,
      style: Theme.of(context).textTheme.bodySmall,
    );
    final sourceSwitch = SegmentedButton<AudioCaptureSource>(
      segments: [
        ButtonSegment(
          value: AudioCaptureSource.system,
          icon: const Icon(Icons.speaker_group_outlined),
          label: Text(l10n.sourceSystem),
        ),
        ButtonSegment(
          value: AudioCaptureSource.process,
          icon: const Icon(Icons.sports_esports_outlined),
          label: Text(l10n.sourceProcess),
        ),
      ],
      selected: {settings.audioCaptureSource},
      onSelectionChanged: running
          ? null
          : (selection) => context.read<SettingsBloc>().add(
              SettingsChanged(
                settings.copyWith(audioCaptureSource: selection.first),
              ),
            ),
    );
    // The picker carries its own refresh button, so it travels whole into
    // the compact layout instead of leaving it on the row with the start
    // button.
    final picker = selector;
    final language = LanguageControls();
    final target = TargetLanguagePicker();
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sourceSwitch,
          const SizedBox(height: 12),
          picker,
          const SizedBox(height: 8),
          helper,
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: language),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerRight, child: target),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            sourceSwitch,
            const SizedBox(width: 16),
            Expanded(child: picker),
            const SizedBox(width: 16),
            language,
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(padding: const EdgeInsets.only(top: 12), child: helper),
            ),
            const SizedBox(width: 16),
            target,
          ],
        ),
      ],
    );
  }
}

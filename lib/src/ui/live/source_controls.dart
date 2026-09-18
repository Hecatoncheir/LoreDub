// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/app_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../dashboard/cubits/characters_cubit.dart';
import '../dashboard/cubits/pipeline_cubit.dart';
import '../dashboard/cubits/settings_cubit.dart';
import '../dashboard/dashboard_context.dart';
import '../common/process_picker.dart';
import 'language_controls.dart';
import 'target_language_picker.dart';

/// The card that picks the game and the source of its sound, with the
/// dubbing language and the start button beside them.
class SourceControls extends StatelessWidget {
  const SourceControls({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => BlocBuilder<SettingsCubit, SettingsState>(
    builder: (context, state) => BlocBuilder<PipelineCubit, LivePipelineState>(
      buildWhen: whenChanged(
        (pipeline) => (pipeline.running, pipeline.processes, pipeline.selectedProcess),
      ),
      // Only whether a card is being recorded: the seconds it has heard tick
      // as it goes, and this screen must not be redrawn for them.
      builder: (context, pipeline) => BlocBuilder<CharactersCubit, CharactersState>(
        buildWhen: whenChanged((characters) => characters.running),
        builder: (context, characters) =>
            _build(context, state.settings, pipeline, recording: characters.running),
      ),
    ),
  );

  Widget _build(
    BuildContext context,
    AppSettings settings,
    LivePipelineState pipeline, {
    required bool recording,
  }) {
    final l10n = AppLocalizations.of(context);
    final running = pipeline.running;
    final requiresProcess = settings.audioCaptureSource == AudioCaptureSource.process;
    final selector = ProcessPicker(
      processes: pipeline.processes,
      selected: pipeline.selectedProcess,
      // A card recording on the characters screen listens to the game it
      // started with; the choice is shared, so it is held there.
      enabled: !running && requiresProcess && !recording,
      onSelected: context.read<PipelineCubit>().selectProcess,
      onRefresh: context.read<PipelineCubit>().refreshProcesses,
    );
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
          : (selection) => context.read<SettingsCubit>().update(
              settings.copyWith(audioCaptureSource: selection.first),
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

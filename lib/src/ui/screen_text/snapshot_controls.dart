// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/app_settings.dart';
import '../dashboard/cubits/pipeline_cubit.dart';
import '../common/language_row.dart';
import '../dashboard/cubits/settings_cubit.dart';
import '../dashboard/dashboard_context.dart';
import 'screen_layout.dart';
import 'snapshot_details.dart';
import 'snapshot_start_button.dart';
import '../common/game_picker.dart';

/// How to select, what the last selection came to, and the session's button.
class SnapshotControls extends StatelessWidget {
  const SnapshotControls({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<SettingsCubit, SettingsState>(
    builder: (context, state) => BlocBuilder<PipelineCubit, LivePipelineState>(
      buildWhen: whenChanged(
        (pipeline) => (
          pipeline.status,
          pipeline.session,
          pipeline.snapshotReading,
          pipeline.snapshotMissed,
          pipeline.frameMissed,
        ),
      ),
      builder: (context, pipeline) => _build(context, state.settings, pipeline),
    ),
  );

  Widget _build(BuildContext context, AppSettings settings, LivePipelineState pipeline) {
    final button = SnapshotStartButton();
    // The frame is read out of one window, so this session needs the game
    // named even though nothing of its sound is listened to.
    // Nothing is read out of that window while the whole screen is what
    // is read, so there is nothing to choose.
    final picker = GamePicker(enabled: !pipeline.running && !settings.readsWholeScreen);
    return LayoutBuilder(
      // Where there is room the button stands on the row that names the
      // game, which is what it starts on. Beside the card as a whole it hung
      // at the middle of a paragraph, level with nothing and moving with
      // every line the text below it wrapped to. Narrower than this the
      // picker would be squeezed to a stub, so the button goes under it.
      builder: (context, constraints) => constraints.maxWidth < ScreenLayout.startBesidePickerWidth
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SnapshotDetails(settings: settings, pipeline: pipeline, game: picker),
                const SizedBox(height: 14),
                button,
              ],
            )
          : SnapshotDetails(
              settings: settings,
              pipeline: pipeline,
              game: Row(
                children: [
                  Expanded(child: picker),
                  const SizedBox(width: 24),
                  SizedBox(width: LanguageRow.actionWidth, child: button),
                ],
              ),
            ),
    );
  }
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../dashboard/cubits/pipeline_cubit.dart';
import '../language_names.dart';
import 'screen_source_picker.dart';
import 'silence_while_reading_switch.dart';
import 'snapshot_status_line.dart';
import 'text_language_picker.dart';

/// The column of the screen's controls, with [game] -- the picker, and the
/// start button beside it where there is room -- standing in it.
class SnapshotDetails extends StatelessWidget {
  const SnapshotDetails({
    super.key,
    required this.settings,
    required this.pipeline,
    required this.game,
  });

  final AppSettings settings;
  final LivePipelineState pipeline;
  final Widget game;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final voice = spokenLanguageName(l10n, settings.targetLanguage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenSourcePicker(settings: settings, locked: pipeline.running),
        const SizedBox(height: 14),
        game,
        const SizedBox(height: 14),
        TextLanguagePicker(),
        const SizedBox(height: 10),
        Text(
          settings.readsWholeScreen ? l10n.screenWholeNote(voice) : l10n.snapshotNote(voice),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        // Silencing the game belongs to the session rather than to the
        // frame: nothing here listens to the game, so it may go quiet
        // whichever way the screen is read.
        SilenceWhileReadingSwitch(settings: settings, locked: pipeline.running),
        SnapshotStatusLine(pipeline: pipeline, settings: settings),
      ],
    );
  }
}

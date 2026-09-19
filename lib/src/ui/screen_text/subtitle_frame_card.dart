// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/app_settings.dart';
import '../../domain/ocr_region.dart';
import '../../../l10n/app_localizations.dart';
import '../theme.dart';
import '../dashboard/cubits/pipeline_cubit.dart';
import '../dashboard/cubits/settings_cubit.dart';
import '../dashboard/dashboard_context.dart';
import '../../domain/screen_reading.dart';
import '../common/module_label.dart';
import 'ocr_region_picker.dart';
import 'snapshot_start_button.dart';

/// The frame the subtitles are read out of, drawn on a picture of the game's
/// window, and whether the game is silenced while they are dubbed.
///
/// It lives here rather than in the settings because this is the only
/// session that reads it: the frame is part of the work this screen does.
class SubtitleFrameCard extends StatelessWidget {
  const SubtitleFrameCard({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<SettingsCubit, SettingsState>(
    builder: (context, state) => BlocBuilder<PipelineCubit, LivePipelineState>(
      buildWhen: whenChanged((pipeline) => pipeline.running),
      builder: (context, pipeline) => _build(context, state.settings, running: pipeline.running),
    ),
  );

  Widget _build(BuildContext context, AppSettings settings, {required bool running}) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModuleLabel(number: '04', label: l10n.areaSubtitleFrame),
            const SizedBox(height: 14),
            OcrRegionPicker(
              key: const ValueKey('ocrRegion'),
              region: settings.ocrRegion,
              semanticLabel: l10n.ocrRegionHelp,
              onChanged: running
                  ? null
                  : (region) =>
                        context.read<SettingsCubit>().update(settings.copyWith(ocrRegion: region)),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  (settings.readsWholeScreen ? l10n.ocrRegionOfScreen : l10n.ocrRegionValue)(
                    (settings.ocrRegion.width * 100).round(),
                    (settings.ocrRegion.height * 100).round(),
                    (settings.ocrRegion.left * 100).round(),
                    (settings.ocrRegion.top * 100).round(),
                  ),
                  style: const TextStyle(fontFamily: LoreDubFonts.mono, fontSize: 12),
                ),
                TextButton.icon(
                  onPressed: running || settings.ocrRegion == OcrRegion.standard
                      ? null
                      : () => context.read<SettingsCubit>().update(
                          settings.copyWith(ocrRegion: OcrRegion.standard),
                        ),
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: Text(l10n.ocrRegionReset),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Drawn here before the game starts, or over the game itself
            // once it has: the same frame either way.
            if (settings.frameHotkey case final key?) ...[
              Text(l10n.frameHowTo(key.display), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
            ],
            Text(l10n.screenHowTo, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 14),
            SnapshotStartButton(reading: ScreenReading.subtitles),
          ],
        ),
      ),
    );
  }
}

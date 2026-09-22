// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/app_settings.dart';
import '../../domain/ocr_region.dart';
import '../../domain/monitor_layout.dart';
import '../../../l10n/app_localizations.dart';
import '../theme.dart';
import '../common/bloc/session_bloc.dart';
import '../settings/bloc/settings_bloc.dart';
import '../common/dashboard_context.dart';
import '../common/keyed_text.dart';
import '../../domain/screen_reading.dart';
import '../common/module_label.dart';
import 'ocr_region_picker.dart';
import 'screen_voices_switch.dart';
import 'snapshot_start_button.dart';
import '../../domain/capture_sources.dart';
import '../common/bloc/sources_bloc.dart';

/// The frame the subtitles are read out of, drawn on a picture of the game's
/// window, and whether the game is silenced while they are dubbed.
///
/// It lives here rather than in the settings because this is the only
/// session that reads it: the frame is part of the work this screen does.
class SubtitleFrameCard extends StatelessWidget {
  const SubtitleFrameCard({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<SettingsBloc, SettingsState>(
    builder: (context, state) => BlocBuilder<SessionBloc, SessionState>(
      buildWhen: whenChanged((pipeline) => pipeline.running),
      builder: (context, pipeline) => BlocSelector<SourcesBloc, CaptureSources, MonitorLayout?>(
        selector: (sources) => sources.monitors,
        builder: (context, monitors) =>
            _build(context, state.settings, running: pipeline.running, monitors: monitors),
      ),
    ),
  );

  Widget _build(
    BuildContext context,
    AppSettings settings, {
    required bool running,
    required MonitorLayout? monitors,
  }) {
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
              // A window's frame is a share of that window; the screen's is
              // a share of every monitor together, and drawn that way.
              monitors: settings.readsWholeScreen ? monitors : null,
              onChanged: running
                  ? null
                  : (region) => context.read<SettingsBloc>().add(
                      SettingsChanged(settings.copyWith(ocrRegion: region)),
                    ),
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
                      : () => context.read<SettingsBloc>().add(
                          SettingsChanged(
                            settings.copyWith(ocrRegion: OcrRegion.standard),
                          ),
                        ),
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: Text(l10n.ocrRegionReset),
                ),
              ],
            ),
            // Where it is read from, shown over the game itself rather
            // than on a picture of it: aiming the frame is most of what it
            // is for, so it is drawn whether a session runs or not.
            Row(
              children: [
                Switch(
                  key: const ValueKey('showFrameOverlay'),
                  value: settings.showFrameOverlay,
                  onChanged: (value) => context.read<SettingsBloc>().add(
                    SettingsChanged(
                      settings.copyWith(showFrameOverlay: value),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(child: Text(l10n.showFrameOverlay)),
              ],
            ),
            const SizedBox(height: 6),
            // Drawn here before the game starts, or over the game itself
            // once it has: the same frame either way.
            if (settings.frameHotkey case final key?) ...[
              KeyedText(
                l10n.frameHowTo(key.display),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
            ],
            Text(l10n.screenHowTo, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 12),
            ScreenVoicesSwitch(settings: settings, locked: running),
            const SizedBox(height: 14),
            SnapshotStartButton(reading: ScreenReading.subtitles),
          ],
        ),
      ),
    );
  }
}

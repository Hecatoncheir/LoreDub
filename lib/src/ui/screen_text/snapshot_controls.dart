// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/app_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../language_names.dart';
import '../theme.dart';
import '../dashboard/cubits/pipeline_cubit.dart';
import '../dashboard/cubits/settings_cubit.dart';
import '../dashboard/cubits/shell_cubit.dart';
import '../dashboard/dashboard_context.dart';
import '../dashboard/process_picker.dart';
import '../common/language_row.dart';
import 'snapshot_start_button.dart';
import 'text_language_picker.dart';
import 'screen_layout.dart';

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
          pipeline.selectedProcess,
          pipeline.processes,
        ),
      ),
      builder: (context, pipeline) => _build(context, state.settings, pipeline),
    ),
  );

  Widget _build(BuildContext context, AppSettings settings, LivePipelineState pipeline) {
    final l10n = AppLocalizations.of(context);
    final hotkey = settings.snapshotHotkey;
    final status = _status(l10n, pipeline, settings);
    final button = SnapshotStartButton();
    // The frame is read out of one window, so this session needs the game
    // named even though nothing of its sound is listened to.
    final picker = ProcessPicker(
      processes: pipeline.processes,
      selected: pipeline.selectedProcess,
      // Nothing is read out of that window while the whole screen is what
      // is read, so there is nothing to choose.
      enabled: !pipeline.running && !settings.readsWholeScreen,
      onSelected: context.read<PipelineCubit>().selectProcess,
      onRefresh: context.read<PipelineCubit>().refreshProcesses,
    );
    Widget details({required Widget game}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hotkey == null)
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.snapshotNoHotkey,
                style: const TextStyle(
                  color: LoreDubPalette.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () =>
                    context.read<ShellCubit>().selectSection(DashboardSection.settings),
                child: Text(l10n.snapshotOpenSettings),
              ),
            ],
          )
        else
          Text(
            l10n.snapshotHowTo(hotkey.display),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        const SizedBox(height: 8),
        Text(l10n.screenHowTo, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 14),
        // A window is read only while it is in front, so nothing put over
        // the game can pass for its subtitles; the screen is read whatever
        // is on it, which is the only way into a game that keeps no
        // ordinary window.
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ScreenSource>(
            segments: [
              ButtonSegment(
                value: ScreenSource.gameWindow,
                icon: const Icon(Icons.crop_din_rounded),
                label: Text(l10n.screenSourceWindow),
              ),
              ButtonSegment(
                value: ScreenSource.wholeScreen,
                icon: const Icon(Icons.desktop_windows_outlined),
                label: Text(l10n.screenSourceScreen),
              ),
            ],
            selected: {settings.screenSource},
            onSelectionChanged: pipeline.running
                ? null
                : (selection) => context.read<SettingsCubit>().update(
                    settings.copyWith(screenSource: selection.first),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        game,
        const SizedBox(height: 14),
        TextLanguagePicker(),
        const SizedBox(height: 10),
        Text(
          settings.readsWholeScreen
              ? l10n.screenWholeNote(spokenLanguageName(l10n, settings.targetLanguage))
              : l10n.snapshotNote(spokenLanguageName(l10n, settings.targetLanguage)),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (status != null) ...[const SizedBox(height: 12), status],
      ],
    );
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
                details(game: picker),
                const SizedBox(height: 14),
                button,
              ],
            )
          : details(
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

  /// What became of the last selection, or that live dubbing holds the key.
  Widget? _status(AppLocalizations l10n, LivePipelineState pipeline, AppSettings settings) {
    final (icon, text, color) = switch (pipeline) {
      _ when pipeline.snapshotReading => (
        Icons.hourglass_top_rounded,
        l10n.snapshotReading,
        LoreDubPalette.warning,
      ),
      _ when pipeline.snapshotMissed => (
        Icons.search_off_rounded,
        l10n.snapshotMissed,
        LoreDubPalette.warning,
      ),
      _ when pipeline.liveRunning => (
        Icons.info_outline_rounded,
        l10n.snapshotInLive,
        LoreDubPalette.mutedInk,
      ),
      _ when pipeline.frameMissed => (
        Icons.crop_free_rounded,
        l10n.frameMissed,
        LoreDubPalette.warning,
      ),
      // Reading the whole screen waits for no window, so there is no game
      // to ask for -- the picker beside this line is shut for the same
      // reason.
      _ when pipeline.selectedProcess == null && !settings.readsWholeScreen => (
        Icons.videogame_asset_off_rounded,
        l10n.screenPickGame,
        LoreDubPalette.warning,
      ),
      _ => (null, '', LoreDubPalette.mutedInk),
    };
    if (icon == null) return null;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/services/model_catalog.dart';
import '../../domain/app_release.dart';
import '../../domain/app_settings.dart';
import '../../domain/compute_device.dart';
import '../../domain/game_process.dart';
import '../../domain/model_package.dart';
import '../../domain/model_proxy.dart';
import '../../domain/model_selection.dart';
import '../../domain/ocr_region.dart';
import '../../domain/runtime_paths.dart';
import '../../domain/pipeline_state.dart';
import '../../domain/spoken_language.dart';
import '../../../l10n/app_localizations.dart';
import '../app_icons.dart';
import '../compute_names.dart';
import '../failure_messages.dart';
import '../language_names.dart';
import '../model_names.dart';
import '../theme.dart';
import 'cubits/dashboard_cubits.dart';
import 'cubits/downloads_cubit.dart';
import 'cubits/pipeline_cubit.dart';
import 'cubits/settings_cubit.dart';
import 'cubits/shell_cubit.dart';
import 'compute_matrix.dart';
import 'hotkey_field.dart';
import 'model_tiles.dart';
import 'model_visuals.dart';
import 'ocr_region_picker.dart';
import 'whisper_model_chart.dart';

/// Rebuilds only when the shell changes, which is the section, the banner
/// and the version. Every other part of the screen listens for itself.
class _ShellBuilder extends StatelessWidget {
  const _ShellBuilder({required this.cubits, required this.builder});

  final DashboardCubits cubits;
  final Widget Function(BuildContext context, ShellState shell) builder;

  @override
  Widget build(BuildContext context) => BlocBuilder<ShellCubit, ShellState>(
    bloc: cubits.shell,
    builder: builder,
  );
}

/// Rebuilds with the running session: its state, what it heard, and the
/// process list.
class _PipelineBuilder extends StatelessWidget {
  const _PipelineBuilder({required this.cubits, required this.builder, this.watch});

  final DashboardCubits cubits;
  final Widget Function(BuildContext context, LivePipelineState pipeline) builder;

  /// The part of the session this widget draws, as a value that can be
  /// compared. Everything outside the transcript reads only a field or two,
  /// and a recognized phrase must not redraw the settings screen.
  final Object? Function(LivePipelineState pipeline)? watch;

  @override
  Widget build(BuildContext context) => BlocBuilder<PipelineCubit, LivePipelineState>(
    bloc: cubits.pipeline,
    buildWhen: watch == null ? null : (previous, current) => watch!(previous) != watch!(current),
    builder: builder,
  );
}

/// Rebuilds when the configuration changes.
class _SettingsBuilder extends StatelessWidget {
  const _SettingsBuilder({required this.cubits, required this.builder});

  final DashboardCubits cubits;
  final Widget Function(BuildContext context, SettingsState settings) builder;

  @override
  Widget build(BuildContext context) => BlocBuilder<SettingsCubit, SettingsState>(
    bloc: cubits.settings,
    builder: builder,
  );
}

/// Rebuilds as packages arrive. Kept off the live screen on purpose: a
/// download ticking must not redraw the transcript.
class _DownloadsBuilder extends StatelessWidget {
  const _DownloadsBuilder({
    required this.cubits,
    required this.builder,
    this.onlyWhatIsInstalled = false,
  });

  final DashboardCubits cubits;
  final Widget Function(BuildContext context, DownloadsState downloads) builder;

  /// Set by the parts that care whether a package is there, not how far its
  /// download has got: it holds them still through the hundred ticks of one.
  final bool onlyWhatIsInstalled;

  @override
  Widget build(BuildContext context) => BlocBuilder<DownloadsCubit, DownloadsState>(
    bloc: cubits.downloads,
    buildWhen: onlyWhatIsInstalled
        ? (previous, current) => !setEquals(previous.installedModelIds, current.installedModelIds)
        : null,
    builder: builder,
  );
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key, required this.cubits});

  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final content = SafeArea(
          child: Column(
            children: [
              _Header(cubits: cubits),
              _ShellBuilder(
                cubits: cubits,
                builder: (context, shell) => switch (shell.error) {
                  final error? => _ErrorBanner(
                    message: describeFailure(AppLocalizations.of(context), error),
                  ),
                  _ => const SizedBox.shrink(),
                },
              ),
              Expanded(
                child: _ShellBuilder(
                  cubits: cubits,
                  builder: (context, shell) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: switch (shell.section) {
                      DashboardSection.live => _LivePanel(
                        key: const ValueKey('live'),
                        cubits: cubits,
                      ),
                      DashboardSection.snapshot => _SnapshotPanel(
                        key: const ValueKey('snapshot'),
                        cubits: cubits,
                      ),
                      DashboardSection.models => _ModelsPanel(
                        key: const ValueKey('models'),
                        cubits: cubits,
                      ),
                      DashboardSection.settings => _SettingsPanel(
                        key: const ValueKey('settings'),
                        cubits: cubits,
                      ),
                    },
                  ),
                ),
              ),
            ],
          ),
        );
        if (compact) {
          return Column(
            children: [
              Expanded(child: content),
              _BottomNavigation(cubits: cubits),
            ],
          );
        }
        return Row(
          children: [
            _Navigation(cubits: cubits),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        );
      },
    ),
  );
}

class _Navigation extends StatelessWidget {
  const _Navigation({required this.cubits});

  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) => Container(
    width: 236,
    color: LoreDubPalette.panel,
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 26),
          child: Row(
            children: [
              Image.asset(
                'assets/branding/loredub-icon.png',
                width: 48,
                height: 48,
                semanticLabel: 'LoreDub',
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LoreDub',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'VOICE UNIT 01',
                      style: TextStyle(
                        fontFamily: LoreDubFonts.mono,
                        color: LoreDubPalette.mutedInk,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _ShellBuilder(
          cubits: cubits,
          builder: (context, shell) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NavigationItem(
                icon: (color) => LoreDubIcons.audioCapture(color: color, size: 21),
                label: AppLocalizations.of(context).navLive,
                selected: shell.section == DashboardSection.live,
                onTap: () => cubits.shell.selectSection(DashboardSection.live),
              ),
              _NavigationItem(
                icon: (color) => Icon(Icons.highlight_alt_rounded, size: 21, color: color),
                label: AppLocalizations.of(context).navSnapshot,
                selected: shell.section == DashboardSection.snapshot,
                onTap: () => cubits.shell.selectSection(DashboardSection.snapshot),
              ),
              _NavigationItem(
                icon: (color) => Icon(Icons.memory_rounded, size: 21, color: color),
                label: AppLocalizations.of(context).navModels,
                selected: shell.section == DashboardSection.models,
                onTap: () => cubits.shell.selectSection(DashboardSection.models),
              ),
              _NavigationItem(
                icon: (color) => Icon(Icons.tune_rounded, size: 21, color: color),
                label: AppLocalizations.of(context).navSettings,
                selected: shell.section == DashboardSection.settings,
                onTap: () => cubits.shell.selectSection(DashboardSection.settings),
              ),
            ],
          ),
        ),
        const Spacer(),
        _VersionButton(cubits: cubits),
        const Padding(
          // Starts where the version's icon does, so the foot of the panel
          // reads down one left edge.
          padding: EdgeInsets.fromLTRB(_footerInset, 0, 12, 12),
          child: Text(
            'WINDOWS · LOCAL PROCESSING',
            maxLines: 1,
            // The monospaced face is wider than the label had room for.
            style: TextStyle(
              fontFamily: LoreDubFonts.mono,
              color: LoreDubPalette.mutedInk,
              fontSize: 9,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Where the foot of the sidebar begins: the version's icon and the status
/// line below it both start here. The button's own padding makes up the
/// difference, so the two stay in step if either is adjusted.
const _footerInset = _footerOuterInset + _footerButtonInset;
const _footerOuterInset = 8.0;
const _footerButtonInset = 4.0;
const _footerIconSize = 14.0;

/// The version, and what is known about newer ones.
///
/// Tapping it checks again; while a check runs the spinner takes the place of
/// nothing else, so the row does not resize. Once a newer version is
/// published the version steps aside for [_UpdateRow].
class _VersionButton extends StatelessWidget {
  const _VersionButton({required this.cubits});

  final DashboardCubits cubits;

  String _tooltip(AppLocalizations l10n, UpdateState updates) => switch (updates.status) {
    UpdateStatus.checking => l10n.updateChecking,
    UpdateStatus.current => l10n.updateUpToDate,
    UpdateStatus.failed => l10n.updateFailed,
    _ => l10n.updateCheckAgain,
  };

  @override
  Widget build(BuildContext context) => _ShellBuilder(
    cubits: cubits,
    builder: (context, shell) => _build(context, shell.updates),
  );

  Widget _build(BuildContext context, UpdateState updates) {
    final l10n = AppLocalizations.of(context);
    final version = updates.currentVersion;
    if (updates.hasUpdate) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(_footerOuterInset, 0, 8, 8),
        child: _UpdateRow(cubits: cubits, updates: updates),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(_footerOuterInset, 0, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: _tooltip(l10n, updates),
              child: TextButton(
                onPressed: updates.checking ? null : () => cubits.shell.checkForUpdates(),
                style: TextButton.styleFrom(
                  foregroundColor: LoreDubPalette.mutedInk,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: _footerButtonInset),
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontFamily: LoreDubFonts.mono,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: _footerIconSize,
                      height: _footerIconSize,
                      child: updates.checking
                          ? const CircularProgressIndicator(strokeWidth: 2)
                          : Icon(
                              updates.status == UpdateStatus.failed
                                  ? Icons.cloud_off_rounded
                                  : Icons.verified_outlined,
                              size: _footerIconSize,
                              color: LoreDubPalette.mutedInk,
                            ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        version.isEmpty ? '—' : l10n.updateCurrent(version),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A newer version, in three steps on the spot the version held: where the
/// update goes ("v0.8.0 → v0.9.0"), a bar while its setup downloads, and
/// "Updated" with the restart that runs the setup.
///
/// A running application cannot overwrite its own files, so the setup itself
/// runs in the few seconds between closing and opening again; the bar is the
/// download, which is nearly all of the wait.
class _UpdateRow extends StatelessWidget {
  const _UpdateRow({required this.cubits, required this.updates});

  final DashboardCubits cubits;
  final UpdateState updates;

  static const _label = TextStyle(
    fontFamily: LoreDubFonts.mono,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final release = updates.release!;
    if (updates.readyToRestart) {
      return Row(
        children: [
          const SizedBox(width: _footerButtonInset),
          // The word never breaks: beside the restart the sidebar is narrow,
          // so it shrinks a little rather than wrapping mid-word.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.updateInstalled,
                maxLines: 1,
                style: _label.copyWith(color: LoreDubPalette.ink),
              ),
            ),
          ),
          Tooltip(
            message: l10n.updateRestartHint,
            child: TextButton.icon(
              key: const ValueKey('updateRestart'),
              onPressed: cubits.shell.restartToUpdate,
              icon: LoreDubIcons.directorySync(color: LoreDubPalette.orange, size: 16),
              label: Text(l10n.updateRestart),
              style: TextButton.styleFrom(
                foregroundColor: LoreDubPalette.orangeDark,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: _label.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      );
    }
    if (updates.installProgress case final progress?) {
      return Tooltip(
        message: l10n.updateDownloading,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _footerButtonInset, vertical: 11),
          child: Row(
            children: [
              Expanded(child: LinearProgressIndicator(value: progress, minHeight: 6)),
              const SizedBox(width: 8),
              Text('${(progress * 100).round()}%', style: _label),
            ],
          ),
        ),
      );
    }
    return Tooltip(
      // A build run from its folder cannot be replaced by the setup, so it
      // is sent to the page instead, and says so.
      message: updates.installable
          ? l10n.updateInstallHint
          : l10n.updateOpenRelease(release.version),
      child: TextButton(
        key: const ValueKey('updateAvailable'),
        onPressed: cubits.shell.installUpdate,
        style: TextButton.styleFrom(
          foregroundColor: LoreDubPalette.ink,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: _footerButtonInset, vertical: 6),
          minimumSize: const Size(0, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: _label,
        ),
        child: Row(
          children: [
            Flexible(
              child: Text(
                l10n.updateFromTo(updates.currentVersion, release.version),
                maxLines: 2,
              ),
            ),
            const SizedBox(width: 6),
            LoreDubIcons.deployedCodeUpdate(color: LoreDubPalette.orange, size: 18),
          ],
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// Built rather than passed ready-made: the colour depends on [selected],
  /// and not every mark here comes from the icon font.
  final Widget Function(Color color) icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Material(
        color: selected ? LoreDubPalette.graphite : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                const SizedBox(width: 12),
                icon(selected ? LoreDubPalette.orange : LoreDubPalette.ink),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : LoreDubPalette.ink,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({required this.cubits});

  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) => _ShellBuilder(
    cubits: cubits,
    builder: (context, shell) => _build(context, shell.section),
  );

  Widget _build(BuildContext context, DashboardSection section) {
    final scheme = Theme.of(context).colorScheme;
    return NavigationBar(
      height: 68,
      backgroundColor: LoreDubPalette.panel,
      indicatorColor: LoreDubPalette.orange,
      selectedIndex: section.index,
      onDestinationSelected: (index) => cubits.shell.selectSection(DashboardSection.values[index]),
      destinations: [
        NavigationDestination(
          // The bar tints its font icons itself, which leaves the drawing
          // untouched, so it is handed the same two colours by hand.
          icon: LoreDubIcons.audioCapture(color: scheme.onSurfaceVariant),
          selectedIcon: LoreDubIcons.audioCapture(color: scheme.onSecondaryContainer),
          label: AppLocalizations.of(context).navLive,
        ),
        NavigationDestination(
          icon: const Icon(Icons.highlight_alt_rounded),
          label: AppLocalizations.of(context).navSnapshot,
        ),
        NavigationDestination(
          icon: const Icon(Icons.memory_rounded),
          label: AppLocalizations.of(context).navModels,
        ),
        NavigationDestination(
          icon: const Icon(Icons.tune_rounded),
          label: AppLocalizations.of(context).navSettings,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.cubits});

  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 22, 28, 12),
    child: Row(
      children: [
        Expanded(
          child: _ShellBuilder(
            cubits: cubits,
            builder: (context, shell) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  switch (shell.section) {
                    DashboardSection.live => '01  /  LIVE VOICE',
                    DashboardSection.snapshot => '02  /  AREA SNAPSHOT',
                    DashboardSection.models => '03  /  MODEL BANK',
                    DashboardSection.settings => '04  /  SIGNAL SETUP',
                  },
                  style: const TextStyle(
                    fontFamily: LoreDubFonts.mono,
                    color: LoreDubPalette.mutedInk,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  switch (shell.section) {
                    DashboardSection.live => AppLocalizations.of(context).titleLive,
                    DashboardSection.snapshot => AppLocalizations.of(context).titleSnapshot,
                    DashboardSection.models => AppLocalizations.of(context).titleModels,
                    DashboardSection.settings => AppLocalizations.of(context).titleSettings,
                  },
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        ),
        _PipelineBuilder(
          cubits: cubits,
          watch: (pipeline) => (pipeline.status, pipeline.startupStage, pipeline.session),
          builder: (context, pipeline) => _StatusChip(
            status: pipeline.status,
            stage: pipeline.startupStage,
            snapshot: pipeline.session == PipelineSession.snapshot,
          ),
        ),
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, this.stage = '', this.snapshot = false});

  final PipelineStatus status;

  /// What the startup is doing right now, shown instead of a bare "Запуск…".
  final String stage;

  /// The snapshot session listens for nothing: it waits for a selection.
  final bool snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, color) = switch (status) {
      PipelineStatus.idle => (l10n.statusIdle, LoreDubPalette.mutedInk),
      PipelineStatus.starting => (
        stage.isEmpty ? l10n.statusStarting : describeStartupStage(l10n, stage),
        LoreDubPalette.warning,
      ),
      PipelineStatus.listening => (
        snapshot ? l10n.statusSnapshotReady : l10n.statusListening,
        LoreDubPalette.success,
      ),
      PipelineStatus.paused => (l10n.statusPaused, LoreDubPalette.warning),
      PipelineStatus.stopping => (l10n.statusStopping, LoreDubPalette.warning),
      PipelineStatus.error => (l10n.statusError, LoreDubPalette.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _LivePanel extends StatelessWidget {
  const _LivePanel({super.key, required this.cubits});

  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
    child: Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ModuleLabel(number: '01', label: 'GAME INPUT'),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) => _SourceControls(
                    cubits: cubits,
                    compact: constraints.maxWidth < _wideSourceRowWidth,
                  ),
                ),
              ],
            ),
          ),
        ),
        _ModelsNeededNotice(
          cubits: cubits,
          ready: (selection) => selection.requiredModelsInstalled,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _PipelineBuilder(
            cubits: cubits,
            watch: (pipeline) => pipeline.transcript,
            builder: (context, pipeline) => Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Padding(
                    // Tighter than a bare label row would need: the button has
                    // to fit without making the header taller than it was.
                    padding: const EdgeInsets.fromLTRB(20, 9, 12, 8),
                    child: Row(
                      children: [
                        const _ModuleLabel(number: '02', label: 'LIVE TRANSCRIPT'),
                        const Spacer(),
                        _ClearListButton(
                          tooltip: AppLocalizations.of(context).transcriptClearTooltip,
                          onPressed: pipeline.transcript.isEmpty
                              ? null
                              : cubits.pipeline.clearTranscript,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: pipeline.transcript.isEmpty
                        ? _SettingsBuilder(
                            cubits: cubits,
                            builder: (context, settings) => _EmptyTranscript(
                              targetLanguage: settings.settings.targetLanguage,
                              captureMode: settings.settings.captureMode,
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                            itemCount: pipeline.transcript.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 14),
                            itemBuilder: (context, index) =>
                                _TranscriptBubble(entry: pipeline.transcript[index]),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Says the packages a screen needs are missing, and leads to them. What
/// counts as missing is the screen's own question: the snapshot session
/// does without whisper.
class _ModelsNeededNotice extends StatelessWidget {
  const _ModelsNeededNotice({required this.cubits, required this.ready});

  final DashboardCubits cubits;
  final bool Function(ModelSelection selection) ready;

  // What is missing is decided by the packages and the chosen language
  // together, so this notice watches both.
  @override
  Widget build(BuildContext context) => _DownloadsBuilder(
    onlyWhatIsInstalled: true,
    cubits: cubits,
    builder: (context, _) => _SettingsBuilder(
      cubits: cubits,
      builder: (context, _) => ready(cubits.selection)
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.download_rounded, color: LoreDubPalette.warning),
                  title: Text(AppLocalizations.of(context).modelsNeededTitle),
                  subtitle: Text(AppLocalizations.of(context).modelsNeededNote),
                  trailing: TextButton(
                    onPressed: () => cubits.shell.selectSection(DashboardSection.models),
                    child: Text(AppLocalizations.of(context).modelsNeededAction),
                  ),
                ),
              ),
            ),
    ),
  );
}

/// Clears the list under a card's header.
class _ClearListButton extends StatelessWidget {
  const _ClearListButton({required this.tooltip, required this.onPressed});

  final String tooltip;

  /// Null when there is nothing to clear, so the button never claims work it
  /// will not do.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.backspace_outlined, size: 16),
      label: Text(AppLocalizations.of(context).transcriptClear),
      style: TextButton.styleFrom(
        foregroundColor: LoreDubPalette.mutedInk,
        minimumSize: const Size(0, 28),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(
          fontFamily: LoreDubFonts.mono,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    ),
  );
}

/// The snapshot screen: a session that loads only the translator and the
/// voice, and translates what the player frames over the game while the
/// snapshot key is held.
class _SnapshotPanel extends StatelessWidget {
  const _SnapshotPanel({super.key, required this.cubits});

  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
    child: Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ModuleLabel(number: '01', label: 'AREA CAPTURE'),
                const SizedBox(height: 14),
                _SnapshotControls(cubits: cubits),
              ],
            ),
          ),
        ),
        _ModelsNeededNotice(
          cubits: cubits,
          ready: (selection) => selection.snapshotModelsInstalled,
        ),
        const SizedBox(height: 16),
        Expanded(child: _SnapshotHistory(cubits: cubits)),
      ],
    ),
  );
}

/// How to select, what the last selection came to, and the session's button.
class _SnapshotControls extends StatelessWidget {
  const _SnapshotControls({required this.cubits});

  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) => _SettingsBuilder(
    cubits: cubits,
    builder: (context, state) => _PipelineBuilder(
      cubits: cubits,
      watch: (pipeline) => (
        pipeline.status,
        pipeline.session,
        pipeline.snapshotReading,
        pipeline.snapshotMissed,
      ),
      builder: (context, pipeline) => _build(context, state.settings, pipeline),
    ),
  );

  Widget _build(BuildContext context, AppSettings settings, LivePipelineState pipeline) {
    final l10n = AppLocalizations.of(context);
    final hotkey = settings.snapshotHotkey;
    final status = _status(l10n, pipeline);
    final details = Column(
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
                onPressed: () => cubits.shell.selectSection(DashboardSection.settings),
                child: Text(l10n.snapshotOpenSettings),
              ),
            ],
          )
        else
          Text(
            l10n.snapshotHowTo(hotkey.display),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        const SizedBox(height: 14),
        _TextLanguagePicker(cubits: cubits),
        const SizedBox(height: 10),
        Text(
          l10n.snapshotNote(spokenLanguageName(l10n, settings.targetLanguage)),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (status != null) ...[const SizedBox(height: 12), status],
      ],
    );
    final button = _SnapshotStartButton(cubits: cubits);
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 640
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [details, const SizedBox(height: 14), button],
            )
          : Row(
              children: [
                Expanded(child: details),
                const SizedBox(width: 24),
                SizedBox(width: _LanguageRow.actionWidth, child: button),
              ],
            ),
    );
  }

  /// What became of the last selection, or that live dubbing holds the key.
  Widget? _status(AppLocalizations l10n, LivePipelineState pipeline) {
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

/// Starts and ends the snapshot session. While live dubbing runs, that
/// session answers the snapshot key, so there is nothing here to start.
class _SnapshotStartButton extends StatelessWidget {
  const _SnapshotStartButton({required this.cubits});

  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) => _PipelineBuilder(
    cubits: cubits,
    watch: (pipeline) => (
      pipeline.status,
      pipeline.session,
      pipeline.startupProgress,
      pipeline.startupStage,
    ),
    // Whether it can start depends on the first load, the packages and the
    // key being bound.
    builder: (context, pipeline) => _ShellBuilder(
      cubits: cubits,
      builder: (context, shell) => _DownloadsBuilder(
        onlyWhatIsInstalled: true,
        cubits: cubits,
        builder: (context, _) => _SettingsBuilder(
          cubits: cubits,
          builder: (context, _) => _build(context, pipeline, initializing: shell.initializing),
        ),
      ),
    ),
  );

  Widget _build(BuildContext context, LivePipelineState pipeline, {required bool initializing}) {
    final l10n = AppLocalizations.of(context);
    final own = pipeline.session == PipelineSession.snapshot;
    final starting = own && pipeline.status == PipelineStatus.starting;
    final running = own && pipeline.running;
    final progress = pipeline.startupProgress;
    final canStart = pipeline.canStartSnapshot(cubits.selection, initializing: initializing);
    return Tooltip(
      message: starting && pipeline.startupStage.isNotEmpty
          ? describeStartupStage(l10n, pipeline.startupStage)
          : '',
      child: FilledButton.icon(
        key: const ValueKey('snapshotStart'),
        onPressed: running || canStart
            ? () => cubits.pipeline.toggleSnapshot(initializing: initializing)
            : null,
        icon: starting
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.4,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : Icon(running ? Icons.stop_rounded : Icons.play_arrow_rounded),
        label: Text(
          starting
              ? (progress == null
                    ? l10n.startingPlain
                    : l10n.startingProgress((progress * 100).round()))
              : running
              ? l10n.snapshotStop
              : l10n.snapshotStart,
        ),
      ),
    );
  }
}

/// Every selection translated so far, newest first.
class _SnapshotHistory extends StatelessWidget {
  const _SnapshotHistory({required this.cubits});

  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) => _PipelineBuilder(
    cubits: cubits,
    watch: (pipeline) => pipeline.snapshots,
    builder: (context, pipeline) => Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 9, 12, 8),
            child: Row(
              children: [
                const _ModuleLabel(number: '02', label: 'SELECTED TEXT'),
                const Spacer(),
                _ClearListButton(
                  tooltip: AppLocalizations.of(context).snapshotClearTooltip,
                  onPressed: pipeline.snapshots.isEmpty ? null : cubits.pipeline.clearSnapshots,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: pipeline.snapshots.isEmpty
                ? const _EmptySnapshots()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    itemCount: pipeline.snapshots.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) =>
                        _TranscriptBubble(entry: pipeline.snapshots[index]),
                  ),
          ),
        ],
      ),
    ),
  );
}

class _EmptySnapshots extends StatelessWidget {
  const _EmptySnapshots();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: constraints.maxHeight > 24 ? constraints.maxHeight - 24 : 0,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.highlight_alt_rounded, size: 42, color: LoreDubPalette.mutedInk),
              const SizedBox(height: 14),
              Text(AppLocalizations.of(context).snapshotEmpty, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The narrowest card that still fits the source switch, the process picker
/// and the language block side by side.
///
/// Measured rather than derived: the switch is as wide as its translated
/// labels make it, so arithmetic over the fixed parts guessed low. What the
/// row actually needs came to about 920 plus
/// [_minimumProcessPickerWidth] for the picker. Below this the picker was
/// squeezed to a stub and broke its label mid-word, so the stacked
/// arrangement takes over and hands it the full width. The widget test walks
/// a range of window sizes to keep this honest.
const _wideSourceRowWidth = 920 + _minimumProcessPickerWidth;

/// Enough for a process name beside the refresh button.
const _minimumProcessPickerWidth = 320.0;

/// Holds a dropdown's list to the room under its field.
///
/// Left to itself the list is as tall as all its entries — a machine runs
/// dozens of processes — and when that is more than the window has below
/// the field, the menu slides up over the field and hides what is being
/// typed into it. So the height is measured from where the field sits and
/// how tall the window is, and measured again when either changes.
class _MenuRoom extends StatefulWidget {
  const _MenuRoom({required this.builder});

  final Widget Function(double menuHeight) builder;

  @override
  State<_MenuRoom> createState() => _MenuRoomState();
}

class _MenuRoomState extends State<_MenuRoom> {
  /// Kept clear between the list and the bottom of the window.
  static const _margin = 16.0;

  /// A window too short for this lets the list overlap rather than become
  /// a slot two entries tall.
  static const _smallest = 160.0;
  static const _largest = 480.0;

  double? _room;

  @override
  Widget build(BuildContext context) {
    // Read so a resized window rebuilds this and measures again.
    final windowHeight = MediaQuery.sizeOf(context).height;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure(windowHeight));
    return widget.builder((_room ?? _largest).clamp(_smallest, _largest));
  }

  void _measure(double windowHeight) {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    final room = windowHeight - bottom - _margin;
    // A few pixels either way are not worth another frame.
    if (_room == null || (room - _room!).abs() > 4) setState(() => _room = room);
  }
}

class _SourceControls extends StatelessWidget {
  const _SourceControls({required this.cubits, required this.compact});

  final DashboardCubits cubits;
  final bool compact;

  @override
  Widget build(BuildContext context) => _SettingsBuilder(
    cubits: cubits,
    builder: (context, state) => _PipelineBuilder(
      cubits: cubits,
      watch: (pipeline) => (pipeline.running, pipeline.processes, pipeline.selectedProcess),
      builder: (context, pipeline) => _build(context, state.settings, pipeline),
    ),
  );

  Widget _build(BuildContext context, AppSettings settings, LivePipelineState pipeline) {
    final l10n = AppLocalizations.of(context);
    final running = pipeline.running;
    final requiresProcess =
        settings.captureMode == CaptureMode.ocr ||
        settings.audioCaptureSource == AudioCaptureSource.process;
    final selector = _MenuRoom(
      builder: (menuHeight) => DropdownMenu<GameProcess>(
        key: ValueKey(pipeline.selectedProcess?.pid),
        initialSelection: pipeline.selectedProcess,
        expandedInsets: EdgeInsets.zero,
        menuHeight: menuHeight,
        enabled: !running && requiresProcess,
        enableFilter: true,
        enableSearch: true,
        requestFocusOnTap: true,
        // A narrow field must not break the label mid-word: it is cut short
        // instead, which still reads as the beginning of the right words.
        label: Text(
          l10n.processLabel,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
        hintText: l10n.processHint,
        inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(hintMaxLines: 1),
        dropdownMenuEntries: pipeline.processes
            .map(
              (process) => DropdownMenuEntry(
                value: process,
                label: l10n.processEntry(process.name, process.pid),
              ),
            )
            .toList(),
        onSelected: running || !requiresProcess ? null : cubits.pipeline.selectProcess,
      ),
    );
    final helper = Text(
      settings.captureMode == CaptureMode.ocr
          ? l10n.captureOcrNote
          : requiresProcess
          ? l10n.captureProcessNote
          : l10n.captureSystemNote,
      style: Theme.of(context).textTheme.bodySmall,
    );
    final sourceSwitch = settings.captureMode == CaptureMode.audio
        ? SegmentedButton<AudioCaptureSource>(
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
                : (selection) => cubits.settings.update(
                    settings.copyWith(audioCaptureSource: selection.first),
                  ),
          )
        : null;
    // Refreshing belongs to the picker, so it travels with it into the
    // compact layout instead of sitting on the row with the start button.
    final picker = Row(
      children: [
        Expanded(child: selector),
        const SizedBox(width: 12),
        IconButton.outlined(
          tooltip: l10n.refreshProcesses,
          onPressed: running ? null : cubits.pipeline.refreshProcesses,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
    final language = _LanguageControls(cubits: cubits);
    final target = _TargetLanguagePicker(cubits: cubits);
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sourceSwitch != null) ...[
            sourceSwitch,
            const SizedBox(height: 12),
          ],
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
            if (sourceSwitch != null) ...[
              sourceSwitch,
              const SizedBox(width: 16),
            ],
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

/// The language the game is dubbed into. Picking it here is the same choice
/// the models screen offers: it selects the translator and the voice together
/// and is remembered between runs.
class _TargetLanguagePicker extends StatelessWidget {
  const _TargetLanguagePicker({required this.cubits});

  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) => _SettingsBuilder(
    cubits: cubits,
    // Which languages read as ready depends on what is downloaded.
    builder: (context, settings) => _DownloadsBuilder(
      onlyWhatIsInstalled: true,
      cubits: cubits,
      builder: (context, _) => _PipelineBuilder(
        cubits: cubits,
        watch: (pipeline) => pipeline.running,
        builder: (context, pipeline) =>
            _build(context, settings.settings.targetLanguage, running: pipeline.running),
      ),
    ),
  );

  Widget _build(BuildContext context, String selected, {required bool running}) {
    final l10n = AppLocalizations.of(context);
    final languages = dubbingLanguages;
    final selection = cubits.selection;
    return _LanguageRow(
      field: DropdownButtonFormField<String>(
        key: const ValueKey('targetLanguage'),
        // A value stored by an older build may no longer be on offer.
        initialValue: languages.contains(selected) ? selected : languages.first,
        isDense: true,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.targetLanguageLabel, isDense: true),
        items: [
          for (final language in languages)
            DropdownMenuItem(
              value: language,
              child: Text(
                selection.isLanguageReady(language)
                    ? spokenLanguageName(l10n, language)
                    : l10n.languageWithoutModels(spokenLanguageName(l10n, language)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: running
            ? null
            : (value) {
                if (value != null) cubits.settings.selectTargetLanguage(value);
              },
      ),
      action: _StartButton(cubits: cubits),
    );
  }
}

/// Loading Marian and Silero takes long enough that a plain label would look
/// like a freeze, so the button carries the progress of the startup itself.
class _StartButton extends StatelessWidget {
  const _StartButton({required this.cubits});

  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) => _PipelineBuilder(
    cubits: cubits,
    // The chosen process belongs here too: without it the button stays grey
    // after the player picks one, because nothing else on the screen moved.
    watch: (pipeline) => (
      pipeline.status,
      pipeline.session,
      pipeline.startupProgress,
      pipeline.startupStage,
      pipeline.selectedProcess,
    ),
    // Whether it can start at all depends on the first load having finished
    // and on the packages being there.
    builder: (context, pipeline) => _ShellBuilder(
      cubits: cubits,
      builder: (context, shell) => _DownloadsBuilder(
        onlyWhatIsInstalled: true,
        cubits: cubits,
        builder: (context, _) => _build(context, pipeline, initializing: shell.initializing),
      ),
    ),
  );

  Widget _build(
    BuildContext context,
    LivePipelineState pipeline, {
    required bool initializing,
  }) {
    final l10n = AppLocalizations.of(context);
    // A snapshot session is not this screen's to show: starting here takes
    // the worker over from it.
    final live = pipeline.session == PipelineSession.live;
    final starting = live && pipeline.status == PipelineStatus.starting;
    final progress = pipeline.startupProgress;
    final running = pipeline.liveRunning;
    final canStart = pipeline.canStart(cubits.selection, initializing: initializing);
    if (live &&
        (pipeline.status == PipelineStatus.listening || pipeline.status == PipelineStatus.paused)) {
      return _SessionButtons(cubits: cubits, paused: pipeline.status == PipelineStatus.paused);
    }
    return Tooltip(
      message: starting && pipeline.startupStage.isNotEmpty
          ? describeStartupStage(l10n, pipeline.startupStage)
          : '',
      child: FilledButton.icon(
        onPressed: running || canStart
            ? () => cubits.pipeline.toggle(initializing: initializing)
            : null,
        icon: starting
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.4,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : Icon(running ? Icons.stop_rounded : Icons.play_arrow_rounded),
        label: Text(
          starting
              ? (progress == null
                    ? l10n.startingPlain
                    : l10n.startingProgress((progress * 100).round()))
              : running
              ? l10n.stopDubbing
              : l10n.startDubbing,
        ),
      ),
    );
  }
}

/// A live session's two controls: rest or wake it, and end it.
///
/// The wide button is the press most likely next — stop while dubbing,
/// resume while paused — and the other waits beside it as an outlined icon,
/// its name in the tooltip. Both fit the slot the start button had.
class _SessionButtons extends StatelessWidget {
  const _SessionButtons({required this.cubits, required this.paused});

  final DashboardCubits cubits;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (paused) {
      return Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              key: const ValueKey('resumeButton'),
              onPressed: cubits.pipeline.resume,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l10n.resumeDubbing),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: l10n.stopHint,
            child: IconButton.outlined(
              key: const ValueKey('stopButton'),
              onPressed: cubits.pipeline.stop,
              icon: const Icon(Icons.stop_rounded),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Tooltip(
          message: l10n.pauseHint,
          child: IconButton.outlined(
            key: const ValueKey('pauseButton'),
            onPressed: cubits.pipeline.pause,
            icon: const Icon(Icons.pause_rounded),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('stopButton'),
            onPressed: cubits.pipeline.stop,
            icon: const Icon(Icons.stop_rounded),
            label: Text(l10n.stopDubbing),
          ),
        ),
      ],
    );
  }
}

/// Language of the original speech. Naming it skips whisper's detection pass,
/// which is a noticeable share of the delay before a phrase is voiced.
class _LanguageControls extends StatelessWidget {
  const _LanguageControls({required this.cubits});

  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) => _SettingsBuilder(
    cubits: cubits,
    builder: (context, state) => _PipelineBuilder(
      cubits: cubits,
      watch: (pipeline) => (pipeline.running, pipeline.detectedLanguage),
      builder: (context, pipeline) => _build(context, state.settings, pipeline),
    ),
  );

  Widget _build(BuildContext context, AppSettings settings, LivePipelineState pipeline) {
    // Subtitles are text: there is nothing to detect, only a script to read.
    if (settings.captureMode == CaptureMode.ocr) return _TextLanguagePicker(cubits: cubits);
    final l10n = AppLocalizations.of(context);
    final locked = pipeline.running;
    final detected = settings.detectSourceLanguage ? pipeline.detectedLanguage : null;
    return _LanguageRow(
      field: DropdownButtonFormField<String>(
        key: const ValueKey('sourceLanguage'),
        initialValue: settings.sourceLanguage,
        isDense: true,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.sourceLanguageLabel, isDense: true),
        items: [
          for (final language in spokenLanguages)
            DropdownMenuItem(
              value: language,
              child: Text(spokenLanguageName(l10n, language)),
            ),
        ],
        onChanged: locked || settings.detectSourceLanguage
            ? null
            : (value) {
                if (value != null) {
                  cubits.settings.update(settings.copyWith(sourceLanguage: value));
                }
              },
      ),
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: settings.detectSourceLanguage,
            onChanged: locked
                ? null
                : (value) => cubits.settings.update(settings.copyWith(detectSourceLanguage: value)),
          ),
          const SizedBox(width: 6),
          Flexible(
            // Once whisper has decided, its answer takes the label's place:
            // the switch itself already says that detection is on.
            child: Text(
              detected == null
                  ? l10n.detectLanguage
                  : l10n.detectedLanguage(spokenLanguageName(l10n, detected)),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: detected == null ? null : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The language of text read off the screen. Windows OCR detects nothing and
/// the translators read only English, so the choice is English or the
/// dubbing language itself, which is then voiced as it is.
class _TextLanguagePicker extends StatelessWidget {
  const _TextLanguagePicker({required this.cubits});

  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) => _SettingsBuilder(
    cubits: cubits,
    builder: (context, state) => _PipelineBuilder(
      cubits: cubits,
      watch: (pipeline) => pipeline.running,
      builder: (context, pipeline) => _build(context, state.settings, locked: pipeline.running),
    ),
  );

  Widget _build(BuildContext context, AppSettings settings, {required bool locked}) {
    final l10n = AppLocalizations.of(context);
    final languages = {fallbackSpokenLanguage, settings.targetLanguage};
    return _LanguageRow(
      field: DropdownButtonFormField<String>(
        // Keyed by the value: a new dubbing language can change it from
        // outside the field.
        key: ValueKey('textLanguage-${settings.textLanguage}'),
        initialValue: settings.textLanguage,
        isDense: true,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.textLanguageLabel, isDense: true),
        items: [
          for (final language in languages)
            DropdownMenuItem(value: language, child: Text(spokenLanguageName(l10n, language))),
        ],
        onChanged: locked
            ? null
            : (value) {
                if (value != null) cubits.settings.update(settings.copyWith(sourceLanguage: value));
              },
      ),
      action: Text(
        l10n.textLanguageNote,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

/// The two language pickers sit in different rows, so they are laid out
/// identically — same field width, same gap, same trailing width — to line up
/// exactly one under the other.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.field, required this.action});

  static const double fieldWidth = 210;

  /// Wide enough for the detected language to replace the toggle's label
  /// without being cut short.
  static const double actionWidth = 240;

  final Widget field;
  final Widget action;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(width: fieldWidth, child: field),
      const SizedBox(width: 12),
      SizedBox(width: actionWidth, child: action),
    ],
  );
}

class _ModuleLabel extends StatelessWidget {
  const _ModuleLabel({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 28,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: LoreDubPalette.orange,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: LoreDubPalette.ink),
        ),
        child: Text(
          number,
          style: const TextStyle(
            fontFamily: LoreDubFonts.mono,
            color: LoreDubPalette.ink,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(width: 9),
      Text(
        label,
        style: const TextStyle(
          fontFamily: LoreDubFonts.mono,
          color: LoreDubPalette.ink,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    ],
  );
}

/// One recognized phrase, shaped like the speech bubble on the application
/// icon: the text on the dark signal surface, and the time it took beside the
/// tail on the orange accent.
class _TranscriptBubble extends StatelessWidget {
  const _TranscriptBubble({required this.entry});

  static const double _tailInset = 28;
  static const Size _tailSize = Size(26, 14);

  final TranscriptEntry entry;

  @override
  Widget build(BuildContext context) {
    final original = entry.original.isEmpty ? entry.english : entry.original;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          // Sized by its text, with enough width left for the tail to stay
          // under the bubble even for a two-word reply.
          constraints: const BoxConstraints(minWidth: 80),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 15),
          decoration: BoxDecoration(
            color: LoreDubPalette.graphite,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (original.isNotEmpty) ...[
                Text(
                  original,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 7),
              ],
              Text(
                entry.translated,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        Row(
          // Top-aligned: the badge is taller than the tail, and centring the
          // row would lift the tail off the bottom edge of the bubble.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: _tailInset),
            CustomPaint(size: _tailSize, painter: _BubbleTailPainter()),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _LatencyBadge(milliseconds: entry.latency.inMilliseconds),
            ),
          ],
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Asymmetric like the icon: the leading edge slopes away from the bubble
    // and the trailing edge drops almost straight down.
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * 0.82, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = LoreDubPalette.graphite);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) => false;
}

class _LatencyBadge extends StatelessWidget {
  const _LatencyBadge({required this.milliseconds});

  final int milliseconds;

  @override
  Widget build(BuildContext context) => Container(
    height: 22,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 11),
    decoration: BoxDecoration(
      color: LoreDubPalette.orange,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      AppLocalizations.of(context).latencyMs(milliseconds),
      // A fixed height with no leading keeps the label centred in the pill
      // instead of riding on the font's baseline.
      style: const TextStyle(
        fontFamily: LoreDubFonts.mono,
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        height: 1,
      ),
    ),
  );
}

class _EmptyTranscript extends StatelessWidget {
  const _EmptyTranscript({required this.targetLanguage, required this.captureMode});

  /// The pipeline ends in whichever language is selected, so the hint says so
  /// rather than always naming Russian.
  final String targetLanguage;

  /// Subtitle mode starts from Windows OCR, not Whisper, and the hint says so.
  final CaptureMode captureMode;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: constraints.maxHeight > 24 ? constraints.maxHeight - 24 : 0,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.subtitles_outlined,
                size: 42,
                color: LoreDubPalette.mutedInk,
              ),
              const SizedBox(height: 14),
              Text(AppLocalizations.of(context).emptyTranscript),
              const SizedBox(height: 6),
              Text(
                switch (captureMode) {
                  CaptureMode.audio => AppLocalizations.of(context).pipelineSummary,
                  CaptureMode.ocr => AppLocalizations.of(context).pipelineSummaryOcr,
                }(spokenLanguageName(AppLocalizations.of(context), targetLanguage)),
                style: const TextStyle(color: LoreDubPalette.mutedInk),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ModelsPanel extends StatelessWidget {
  const _ModelsPanel({super.key, required this.cubits});

  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) => _DownloadsBuilder(
    cubits: cubits,
    builder: (context, downloads) => _SettingsBuilder(
      cubits: cubits,
      builder: (context, settings) => _PipelineBuilder(
        cubits: cubits,
        watch: (pipeline) => pipeline.running,
        builder: (context, pipeline) => _build(context, downloads, running: pipeline.running),
      ),
    ),
  );

  Widget _build(BuildContext context, DownloadsState downloads, {required bool running}) {
    final l10n = AppLocalizations.of(context);
    final selection = cubits.selection;
    final selected = selection.settings.targetLanguage;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      children: [
        _ModuleLabel(number: '01', label: l10n.sectionRecognition),
        const SizedBox(height: 4),
        _SectionNote(l10n.sectionRecognitionNote),
        if (selection.recognitionNeedsEnglish) ...[
          const SizedBox(height: 8),
          _SectionNote(l10n.recognitionNeedsEnglish),
        ],
        // Size against quality is the whole choice, so it is drawn as a chart;
        // a window too narrow for the bars gets the plain cards instead.
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= WhisperModelChart.minimumWidth) {
              return Padding(
                padding: const EdgeInsets.only(top: 18),
                child: WhisperModelChart(
                  models: selection.recognitionModels,
                  selectedId: selection.recognition?.model.id,
                  running: running,
                  isStopping: downloads.isStopping,
                  onInstall: cubits.downloads.installModel,
                  onPause: (state) => cubits.downloads.pauseDownload(state.model.id),
                  onCancel: (state) => cubits.downloads.cancelDownload(state.model.id),
                  onRemove: cubits.downloads.removeModel,
                  onSelect: running
                      ? null
                      : (state) => cubits.settings.selectRecognitionModel(state.model.id),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final state in selection.recognitionModels) ...[
                  const SizedBox(height: 12),
                  _ModelCard(
                    state: state,
                    onInstall: () => cubits.downloads.installModel(state),
                    onPause: () => cubits.downloads.pauseDownload(state.model.id),
                    onCancel: () => cubits.downloads.cancelDownload(state.model.id),
                    stopping: downloads.isStopping(state.model.id),
                    choosable: true,
                    selected: state.model.id == selection.recognition?.model.id,
                    onSelect: running
                        ? null
                        : () => cubits.settings.selectRecognitionModel(state.model.id),
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 26),
        // A translator and a voice are only ever useful together, so a
        // language is one tile: downloaded, picked and deleted as a pair.
        _ModuleLabel(number: '02', label: l10n.sectionLanguages),
        const SizedBox(height: 4),
        _SectionNote(l10n.sectionLanguagesNote),
        const SizedBox(height: 12),
        ModelTileGrid(
          children: [
            for (final pair in selection.languagePairs)
              LanguagePairTile(
                key: ValueKey('languageTile-${pair.language}'),
                pair: pair,
                selected: pair.language == selected,
                running: running,
                isStopping: downloads.isStopping,
                onSelect: running
                    ? null
                    : () => cubits.settings.selectTargetLanguage(pair.language),
                onInstall: cubits.downloads.installModel,
                onPause: (state) => cubits.downloads.pauseDownload(state.model.id),
                onCancel: (state) => cubits.downloads.cancelDownload(state.model.id),
                onRemove: cubits.downloads.removeModel,
              ),
          ],
        ),
        for (final pair in selection.languagePairs)
          for (final part in pair.parts)
            if (part.error != null) ...[
              const SizedBox(height: 10),
              ModelFailureRow(state: part),
            ],
        const SizedBox(height: 26),
        _ModuleLabel(number: '03', label: l10n.sectionVoiceConversion),
        const SizedBox(height: 4),
        _SectionNote(l10n.sectionVoiceConversionNote),
        const SizedBox(height: 12),
        ModelTileGrid(
          children: [
            for (final state in selection.voiceConverters)
              ConverterTile(
                key: ValueKey('converterTile-${state.model.id}'),
                state: state,
                inUse: selection.clonesVoice,
                running: running,
                isStopping: downloads.isStopping,
                onInstall: cubits.downloads.installModel,
                onPause: (state) => cubits.downloads.pauseDownload(state.model.id),
                onCancel: (state) => cubits.downloads.cancelDownload(state.model.id),
                onRemove: cubits.downloads.removeModel,
              ),
          ],
        ),
        for (final state in selection.voiceConverters)
          if (state.error != null) ...[
            const SizedBox(height: 10),
            ModelFailureRow(state: state),
          ],
      ],
    );
  }
}

class _SectionNote extends StatelessWidget {
  const _SectionNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 2),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}

/// Pause/resume and cancel for a download in flight.
///
/// Kept to two small buttons so it fits the Whisper cards a narrow window
/// falls back to.
class _DownloadControls extends StatelessWidget {
  const _DownloadControls({
    required this.paused,
    required this.stopping,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  final bool paused;
  final bool stopping;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: stopping
              ? l10n.downloadStopping
              : (paused ? l10n.downloadResume : l10n.downloadPause),
          onPressed: stopping ? null : (paused ? onResume : onPause),
          icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 20),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          padding: EdgeInsets.zero,
        ),
        IconButton(
          tooltip: l10n.downloadCancel,
          onPressed: stopping ? null : onCancel,
          icon: const Icon(Icons.close_rounded, size: 20),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.state,
    required this.onInstall,
    required this.onPause,
    required this.onCancel,
    this.stopping = false,
    this.choosable = false,
    this.selected = false,
    this.onSelect,
  });

  final ModelInstallState state;
  final VoidCallback onInstall;

  /// Stopping keeps what arrived; cancelling throws it away.
  final VoidCallback onPause;
  final VoidCallback onCancel;

  /// A stop has been asked for and the download has not noticed yet.
  final bool stopping;

  /// Whether this card is one of a set the player picks between. Only the
  /// Whisper builds are drawn as cards now, in a window too narrow for
  /// their chart; such a card shows which one is chosen.
  final bool choosable;
  final bool selected;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final details = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (choosable)
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: selected ? LoreDubPalette.orange : LoreDubPalette.outline,
          )
        else
          Icon(
            state.installed ? Icons.check_circle_rounded : Icons.memory_rounded,
            color: state.installed ? LoreDubPalette.success : LoreDubPalette.mutedInk,
          ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                modelTitle(l10n, state.model),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              Text(
                modelDescription(l10n, state.model),
                style: const TextStyle(color: LoreDubPalette.mutedInk),
              ),
              if (state.progress case final progress?) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      state.paused
                          ? '${(progress * 100).round()}% · ${l10n.downloadPaused}'
                          : '${(progress * 100).round()}%',
                    ),
                    const Spacer(),
                    _DownloadControls(
                      paused: state.paused,
                      stopping: stopping,
                      onPause: onPause,
                      onResume: onInstall,
                      onCancel: onCancel,
                    ),
                  ],
                ),
              ],
              if (state.error case final error?) ...[
                const SizedBox(height: 8),
                Text(
                  describeFailure(l10n, error),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    final action = OutlinedButton.icon(
      onPressed: state.installed || state.stoppable ? null : onInstall,
      icon: Icon(state.installed ? Icons.check_rounded : Icons.download_rounded),
      label: Text(state.installed ? l10n.modelInstalled : l10n.modelDownload),
    );
    final body = Padding(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: details),
              const SizedBox(width: 20),
              action,
            ],
          );
        },
      ),
    );
    return Card(
      // The whole card picks the language, not just the small indicator.
      child: onSelect == null
          ? body
          : InkWell(
              onTap: onSelect,
              borderRadius: BorderRadius.circular(12),
              child: body,
            ),
    );
  }
}

class _SettingsPanel extends StatefulWidget {
  const _SettingsPanel({super.key, required this.cubits});

  final DashboardCubits cubits;

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  final _proxyFormKey = GlobalKey<FormState>();
  final _pythonFormKey = GlobalKey<FormState>();
  late final TextEditingController _proxyController;
  late final TextEditingController _pythonController;

  DashboardCubits get cubits => widget.cubits;

  AppSettings get _settings => cubits.settings.settings;

  @override
  void initState() {
    super.initState();
    _proxyController = TextEditingController(
      text: _settings.modelProxyUrl,
    );
    _pythonController = TextEditingController(
      text: _settings.pythonExecutable.isEmpty
          ? bundledPythonExecutablePath()
          : _settings.pythonExecutable,
    );
  }

  @override
  void dispose() {
    _proxyController.dispose();
    _pythonController.dispose();
    super.dispose();
  }

  String? _validateProxy(String? value) {
    try {
      parseModelProxyUrl(value ?? '');
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  /// Why a combination cannot be bound: one that takes a key from the game,
  /// or one another action already has. [others] pairs each other action's
  /// combination with its name.
  String? _hotkeyProblem(
    AppLocalizations l10n,
    Hotkey hotkey, {
    required List<(Hotkey?, String)> others,
  }) {
    if (!hotkey.leavesGameKeys) return l10n.hotkeyNeedsModifier;
    for (final (other, name) in others) {
      if (other != null && other.sameCombination(hotkey)) return l10n.hotkeyDuplicate(name);
    }
    return null;
  }

  void _saveProxy() {
    if (!(_proxyFormKey.currentState?.validate() ?? false)) return;
    cubits.settings.update(_settings.copyWith(modelProxyUrl: _proxyController.text.trim()));
  }

  Future<void> _findPython() async {
    final executable = await cubits.settings.findPythonExecutable();
    if (executable == null || !mounted) return;
    _pythonController.text = executable;
  }

  void _savePython() {
    if (!(_pythonFormKey.currentState?.validate() ?? false)) return;
    cubits.settings.update(_settings.copyWith(pythonExecutable: _pythonController.text.trim()));
  }

  @override
  Widget build(BuildContext context) => _SettingsBuilder(
    cubits: cubits,
    builder: (context, state) => _PipelineBuilder(
      cubits: cubits,
      watch: (pipeline) => pipeline.running,
      // The compute card and the model directory listen to the downloads
      // themselves, so a runtime arriving does not redraw the whole page.
      builder: (context, pipeline) => _build(context, state, running: pipeline.running),
    ),
  );

  Widget _build(BuildContext context, SettingsState state, {required bool running}) {
    final l10n = AppLocalizations.of(context);
    final settings = state.settings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      children: [
        _SettingCard(
          title: l10n.settingsInterfaceLanguage,
          subtitle: l10n.interfaceLanguageNote,
          child: SegmentedButton<String>(
            segments: [
              for (final language in interfaceLanguages)
                ButtonSegment(
                  value: language,
                  label: Text(interfaceLanguageName(language)),
                ),
            ],
            selected: {settings.interfaceLanguage},
            onSelectionChanged: (selection) =>
                cubits.settings.update(settings.copyWith(interfaceLanguage: selection.first)),
          ),
        ),
        const SizedBox(height: 12),
        _SettingCard(
          title: l10n.settingsCaptureSource,
          child: SegmentedButton<CaptureMode>(
            segments: [
              ButtonSegment(
                value: CaptureMode.audio,
                icon: const Icon(Icons.hearing_rounded),
                label: Text(l10n.captureAudio),
              ),
              ButtonSegment(
                value: CaptureMode.ocr,
                icon: const Icon(Icons.subtitles_rounded),
                label: Text(l10n.captureOcr),
              ),
            ],
            selected: {settings.captureMode},
            onSelectionChanged: running
                ? null
                : (selection) =>
                      cubits.settings.update(settings.copyWith(captureMode: selection.first)),
          ),
        ),
        if (settings.captureMode == CaptureMode.ocr) ...[
          const SizedBox(height: 12),
          _SettingCard(
            title: l10n.settingsOcrRegion,
            subtitle: l10n.ocrRegionNote,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OcrRegionPicker(
                  key: const ValueKey('ocrRegion'),
                  region: settings.ocrRegion,
                  semanticLabel: l10n.ocrRegionHelp,
                  onChanged: running
                      ? null
                      : (region) => cubits.settings.update(settings.copyWith(ocrRegion: region)),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      l10n.ocrRegionValue(
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
                          : () => cubits.settings.update(
                              settings.copyWith(ocrRegion: OcrRegion.standard),
                            ),
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: Text(l10n.ocrRegionReset),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.ocrRegionHelp,
                  style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _SettingCard(
          title: l10n.settingsOriginalVolume,
          subtitle: l10n.originalVolumeValue((settings.originalVolume * 100).round()),
          child: Slider(
            value: settings.originalVolume,
            min: 0,
            max: 0.5,
            divisions: 25,
            label: '${(settings.originalVolume * 100).round()}%',
            onChanged: running
                ? null
                : (value) => cubits.settings.update(settings.copyWith(originalVolume: value)),
          ),
        ),
        const SizedBox(height: 12),
        _SettingCard(
          title: l10n.settingsTtsSpeed,
          subtitle: l10n.speedValue(settings.ttsSpeed.toStringAsFixed(2)),
          child: Slider(
            value: settings.ttsSpeed,
            min: 0.9,
            max: 1.35,
            divisions: 18,
            label: l10n.speedValue(settings.ttsSpeed.toStringAsFixed(2)),
            onChanged: running
                ? null
                : (value) => cubits.settings.update(settings.copyWith(ttsSpeed: value)),
          ),
        ),
        const SizedBox(height: 12),
        _VoiceCard(cubits: cubits),
        const SizedBox(height: 12),
        _SettingCard(
          title: l10n.settingsHotkeys,
          subtitle: l10n.hotkeysNote,
          child: Column(
            children: [
              _HotkeyRow(
                label: l10n.hotkeyPause,
                field: HotkeyField(
                  key: const ValueKey('pauseHotkey'),
                  value: settings.pauseHotkey,
                  enabled: !running,
                  validate: (hotkey) => _hotkeyProblem(
                    l10n,
                    hotkey,
                    others: [
                      (_settings.resumeHotkey, l10n.hotkeyResume),
                      (_settings.snapshotHotkey, l10n.hotkeySnapshot),
                    ],
                  ),
                  onChanged: (hotkey) => cubits.settings.update(
                    hotkey == null
                        ? _settings.copyWith(clearPauseHotkey: true)
                        : _settings.copyWith(pauseHotkey: hotkey),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _HotkeyRow(
                label: l10n.hotkeyResume,
                field: HotkeyField(
                  key: const ValueKey('resumeHotkey'),
                  value: settings.resumeHotkey,
                  enabled: !running,
                  validate: (hotkey) => _hotkeyProblem(
                    l10n,
                    hotkey,
                    others: [
                      (_settings.pauseHotkey, l10n.hotkeyPause),
                      (_settings.snapshotHotkey, l10n.hotkeySnapshot),
                    ],
                  ),
                  onChanged: (hotkey) => cubits.settings.update(
                    hotkey == null
                        ? _settings.copyWith(clearResumeHotkey: true)
                        : _settings.copyWith(resumeHotkey: hotkey),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _HotkeyRow(
                label: l10n.hotkeySnapshot,
                field: HotkeyField(
                  key: const ValueKey('snapshotHotkey'),
                  value: settings.snapshotHotkey,
                  enabled: !running,
                  validate: (hotkey) => _hotkeyProblem(
                    l10n,
                    hotkey,
                    others: [
                      (_settings.pauseHotkey, l10n.hotkeyPause),
                      (_settings.resumeHotkey, l10n.hotkeyResume),
                    ],
                  ),
                  onChanged: (hotkey) => cubits.settings.update(
                    hotkey == null
                        ? _settings.copyWith(clearSnapshotHotkey: true)
                        : _settings.copyWith(snapshotHotkey: hotkey),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SettingCard(
          title: l10n.settingsPerformance,
          subtitle: l10n.performanceNote(Platform.numberOfProcessors, defaultCpuThreads()),
          child: DropdownButtonFormField<int>(
            initialValue: settings.cpuThreads,
            decoration: InputDecoration(labelText: l10n.cpuThreads),
            items: _threadOptions(settings.cpuThreads)
                .map((value) => DropdownMenuItem(value: value, child: Text('$value')))
                .toList(),
            onChanged: running
                ? null
                : (value) {
                    if (value != null) {
                      cubits.settings.update(settings.copyWith(cpuThreads: value));
                    }
                  },
          ),
        ),
        const SizedBox(height: 12),
        _ComputeDeviceCard(cubits: cubits),
        const SizedBox(height: 12),
        _SettingCard(
          title: l10n.settingsPython,
          subtitle: l10n.pythonNote,
          child: Form(
            key: _pythonFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _pythonController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.pythonFieldLabel,
                    helperText: l10n.pythonFieldHelper,
                    prefixIcon: const Icon(Icons.terminal_rounded),
                  ),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? l10n.pythonFieldRequired : null,
                  onFieldSubmitted: (_) => _savePython(),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: state.searchingPython ? null : _findPython,
                      icon: state.searchingPython
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.manage_search_rounded),
                      label: Text(
                        state.searchingPython ? l10n.pythonSearching : l10n.pythonFindAutomatically,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        _pythonController.text = bundledPythonExecutablePath();
                        _savePython();
                      },
                      icon: const Icon(Icons.settings_backup_restore_rounded),
                      label: Text(l10n.pythonBundled),
                    ),
                    FilledButton.icon(
                      onPressed: _savePython,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(l10n.save),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SettingCard(
          title: l10n.settingsModelDownloads,
          subtitle: l10n.proxyNote,
          child: Form(
            key: _proxyFormKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final field = TextFormField(
                  controller: _proxyController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.proxyLabel,
                    hintText: 'http://127.0.0.1:7890',
                    helperText: l10n.proxyHelper,
                    helperMaxLines: 2,
                    prefixIcon: const Icon(Icons.lan_outlined),
                  ),
                  validator: _validateProxy,
                  onFieldSubmitted: (_) => _saveProxy(),
                );
                final save = OutlinedButton.icon(
                  onPressed: _saveProxy,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(l10n.save),
                );
                if (constraints.maxWidth < 620) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      field,
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerRight, child: save),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: field),
                    const SizedBox(width: 16),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: save,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SettingCard(
          title: l10n.settingsModelDirectory,
          subtitle: l10n.modelDirectoryNote,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final path = _DownloadsBuilder(
                cubits: cubits,
                builder: (context, downloads) => SelectableText(
                  downloads.modelDirectoryPath,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
              final open = OutlinedButton.icon(
                onPressed: cubits.downloads.openModelDirectory,
                icon: const Icon(Icons.folder_open_rounded),
                label: Text(l10n.openInExplorer),
              );
              if (constraints.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    path,
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: open),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: path),
                  const SizedBox(width: 16),
                  open,
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Thread counts worth offering on this machine, always including whatever is
/// currently selected so a setting carried over from another CPU still shows.
List<int> _threadOptions(int selected) {
  final options =
      <int>{2, 3, 4, 6, 8, 12, 16}.where((value) => value <= Platform.numberOfProcessors).toSet()
        ..add(selected)
        ..add(defaultCpuThreads());
  return options.toList()..sort();
}

/// Which voice reads the dubbing, and whether it follows the original.
///
/// The automatic half only makes sense when the language's package ships
/// both a man's and a woman's voice and there is audio to hear, so when it
/// does not, the option is disabled and the reason is written out rather
/// than left for the user to guess at.
class _VoiceCard extends StatelessWidget {
  const _VoiceCard({required this.cubits});

  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) => _SettingsBuilder(
    cubits: cubits,
    // Which voices exist comes from the downloaded package.
    builder: (context, state) => _DownloadsBuilder(
      onlyWhatIsInstalled: true,
      cubits: cubits,
      builder: (context, _) => _PipelineBuilder(
        cubits: cubits,
        watch: (pipeline) => (pipeline.running, pipeline.spokenVoice),
        builder: (context, pipeline) => _build(context, state, pipeline),
      ),
    ),
  );

  Widget _build(BuildContext context, SettingsState state, LivePipelineState pipeline) {
    final l10n = AppLocalizations.of(context);
    final settings = state.settings;
    final selection = cubits.selection;
    final running = pipeline.running;
    final voices = selection.availableVoices;
    final canFollow = selection.canFollowSpeaker;
    final canClone = selection.canUseOriginalVoice;
    // A mode this setup cannot honour is shown as the one that will run.
    final mode = switch (settings.voiceMode) {
      VoiceMode.original when canClone => VoiceMode.original,
      VoiceMode.automatic || VoiceMode.original when canFollow => VoiceMode.automatic,
      _ => VoiceMode.chosen,
    };
    final converterInstalled = selection.voiceConverter?.installed ?? false;
    return _SettingCard(
      title: l10n.settingsVoice,
      subtitle: l10n.voiceNote,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<VoiceMode>(
            segments: [
              ButtonSegment(
                value: VoiceMode.automatic,
                label: Text(l10n.voiceAutomatic),
                enabled: canFollow,
              ),
              ButtonSegment(value: VoiceMode.chosen, label: Text(l10n.voiceFixed)),
              ButtonSegment(
                value: VoiceMode.original,
                label: Text(l10n.voiceOriginal),
                enabled: canClone,
              ),
            ],
            selected: {mode},
            onSelectionChanged: running
                ? null
                : (picked) => cubits.settings.update(settings.withVoiceMode(picked.first)),
          ),
          if (mode == VoiceMode.original) ...[
            const SizedBox(height: 10),
            Text(
              converterInstalled ? l10n.voiceOriginalNote : l10n.voiceOriginalMissing,
              style: TextStyle(
                color: converterInstalled ? LoreDubPalette.mutedInk : LoreDubPalette.warning,
                fontSize: 12,
              ),
            ),
            if (converterInstalled) ...[
              const SizedBox(height: 12),
              _VoiceBankControls(
                cubits: cubits,
                settings: settings,
                size: state.voiceBankSize,
                running: running,
              ),
            ],
          ],
          if (!canFollow) ...[
            const SizedBox(height: 10),
            Text(
              settings.captureMode == CaptureMode.ocr
                  ? l10n.voiceNeedsAudio
                  : l10n.voiceUnavailable,
              style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 12),
            ),
          ],
          // The original voice needs a base to lay its timbre over; when the
          // package cannot follow the speaker, that base is chosen by hand.
          if ((mode == VoiceMode.chosen || (mode == VoiceMode.original && !canFollow)) &&
              voices.isNotEmpty) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: const ValueKey('voice'),
              initialValue: selection.voice,
              decoration: InputDecoration(labelText: l10n.voiceFieldLabel),
              items: [
                for (final voice in voices)
                  DropdownMenuItem(value: voice.id, child: Text(voiceLabel(l10n, voice))),
              ],
              onChanged: running
                  ? null
                  : (value) {
                      if (value != null) {
                        cubits.settings.update(settings.copyWith(voice: value));
                      }
                    },
            ),
          ],
          // With one voice for every line there is nobody to tell apart.
          if (mode != VoiceMode.chosen) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Switch(
                  value: settings.overlapVoices,
                  onChanged: running
                      ? null
                      : (value) => cubits.settings.update(settings.copyWith(overlapVoices: value)),
                ),
                const SizedBox(width: 6),
                Flexible(child: Text(l10n.voiceOverlap)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.voiceOverlapNote,
              style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 12),
            ),
          ],
          // Which voice the automatic choice actually settled on, so it is
          // not a silent decision — the same courtesy the detected language
          // gets on the live screen.
          if (mode != VoiceMode.chosen ? pipeline.spokenVoice : null case final speaking?) ...[
            const SizedBox(height: 10),
            Text(
              mode == VoiceMode.original
                  ? l10n.voiceOriginalSpeaking(speaking)
                  : l10n.voiceSpeaking(speaking),
              style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

/// Whether the original voice remembers the characters, how many it has,
/// and a way to forget them. Forgetting cannot be undone, so it is asked.
class _VoiceBankControls extends StatelessWidget {
  const _VoiceBankControls({
    required this.cubits,
    required this.settings,
    required this.size,
    required this.running,
  });

  final DashboardCubits cubits;
  final AppSettings settings;
  final int size;
  final bool running;

  Future<void> _confirmClear(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(l10n.voiceBankClearTitle),
        content: Text(
          l10n.voiceBankClearMessage,
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.voiceBankClearCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.voiceBankClearConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubits.settings.clearVoiceBank();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Switch(
              value: settings.voiceBank,
              onChanged: running
                  ? null
                  : (value) => cubits.settings.update(settings.copyWith(voiceBank: value)),
            ),
            const SizedBox(width: 6),
            Flexible(child: Text(l10n.voiceBank)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          settings.voiceBank ? l10n.voiceBankOnNote : l10n.voiceBankOffNote,
          style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 12),
        ),
        // Shown with the switch off too: voices kept earlier are still on
        // disk, and this is where they are given back.
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.voiceBankCount(size),
                style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
              ),
            ),
            TextButton.icon(
              // The running worker holds the bank and would write it back.
              onPressed: running || size == 0 ? null : () => _confirmClear(context),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(l10n.voiceBankClear),
              style: TextButton.styleFrom(foregroundColor: LoreDubPalette.mutedInk),
            ),
          ],
        ),
      ],
    );
  }
}

/// The compute section: one preset for the whole pipeline, then a table of
/// stage by device showing what that preset actually resolved to and letting
/// any cell be picked, and the GPU packages as tiles. A backend the machine
/// cannot run is shown but faded, so an AMD owner can see that CUDA exists
/// and why it is not on offer.
class _ComputeDeviceCard extends StatelessWidget {
  const _ComputeDeviceCard({required this.cubits});

  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) => _DownloadsBuilder(
    cubits: cubits,
    builder: (context, downloads) => _SettingsBuilder(
      cubits: cubits,
      builder: (context, state) => _PipelineBuilder(
        cubits: cubits,
        watch: (pipeline) => (pipeline.running, pipeline.backendSignature),
        builder: (context, pipeline) => _build(context, downloads, state.settings, pipeline),
      ),
    ),
  );

  Widget _build(
    BuildContext context,
    DownloadsState downloads,
    AppSettings settings,
    LivePipelineState pipeline,
  ) {
    final l10n = AppLocalizations.of(context);
    final running = pipeline.running;
    final adapter = downloads.availability.adapters.firstOrNull;
    // OpenVoice runs only for the original voice, so its row waits for it.
    final stages = [
      for (final stage in ComputeStage.values)
        if (stage != ComputeStage.voiceConversion || settings.originalVoice) stage,
    ];
    final availability = downloads.availability;
    // The packages this machine could use, and any already on disk: a card
    // that was taken out must not strand gigabytes nobody can give back.
    final runtimes = [
      for (final runtime in downloads.runtimes)
        if (runtime.installed ||
            runtime.stoppable ||
            _servesHardware(runtime.package.id, availability))
          runtime,
    ];
    return _SettingCard(
      title: l10n.settingsComputeDevice,
      subtitle: l10n.computeDeviceNote,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<ComputeDevice>(
            segments: [
              for (final device in ComputeDevice.values)
                ButtonSegment(value: device, label: Text(computeDeviceName(l10n, device))),
            ],
            selected: {settings.computeDevice},
            onSelectionChanged: running
                ? null
                : (selection) => cubits.settings.selectComputeDevice(selection.first),
          ),
          const SizedBox(height: 14),
          Text(
            adapter == null ? l10n.computeNoAdapter : l10n.computeAdapterDetected(adapter.name),
            style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
          ),
          const SizedBox(height: 14),
          // Stage by device: every cell says at a glance whether the stage
          // runs there, could, needs a package first, or cannot at all.
          for (final stage in stages)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 104,
                    child: Text(
                      computeStageName(l10n, stage),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  for (final backend in ComputeBackend.values) ...[
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: _cell(l10n, stage, backend, downloads, settings, pipeline),
                      ),
                    ),
                    if (backend != ComputeBackend.values.last) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          if (runtimes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l10n.computeRuntimesTitle,
              style: const TextStyle(
                fontFamily: LoreDubFonts.mono,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: LoreDubPalette.mutedInk,
              ),
            ),
            const SizedBox(height: 10),
            ModelTileGrid(
              children: [
                for (final runtime in runtimes)
                  RuntimeTile(
                    key: ValueKey('runtimeTile-${runtime.package.id}'),
                    state: runtime,
                    inUse: _inUse(runtime.package.id, stages, settings, pipeline, availability),
                    running: running,
                    stopping: downloads.isStopping(runtime.package.id),
                    onInstall: () => cubits.downloads.installRuntime(runtime),
                    onPause: () => cubits.downloads.pauseDownload(runtime.package.id),
                    onCancel: () => cubits.downloads.cancelDownload(runtime.package.id),
                    onRemove: () => cubits.downloads.removeRuntime(runtime),
                  ),
              ],
            ),
            // A failed install puts the tile back as it was, so without the
            // reason spelled out the press looked like it had done nothing.
            for (final runtime in runtimes)
              if (runtime.error case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SelectableText(
                    '${runtimeName(l10n, runtime.package.id)}: ${describeFailure(l10n, error)}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                  ),
                ),
          ],
          const SizedBox(height: 12),
          Text(
            l10n.computeSpeechCpuOnly,
            style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _cell(
    AppLocalizations l10n,
    ComputeStage stage,
    ComputeBackend backend,
    DownloadsState downloads,
    AppSettings settings,
    LivePipelineState pipeline,
  ) {
    final key = ValueKey('backendCell-${stage.name}-${backend.name}');
    final label = computeBackendName(l10n, backend);
    final running = pipeline.running;
    if (!stageBackends(stage).contains(backend)) {
      return BackendCell(
        key: key,
        label: label,
        state: BackendCellState.unsupported,
        tooltip: l10n.computeBackendUnsupported,
      );
    }
    if (!downloads.availability.supportsHardware(backend)) {
      return BackendCell(
        key: key,
        label: label,
        state: BackendCellState.noHardware,
        tooltip: l10n.computeBackendNoHardware,
      );
    }
    if (downloads.missingRuntimeFor(stage, backend) case final missing?) {
      final size = formatPackageSize(missing.package.approximateBytes);
      if (missing.progress case final progress?) {
        return BackendCell(
          key: key,
          label: label,
          state: BackendCellState.downloading,
          progress: progress,
          detail: missing.paused ? l10n.downloadPaused : '${(progress * 100).round()}%',
          tooltip: l10n.computeRuntimeDownloading(size),
        );
      }
      return BackendCell(
        key: key,
        label: label,
        state: BackendCellState.needsRuntime,
        detail: size,
        tooltip: '${l10n.computeRuntimeMissing(size)}\n${l10n.computeCellHintDownload}',
        onTap: running ? null : () => cubits.downloads.installRuntime(missing),
      );
    }
    // While dubbing runs this is what the stage really settled on.
    final selected = pipeline.backendFor(stage, settings, downloads.availability) == backend;
    return BackendCell(
      key: key,
      label: label,
      state: selected ? BackendCellState.selected : BackendCellState.ready,
      tooltip: selected
          ? l10n.computeCellSelected
          : running
          ? l10n.computeCellLocked
          : l10n.computeCellSelect,
      onTap: selected || running ? null : () => cubits.settings.selectStageBackend(stage, backend),
    );
  }

  /// Whether any stage could put a runtime to use on this machine.
  static bool _servesHardware(String id, ComputeAvailability availability) {
    for (final stage in ComputeStage.values) {
      for (final backend in stageBackends(stage)) {
        if (requiredRuntimeId(stage, backend) == id && availability.supportsHardware(backend)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Whether a stage on the card runs on this runtime right now.
  static bool _inUse(
    String id,
    List<ComputeStage> stages,
    AppSettings settings,
    LivePipelineState pipeline,
    ComputeAvailability availability,
  ) => stages.any(
    (stage) => requiredRuntimeId(stage, pipeline.backendFor(stage, settings, availability)) == id,
  );
}

/// An action and the field that binds its combination.
class _HotkeyRow extends StatelessWidget {
  const _HotkeyRow({required this.label, required this.field});

  final String label;
  final Widget field;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 160,
        child: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      Expanded(child: field),
    ],
  );
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          if (subtitle case final value?) ...[
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(color: LoreDubPalette.mutedInk),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(28, 0, 28, 4),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.55)),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

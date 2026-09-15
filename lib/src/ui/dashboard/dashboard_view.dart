// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/services/model_catalog.dart';
import '../../domain/app_release.dart';
import '../../domain/app_settings.dart';
import '../../domain/character.dart';
import '../../domain/compute_device.dart';
import '../../domain/model_package.dart';
import '../../domain/model_proxy.dart';
import '../../domain/model_selection.dart';
import '../../domain/ocr_region.dart';
import '../../domain/pipeline_graph.dart';
import '../../domain/runtime_paths.dart';
import '../../domain/pipeline_state.dart';
import '../../domain/spoken_language.dart';
import '../../domain/start_requirements.dart';
import '../../../l10n/app_localizations.dart';
import '../app_icons.dart';
import '../compute_names.dart';
import '../failure_messages.dart';
import '../language_names.dart';
import '../model_names.dart';
import '../speaker_names.dart';
import '../theme.dart';
import 'cubits/characters_cubit.dart';
import 'cubits/dashboard_cubits.dart';
import 'cubits/downloads_cubit.dart';
import 'cubits/pipeline_cubit.dart';
import 'cubits/pipeline_graph_bloc.dart';
import 'cubits/settings_cubit.dart';
import 'cubits/shell_cubit.dart';
import 'character_tiles.dart';
import 'compute_matrix.dart';
import 'hotkey_field.dart';
import 'model_tiles.dart';
import 'model_visuals.dart';
import 'ocr_region_picker.dart';
import 'process_picker.dart';
import 'pipeline_canvas.dart';
import 'pipeline_inspector.dart';
import 'pipeline_shelf.dart';
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
    this.watch,
  });

  final DashboardCubits cubits;
  final Widget Function(BuildContext context, DownloadsState downloads) builder;

  /// Set by the parts that care whether a package is there, not how far its
  /// download has got: it holds them still through the hundred ticks of one.
  final bool onlyWhatIsInstalled;

  /// A narrower reading still, for a part that draws something else as well
  /// — which GPU runtimes are on disk, say. Compared as a value.
  final Object? Function(DownloadsState downloads)? watch;

  @override
  Widget build(BuildContext context) => BlocBuilder<DownloadsCubit, DownloadsState>(
    bloc: cubits.downloads,
    buildWhen: switch ((watch, onlyWhatIsInstalled)) {
      (final watch?, _) => (previous, current) => watch(previous) != watch(current),
      (_, true) => (previous, current) => !setEquals(
        previous.installedModelIds,
        current.installedModelIds,
      ),
      _ => null,
    },
    builder: builder,
  );
}

/// Rebuilds with the player's cast and the session that records a voice.
class _CharactersBuilder extends StatelessWidget {
  const _CharactersBuilder({required this.cubits, required this.builder, this.watch});

  final DashboardCubits cubits;
  final Widget Function(BuildContext context, CharactersState characters) builder;

  /// The part of the screen this widget draws; a recording ticking must not
  /// redraw every card.
  final Object? Function(CharactersState characters)? watch;

  @override
  Widget build(BuildContext context) => BlocBuilder<CharactersCubit, CharactersState>(
    bloc: cubits.characters,
    buildWhen: watch == null ? null : (previous, current) => watch!(previous) != watch!(current),
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
                      DashboardSection.pipeline => _PipelinePanel(
                        key: const ValueKey('pipeline'),
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
                      DashboardSection.characters => _CharactersPanel(
                        key: const ValueKey('characters'),
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
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
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
        // The list scrolls rather than pushing the version off the foot of
        // the panel: six entries under two headings are taller than a short
        // window, and taller still under a raised interface scale.
        Expanded(
          child: _ShellBuilder(
            cubits: cubits,
            builder: (context, shell) => SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NavigationGroup(label: AppLocalizations.of(context).navGroupDubbing),
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
                  _NavigationGroup(label: AppLocalizations.of(context).navGroupSetup),
                  _NavigationItem(
                    icon: (color) => Icon(Icons.groups_rounded, size: 21, color: color),
                    label: AppLocalizations.of(context).navCharacters,
                    selected: shell.section == DashboardSection.characters,
                    onTap: () => cubits.shell.selectSection(DashboardSection.characters),
                  ),
                  _NavigationItem(
                    icon: (color) => Icon(Icons.account_tree_rounded, size: 21, color: color),
                    label: AppLocalizations.of(context).navPipeline,
                    selected: shell.section == DashboardSection.pipeline,
                    onTap: () => cubits.shell.selectSection(DashboardSection.pipeline),
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
          ),
        ),
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

/// What the screens under it are for. The six sections are two jobs -- the
/// dubbing itself, and everything that has to be ready before it -- and a
/// flat list of six made "Схема" look like as ordinary a way in as "Эфир".
///
/// It names the group and nothing else: the compact navigation indexes into
/// `DashboardSection.values` and has no room for a heading, so the grouping
/// is the wide window's alone.
class _NavigationGroup extends StatelessWidget {
  const _NavigationGroup({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 24, 8, 8),
    child: Text(
      label,
      style: const TextStyle(
        fontFamily: LoreDubFonts.mono,
        color: LoreDubPalette.mutedInk,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    ),
  );
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
          icon: const Icon(Icons.groups_rounded),
          label: AppLocalizations.of(context).navCharacters,
        ),
        NavigationDestination(
          icon: const Icon(Icons.account_tree_rounded),
          label: AppLocalizations.of(context).navPipeline,
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
                  // The marking over the title reads in the player's own
                  // language: it is a strap rather than a brand, and half
                  // the screens already named their areas in Russian.
                  switch (shell.section) {
                    DashboardSection.live => '01  /  ${AppLocalizations.of(context).headerLive}',
                    DashboardSection.snapshot =>
                      '02  /  ${AppLocalizations.of(context).headerScreen}',
                    DashboardSection.characters =>
                      '03  /  ${AppLocalizations.of(context).headerCharacters}',
                    DashboardSection.pipeline =>
                      '04  /  ${AppLocalizations.of(context).headerPipeline}',
                    DashboardSection.models =>
                      '05  /  ${AppLocalizations.of(context).headerModels}',
                    DashboardSection.settings =>
                      '06  /  ${AppLocalizations.of(context).headerSettings}',
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
                    DashboardSection.pipeline => AppLocalizations.of(context).titlePipeline,
                    DashboardSection.snapshot => AppLocalizations.of(context).titleSnapshot,
                    DashboardSection.models => AppLocalizations.of(context).titleModels,
                    DashboardSection.characters => AppLocalizations.of(context).titleCharacters,
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
            snapshot: pipeline.session == PipelineSession.screen,
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
  Widget build(BuildContext context) => LayoutBuilder(
    // The transcript takes what the cards above it leave, and in a short
    // window -- a compact layout with its navigation along the foot, a
    // checklist still to be worked through -- that was less than the card
    // needs for its own header. Under the floor the screen scrolls instead.
    builder: (context, constraints) => constraints.maxHeight >= _liveMinHeight
        ? _content(context)
        : SingleChildScrollView(
            child: SizedBox(height: _liveMinHeight, child: _content(context)),
          ),
  );

  Widget _content(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
    child: Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ModuleLabel(number: '01', label: AppLocalizations.of(context).areaGameInput),
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
        _StartChecklist(cubits: cubits),
        const SizedBox(height: 16),
        // The transcript and the voices of the scene stand side by side
        // where there is room; a narrow window stacks them, the transcript
        // keeping whatever height is left.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth >= _sceneBesideTranscriptWidth
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _TranscriptCard(cubits: cubits)),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: _sceneVoicesWidth,
                        child: _SceneVoicesCard(cubits: cubits),
                      ),
                    ],
                  )
                // Shares of what is left rather than a fixed height. Under a
                // card's worth of room the transcript takes it all: two
                // headers and nothing under them would serve nobody.
                : constraints.maxHeight < _sceneStackedMinHeight
                ? _TranscriptCard(cubits: cubits)
                : Column(
                    children: [
                      Expanded(flex: 3, child: _TranscriptCard(cubits: cubits)),
                      const SizedBox(height: 16),
                      Expanded(flex: 2, child: _SceneVoicesCard(cubits: cubits)),
                    ],
                  ),
          ),
        ),
      ],
    ),
  );
}

/// What the live screen keeps for itself before it starts scrolling: the two
/// cards at their tallest, and a transcript still worth looking at under
/// them.
const _liveMinHeight = 640.0;

/// Beyond this two setting cards stand side by side rather than one under
/// the other. Below it a slider and its own notes would be squeezed.
const _pairedCardsWidth = 900.0;

/// Beyond this the scene voices sit beside the transcript rather than under
/// it; below it the transcript would be left too narrow to read.
const _sceneBesideTranscriptWidth = 1000.0;
const _sceneVoicesWidth = 340.0;

/// Under this the stacked layout shows the transcript alone.
const _sceneStackedMinHeight = 360.0;

/// What the running session heard, newest first.
class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({
    required this.cubits,
    this.number = '02',
    this.label,
    this.fromScreen = false,
  });

  final DashboardCubits cubits;

  /// Which area of its screen this is, and what it is called there. Live
  /// dubbing lists what it heard second; the screen session lists what the
  /// frame gained third, after the controls and the frame itself.
  final String number;

  /// Null on Live, where it is the transcript of what was heard.
  final String? label;

  /// Whether the lines came off the screen rather than out of the game's
  /// sound, which is all the empty state needs to name the right route.
  final bool fromScreen;

  @override
  Widget build(BuildContext context) => _PipelineBuilder(
    cubits: cubits,
    watch: (pipeline) => pipeline.transcript,
    builder: (context, pipeline) => _CharactersBuilder(
      cubits: cubits,
      watch: (characters) => characters.characters,
      builder: (context, characters) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              // Tighter than a bare label row would need: the button has
              // to fit without making the header taller than it was.
              padding: const EdgeInsets.fromLTRB(20, 9, 12, 8),
              child: Row(
                children: [
                  _ModuleLabel(
                    number: number,
                    label: label ?? AppLocalizations.of(context).areaTranscript,
                  ),
                  const Spacer(),
                  _ClearListButton(
                    tooltip: AppLocalizations.of(context).transcriptClearTooltip,
                    onPressed: pipeline.transcript.isEmpty ? null : cubits.pipeline.clearTranscript,
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
                        fromScreen: fromScreen,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      itemCount: pipeline.transcript.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) => _TranscriptBubble(
                        entry: pipeline.transcript[index],
                        characters: characters.characters,
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Who the session has heard, and whose voice reads them.
///
/// A voice of the game and a card recognized in it are both here. The area
/// shows and does not set: who reads whom is drawn on the graph.
class _SceneVoicesCard extends StatelessWidget {
  const _SceneVoicesCard({required this.cubits});

  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) => _ShellBuilder(
    cubits: cubits,
    builder: (context, shell) => _PipelineBuilder(
      cubits: cubits,
      watch: (pipeline) => (pipeline.speakers, pipeline.status, pipeline.session),
      builder: (context, pipeline) => _CharactersBuilder(
        cubits: cubits,
        watch: (characters) => characters.characters,
        builder: (context, cast) =>
            _build(context, pipeline, cast.characters, initializing: shell.initializing),
      ),
    ),
  );

  Widget _build(
    BuildContext context,
    LivePipelineState pipeline,
    List<Character> characters, {
    required bool initializing,
  }) {
    final l10n = AppLocalizations.of(context);
    final listening = pipeline.sceneRunning;
    // Placing the voices needs the converter and a bank to keep them in;
    // while dubbing or a selection holds the worker, it cannot run at all.
    final canListen =
        listening ||
        cubits.pipeline.state.canStartScene(cubits.selection, initializing: initializing);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 9, 12, 8),
            child: _ModuleLabel(
              number: '03',
              label: AppLocalizations.of(context).areaSceneVoices,
            ),
          ),
          const Divider(height: 1),
          // On its own line rather than beside the label: this column is
          // narrow, and the two would not fit across it.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('sceneListen'),
                onPressed: canListen
                    ? () => cubits.pipeline.toggleSceneVoices(initializing: initializing)
                    : null,
                icon: Icon(listening ? Icons.stop_rounded : Icons.hearing_rounded, size: 18),
                label: Text(listening ? l10n.sceneVoicesListenStop : l10n.sceneVoicesListen),
                style: TextButton.styleFrom(
                  foregroundColor: listening ? LoreDubPalette.orange : LoreDubPalette.ink,
                ),
              ),
            ),
          ),
          Expanded(
            child: pipeline.speakers.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Text(
                      !cubits.selection.tracksSpeakers
                          ? l10n.sceneVoicesNeedsConverter
                          : listening
                          ? l10n.sceneVoicesListening
                          : l10n.sceneVoicesEmpty,
                      style: TextStyle(
                        fontSize: 12,
                        color: listening ? LoreDubPalette.orange : LoreDubPalette.mutedInk,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                    children: [
                      Text(
                        characters.isEmpty
                            ? l10n.sceneVoiceNoCharacters
                            : '${l10n.sceneVoicesNote} ${l10n.voicesOnTheGraph}',
                        style: const TextStyle(fontSize: 12, color: LoreDubPalette.mutedInk),
                      ),
                      const SizedBox(height: 6),
                      for (final speaker in pipeline.speakers)
                        SceneVoiceRow(
                          speaker: speaker,
                          name: speakerName(l10n, speaker.key, characters),
                          readsAs: replacementName(speaker.key, characters),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
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

/// What still stands between the player and the first press of Start.
///
/// The three reasons `canStart` refuses for used to be told separately --
/// one notice for the packages, another for a route taken apart, and
/// nothing at all for a game not yet chosen, which left the button dead
/// with no word about what it waited on. They are one card now, numbered in
/// the order they are met, and it is gone the moment nothing is left in it.
class _StartChecklist extends StatelessWidget {
  const _StartChecklist({required this.cubits});

  final DashboardCubits cubits;

  // Whether a package is there rather than how far its download has got:
  // the card must not redraw through the hundred ticks of one.
  @override
  Widget build(BuildContext context) => _DownloadsBuilder(
    onlyWhatIsInstalled: true,
    cubits: cubits,
    builder: (context, _) => _SettingsBuilder(
      cubits: cubits,
      builder: (context, _) => _PipelineBuilder(
        cubits: cubits,
        watch: (pipeline) => pipeline.selectedProcess,
        builder: (context, pipeline) => _build(
          context,
          stepsBeforeStart(cubits.selection, gameChosen: pipeline.selectedProcess != null),
        ),
      ),
    ),
  );

  Widget _build(BuildContext context, List<StartStep> steps) {
    if (steps.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.checklist_rounded, color: LoreDubPalette.warning, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    l10n.startChecklistTitle,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              for (final (index, step) in steps.indexed)
                _StartStepRow(
                  number: index + 1,
                  title: switch (step) {
                    StartStep.models => l10n.modelsNeededTitle,
                    StartStep.route => l10n.routeNeededTitle,
                    StartStep.game => l10n.startStepGame,
                  },
                  action: switch (step) {
                    StartStep.models => l10n.modelsNeededAction,
                    StartStep.route => l10n.routeNeededAction,
                    StartStep.game => null,
                  },
                  // The picker the game is chosen in stands on this same
                  // screen, a finger's width above, so that step leads
                  // nowhere and only says what is missing.
                  onPressed: switch (step) {
                    StartStep.models => () => cubits.shell.selectSection(DashboardSection.models),
                    StartStep.route => () => cubits.shell.selectSection(DashboardSection.pipeline),
                    StartStep.game => null,
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One line of the checklist: its place in the list, what is missing, and
/// the screen it is put right on.
class _StartStepRow extends StatelessWidget {
  const _StartStepRow({
    required this.number,
    required this.title,
    required this.action,
    required this.onPressed,
  });

  final int number;
  final String title;
  final String? action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      children: [
        SizedBox(
          width: 30,
          child: Text(
            '$number.',
            style: const TextStyle(
              fontFamily: LoreDubFonts.mono,
              color: LoreDubPalette.mutedInk,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        // A step is a line and no more: three of them with a paragraph
        // each left the transcript under the card nothing to stand in.
        Expanded(child: Text(title)),
        if (action case final label?) ...[
          const SizedBox(width: 12),
          TextButton(onPressed: onPressed, child: Text(label)),
        ],
      ],
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
/// The screen the game writes on, read two ways at once.
///
/// The frame is watched while the session runs, so a line the game adds to
/// it is dubbed as it appears; the snapshot key picks out anything else on
/// the screen by hand. One session answers both -- neither needs whisper,
/// and both end in the same translator and voice -- so what the game keeps
/// writing and what the player asks for arrive side by side.
class _SnapshotPanel extends StatelessWidget {
  const _SnapshotPanel({super.key, required this.cubits});

  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // The frame, the controls and two lists need more room than the live
    // screen does. Given less, the screen scrolls and the lists take a
    // height of their own rather than being crushed to their own headers.
    builder: (context, constraints) {
      final stacked = constraints.maxWidth < _frameBesideControlsWidth;
      final floor = stacked ? _screenStackedMinHeight : _screenMinHeight;
      final filling = constraints.maxHeight >= floor;
      final content = _content(context, stacked: stacked, filling: filling);
      return filling ? content : SingleChildScrollView(child: content);
    },
  );

  Widget _content(BuildContext context, {required bool stacked, required bool filling}) {
    final lists = stacked
        ? Column(
            children: [
              Expanded(child: _SubtitleList(cubits: cubits)),
              const SizedBox(height: 16),
              Expanded(child: _SnapshotHistory(cubits: cubits)),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _SubtitleList(cubits: cubits)),
              const SizedBox(width: 16),
              Expanded(child: _SnapshotHistory(cubits: cubits)),
            ],
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      child: Column(
        children: [
          if (stacked)
            Column(
              children: [
                _ScreenCaptureCard(cubits: cubits),
                const SizedBox(height: 16),
                _SubtitleFrameCard(cubits: cubits),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _ScreenCaptureCard(cubits: cubits)),
                const SizedBox(width: 16),
                SizedBox(
                  width: _frameCardWidth,
                  child: _SubtitleFrameCard(cubits: cubits),
                ),
              ],
            ),
          _ModelsNeededNotice(
            cubits: cubits,
            ready: (selection) => selection.screenModelsInstalled,
          ),
          const SizedBox(height: 16),
          if (filling)
            Expanded(child: lists)
          else
            SizedBox(
              height: stacked ? _listHeight * 2 + 16 : _listHeight,
              child: lists,
            ),
        ],
      ),
    );
  }
}

/// What the frame gained as the game wrote in it, in the same card live
/// dubbing lists what it heard in.
class _SubtitleList extends StatelessWidget {
  const _SubtitleList({required this.cubits});

  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) => _TranscriptCard(
    cubits: cubits,
    number: '03',
    label: AppLocalizations.of(context).areaSubtitles,
    fromScreen: true,
  );
}

/// What the screen session keeps for itself before it starts scrolling: the
/// controls beside the frame, and a list under them worth looking at.
const _screenMinHeight = 980.0;

/// The same, with the frame under the controls rather than beside them.
const _screenStackedMinHeight = 1320.0;

/// How tall one of the two lists is made when the screen scrolls instead of
/// filling the window.
const _listHeight = 320.0;

/// Beyond this the subtitle frame stands beside the controls rather than
/// under them.
const _frameBesideControlsWidth = 860.0;
const _frameCardWidth = 380.0;

/// The game to read, the language on its screen, and the session's button.
class _ScreenCaptureCard extends StatelessWidget {
  const _ScreenCaptureCard({required this.cubits});

  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ModuleLabel(number: '01', label: AppLocalizations.of(context).areaScreenCapture),
          const SizedBox(height: 14),
          _SnapshotControls(cubits: cubits),
        ],
      ),
    ),
  );
}

/// The frame the subtitles are read out of, drawn on a picture of the game's
/// window, and whether the game is silenced while they are dubbed.
///
/// It lives here rather than in the settings because this is the only
/// session that reads it: the frame is part of the work this screen does.
class _SubtitleFrameCard extends StatelessWidget {
  const _SubtitleFrameCard({required this.cubits});

  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) => _SettingsBuilder(
    cubits: cubits,
    builder: (context, state) => _PipelineBuilder(
      cubits: cubits,
      watch: (pipeline) => pipeline.running,
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
            _ModuleLabel(number: '02', label: l10n.areaSubtitleFrame),
            const SizedBox(height: 14),
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
                      : () => cubits.settings.update(
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
              Text(
                l10n.frameHowTo(key.display),
                style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Switch(
                  value: settings.silenceWhileReading,
                  onChanged: running
                      ? null
                      : (value) =>
                            cubits.settings.update(settings.copyWith(silenceWhileReading: value)),
                ),
                const SizedBox(width: 6),
                Flexible(child: Text(l10n.silenceWhileReading)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.silenceWhileReadingNote,
              style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
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
        pipeline.frameMissed,
        pipeline.selectedProcess,
        pipeline.processes,
      ),
      builder: (context, pipeline) => _build(context, state.settings, pipeline),
    ),
  );

  Widget _build(BuildContext context, AppSettings settings, LivePipelineState pipeline) {
    final l10n = AppLocalizations.of(context);
    final hotkey = settings.snapshotHotkey;
    final status = _status(l10n, pipeline, settings);
    final button = _SnapshotStartButton(cubits: cubits);
    // The frame is read out of one window, so this session needs the game
    // named even though nothing of its sound is listened to.
    final picker = ProcessPicker(
      processes: pipeline.processes,
      selected: pipeline.selectedProcess,
      // Nothing is read out of that window while the whole screen is what
      // is read, so there is nothing to choose.
      enabled: !pipeline.running && !settings.readsWholeScreen,
      onSelected: cubits.pipeline.selectProcess,
      onRefresh: cubits.pipeline.refreshProcesses,
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
                : (selection) =>
                      cubits.settings.update(settings.copyWith(screenSource: selection.first)),
          ),
        ),
        const SizedBox(height: 14),
        game,
        const SizedBox(height: 14),
        _TextLanguagePicker(cubits: cubits),
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
      builder: (context, constraints) => constraints.maxWidth < 760
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
                  SizedBox(width: _LanguageRow.actionWidth, child: button),
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
    final own = pipeline.session == PipelineSession.screen;
    final starting = own && pipeline.status == PipelineStatus.starting;
    final running = own && pipeline.running;
    final progress = pipeline.startupProgress;
    final canStart = pipeline.canStartScreen(cubits.selection, initializing: initializing);
    return Tooltip(
      message: starting && pipeline.startupStage.isNotEmpty
          ? describeStartupStage(l10n, pipeline.startupStage)
          : '',
      child: FilledButton.icon(
        key: const ValueKey('snapshotStart'),
        onPressed: running || canStart
            ? () => cubits.pipeline.toggleScreenText(initializing: initializing)
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
                _ModuleLabel(
                  number: '04',
                  label: AppLocalizations.of(context).areaSelectedText,
                ),
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
      // Only whether a card is being recorded: the seconds it has heard tick
      // as it goes, and this screen must not be redrawn for them.
      builder: (context, pipeline) => _CharactersBuilder(
        cubits: cubits,
        watch: (characters) => characters.running,
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
      onSelected: cubits.pipeline.selectProcess,
      onRefresh: cubits.pipeline.refreshProcesses,
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
          : (selection) =>
                cubits.settings.update(settings.copyWith(audioCaptureSource: selection.first)),
    );
    // The picker carries its own refresh button, so it travels whole into
    // the compact layout instead of leaving it on the row with the start
    // button.
    final picker = selector;
    final language = _LanguageControls(cubits: cubits);
    final target = _TargetLanguagePicker(cubits: cubits);
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
                if (value != null) {
                  cubits.settings.update(settings.copyWith(screenLanguage: value));
                }
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

  /// What the two of them need side by side.
  static const double _sideBySide = fieldWidth + 12 + actionWidth;

  final Widget field;
  final Widget action;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // Both halves were fixed and the row refused to shrink, so a card
    // narrower than the two of them -- the screen page's controls beside
    // the subtitle frame -- was overflowed by whatever was missing. Given
    // less than they need, they go one under the other and take the width
    // there is.
    builder: (context, constraints) =>
        !constraints.hasBoundedWidth || constraints.maxWidth >= _sideBySide
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: fieldWidth, child: field),
              const SizedBox(width: 12),
              SizedBox(width: actionWidth, child: action),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [field, const SizedBox(height: 10), action],
          ),
  );
}

class _ModuleLabel extends StatelessWidget {
  const _ModuleLabel({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    // As wide as the number and the name, and no wider: given room to
    // spread — a heading that wraps — a row of its full width would leave
    // nothing to sit beside it.
    mainAxisSize: MainAxisSize.min,
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
  const _TranscriptBubble({required this.entry, this.characters = const []});

  static const double _tailInset = 28;
  static const Size _tailSize = Size(26, 14);

  final TranscriptEntry entry;

  /// The cast, so a line matched to a card is named rather than numbered,
  /// and so a line read by another card can say whose voice it was.
  final List<Character> characters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final original = entry.original.isEmpty ? entry.english : entry.original;
    final speaker = entry.speaker;
    final readAs = speaker == null ? null : replacementName(speaker, characters);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (speaker != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 5),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    speakerName(l10n, speaker, characters),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: LoreDubFonts.mono,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: LoreDubPalette.mutedInk,
                    ),
                  ),
                ),
                if (readAs != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l10n.sceneVoiceReplaced(readAs),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: LoreDubFonts.mono,
                        fontSize: 11,
                        color: LoreDubPalette.orange,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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
  const _EmptyTranscript({required this.targetLanguage, required this.fromScreen});

  /// The pipeline ends in whichever language is selected, so the hint says so
  /// rather than always naming Russian.
  final String targetLanguage;

  /// Whether this is the screen session's list rather than live dubbing's:
  /// the same card, fed by Windows OCR instead of whisper.
  final bool fromScreen;

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
                (fromScreen
                    ? AppLocalizations.of(context).pipelineSummaryOcr
                    : AppLocalizations.of(context).pipelineSummary)(
                  spokenLanguageName(AppLocalizations.of(context), targetLanguage),
                ),
                style: const TextStyle(color: LoreDubPalette.mutedInk),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The characters screen: the player's cast, and the session their voices
/// are recorded through.
/// The pipeline as a scheme: the stages as nodes, the route between them,
/// and the cards of the cast that take a voice from one another.
///
/// Nothing is configured here that is not configured elsewhere. The canvas
/// is drawn from the settings and the cast, and every link the player draws
/// is turned straight back into one of them, so the scheme and the screens
/// can never say different things.
class _PipelinePanel extends StatelessWidget {
  const _PipelinePanel({super.key, required this.cubits});

  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
    child: BlocBuilder<PipelineGraphBloc, PipelineGraphState>(
      bloc: cubits.graph,
      builder: (context, graph) => _SettingsBuilder(
        cubits: cubits,
        builder: (context, settings) => _DownloadsBuilder(
          cubits: cubits,
          // What is on disk and what the machine can run it on. A download
          // ticking must not redraw the scheme.
          watch: (downloads) =>
              '${downloads.installedModelIds.join()}'
              '|${downloads.availability.installedRuntimes.join()}',
          builder: (context, downloads) => _PipelineBuilder(
            cubits: cubits,
            watch: (pipeline) => (
              pipeline.running,
              pipeline.status,
              pipeline.selectedProcess,
              pipeline.processes,
              pipeline.backendSignature,
            ),
            builder: (context, pipeline) => _CharactersBuilder(
              cubits: cubits,
              watch: (characters) => (characters.characters, characters.running),
              builder: (context, characters) => _build(
                context,
                graph: graph,
                availability: downloads.availability,
                facts: PipelineFacts(
                  settings: settings.settings,
                  selection: ModelSelection(
                    models: downloads.models,
                    settings: settings.settings,
                  ),
                  process: pipeline.selectedProcess,
                  characters: characters.characters,
                  activeBackends: pipeline.activeBackends,
                  running: pipeline.running,
                  paused: pipeline.status == PipelineStatus.paused,
                  recordingVoice: characters.running,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _build(
    BuildContext context, {
    required PipelineGraphState graph,
    required PipelineFacts facts,
    required ComputeAvailability availability,
  }) {
    final selected = graph.selectedNode;
    return Column(
      children: [
        _GraphToolbar(cubits: cubits, state: graph, facts: facts),
        const SizedBox(height: 12),
        // The panel floats over the canvas rather than beside it: opening it
        // must not move the scheme out from under the pointer that opened it.
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: PipelineCanvas(
                    bloc: cubits.graph,
                    state: graph,
                    facts: facts,
                    availability: availability,
                  ),
                ),
              ),
              if (selected != null)
                Positioned(
                  top: 12,
                  right: 12,
                  bottom: 12,
                  child: PipelineInspector(
                    cubits: cubits,
                    node: selected,
                    facts: facts,
                    availability: availability,
                    chained: graph.graph.chained,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The presets, the steps back, and the cards waiting to be put on the
/// canvas. Under them, whatever the last attempt at a link came to.
class _GraphToolbar extends StatelessWidget {
  const _GraphToolbar({required this.cubits, required this.state, required this.facts});

  final DashboardCubits cubits;
  final PipelineGraphState state;
  final PipelineFacts facts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // How the canvas is worked, on the row the buttons that work
                // it are on: the two chips that used to stand here picked
                // between the audio route and the subtitles, and the screen
                // is read on its own page now. Whatever the last attempt at
                // a link came to takes the same place, so a refusal is read
                // where the hand already is.
                Expanded(
                  child: switch (state.refusal) {
                    final refusal? => Text(
                      describeConnectionRefusal(l10n, refusal),
                      style: const TextStyle(fontSize: 12, color: LoreDubPalette.error),
                    ),
                    _ => Text(
                      l10n.pipelineGraphHint,
                      style: const TextStyle(fontSize: 12, color: LoreDubPalette.mutedInk),
                    ),
                  },
                ),
                const SizedBox(width: 12),
                _addCharacter(context, l10n),
                // The session is rested from here as well as from Live: the
                // cast is rewired on this screen, and walking to another one
                // to stop the dubbing first is a walk for nothing.
                if (facts.running) ...[
                  IconButton(
                    key: const ValueKey('graphPause'),
                    tooltip: facts.paused ? l10n.resumeDubbing : l10n.pauseHint,
                    icon: Icon(
                      facts.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 20,
                      color: facts.paused ? LoreDubPalette.orange : null,
                    ),
                    onPressed: facts.paused ? cubits.pipeline.resume : cubits.pipeline.pause,
                  ),
                  IconButton(
                    key: const ValueKey('graphStop'),
                    tooltip: l10n.stopDubbing,
                    icon: const Icon(Icons.stop_rounded, size: 20),
                    onPressed: cubits.pipeline.stop,
                  ),
                ],
                IconButton(
                  tooltip: l10n.pipelineSaveScheme,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 20),
                  onPressed: () => _saveScheme(context, l10n),
                ),
                IconButton(
                  tooltip: l10n.pipelineSchemeImport,
                  icon: const Icon(Icons.file_open_outlined, size: 20),
                  onPressed: () => _importScheme(l10n),
                ),
                IconButton(
                  tooltip: l10n.pipelineResetLayout,
                  icon: const Icon(Icons.grid_view_rounded, size: 20),
                  onPressed: () => cubits.graph.add(const PipelineLayoutReset()),
                ),
                IconButton(
                  tooltip: l10n.pipelineUndo,
                  icon: const Icon(Icons.undo_rounded, size: 20),
                  onPressed: state.canUndo
                      ? () => cubits.graph.add(const PipelineGraphUndone())
                      : null,
                ),
                IconButton(
                  tooltip: l10n.pipelineRedo,
                  icon: const Icon(Icons.redo_rounded, size: 20),
                  onPressed: state.canRedo
                      ? () => cubits.graph.add(const PipelineGraphRedone())
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            // The shelf of kept schemes, each with a picture of itself: a
            // click puts it on the canvas and it is the one that runs. It is
            // folded away until asked for — the canvas is what the screen is
            // for, and a shelf of pictures would take the top of it every
            // time the screen is opened.
            PipelineShelf(
              schemes: state.schemes,
              cast: facts.characters,
              onChoose: (id) => cubits.graph.add(PipelineSchemeChosen(id)),
              onRename: (id, name) => cubits.graph.add(PipelineSchemeRenamed(id, name)),
              onRemove: (id) => cubits.graph.add(PipelineSchemeRemoved(id)),
              onExport: (id) => _exportScheme(id, l10n),
            ),
          ],
        ),
      ),
    );
  }

  /// Keeps the scheme as it stands, under a name the player types.
  Future<void> _saveScheme(BuildContext context, AppLocalizations l10n) async {
    final name = await askForName(
      context,
      title: l10n.pipelineSchemeName,
      action: l10n.pipelineSaveScheme,
      initial: l10n.pipelineSchemeNew,
    );
    if (name != null) cubits.graph.add(PipelineSchemeSaved(name));
  }

  Future<void> _exportScheme(String id, AppLocalizations l10n) async {
    final scheme = state.schemes.where((value) => value.id == id).firstOrNull;
    if (scheme == null) return;
    final destination = await getSaveLocation(
      suggestedName: '${scheme.name}.loredub-scheme.json',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'LoreDub', extensions: ['json']),
      ],
    );
    if (destination == null) return;
    cubits.graph.add(PipelineSchemeExported(id, destination.path));
  }

  Future<void> _importScheme(AppLocalizations l10n) async {
    final files = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'LoreDub', extensions: ['json']),
      ],
    );
    if (files.isEmpty) return;
    cubits.graph.add(PipelineSchemeImported([for (final file in files) file.path]));
  }

  /// Every card of the cast, drawn or not: a card already on the canvas can
  /// be drawn again beside the character whose part it takes over, and the
  /// count beside its name says how many of it are there.
  Widget _addCharacter(BuildContext context, AppLocalizations l10n) {
    final drawn = <String, int>{};
    for (final node in state.graph.ofKind(PipelineNodeKind.character)) {
      drawn.update(node.characterId ?? '', (count) => count + 1, ifAbsent: () => 1);
    }
    return PopupMenuButton<String>(
      tooltip: facts.characters.isEmpty ? l10n.pipelineNoCharacters : l10n.pipelineAddCharacter,
      enabled: facts.characters.isNotEmpty,
      icon: const Icon(Icons.person_add_alt_rounded, size: 20),
      onSelected: (id) => cubits.graph.add(PipelineCharacterPlaced(id)),
      itemBuilder: (context) => [
        for (final character in facts.characters)
          PopupMenuItem(
            value: character.id,
            child: Row(
              children: [
                Expanded(child: Text(character.name)),
                if (drawn[character.id] case final count?)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      '×$count',
                      style: const TextStyle(
                        fontFamily: LoreDubFonts.mono,
                        fontSize: 11,
                        color: LoreDubPalette.mutedInk,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CharactersPanel extends StatelessWidget {
  const _CharactersPanel({super.key, required this.cubits});

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
                _ModuleLabel(
                  number: '01',
                  label: AppLocalizations.of(context).areaVoiceRecording,
                ),
                const SizedBox(height: 14),
                _CharacterSessionControls(cubits: cubits),
              ],
            ),
          ),
        ),
        _ModelsNeededNotice(
          cubits: cubits,
          ready: (selection) => selection.voiceConverter?.installed ?? false,
        ),
        const SizedBox(height: 16),
        // The cast on the left, the packs beside it on the right: a card is
        // carried across rather than down a scroll, and both ends of the
        // journey stay in sight the whole way. A window too narrow to hold
        // the two side by side puts the packs back underneath, where a drag
        // is longer but possible.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < _packsBeside
                ? ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _CharacterCast(cubits: cubits),
                      const SizedBox(height: 16),
                      _CharacterPacks(cubits: cubits),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Each side scrolls on its own, so reaching for a pack
                      // does not move the cards under the pointer.
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [_CharacterCast(cubits: cubits)],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: (constraints.maxWidth * 0.36).clamp(340.0, 480.0),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [_CharacterPacks(cubits: cubits)],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    ),
  );
}

/// The head of an area: its number and name on one side, what can be done
/// to it on the other. In a column too narrow to hold both, the buttons
/// drop to a line of their own rather than off the edge.
class _AreaHeading extends StatelessWidget {
  const _AreaHeading({required this.label, required this.actions});

  final Widget label;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    runSpacing: 4,
    children: [
      label,
      Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
    ],
  );
}

/// How much room the characters screen needs before the packs stand beside
/// the cast rather than under it: two columns of cards, and the gap.
const _packsBeside = 880.0;

/// Which game to listen to, and whether the session that measures voices is
/// running. Live dubbing holds the same worker, so the two never run at once.
class _CharacterSessionControls extends StatelessWidget {
  const _CharacterSessionControls({required this.cubits});

  final DashboardCubits cubits;

  @override
  Widget build(BuildContext context) => _ShellBuilder(
    cubits: cubits,
    builder: (context, shell) => _DownloadsBuilder(
      onlyWhatIsInstalled: true,
      cubits: cubits,
      builder: (context, _) => _PipelineBuilder(
        cubits: cubits,
        watch: (pipeline) => (pipeline.processes, pipeline.selectedProcess, pipeline.running),
        builder: (context, pipeline) => _CharactersBuilder(
          cubits: cubits,
          watch: (characters) => (characters.status, characters.recordingId),
          builder: (context, characters) =>
              _build(context, pipeline, characters, initializing: shell.initializing),
        ),
      ),
    ),
  );

  Widget _build(
    BuildContext context,
    LivePipelineState pipeline,
    CharactersState characters, {
    required bool initializing,
  }) {
    final l10n = AppLocalizations.of(context);
    final canRecord = cubits.characters.canRecord;
    final locked = characters.running || pipeline.running;
    final picker = ProcessPicker(
      processes: pipeline.processes,
      selected: pipeline.selectedProcess,
      enabled: !locked,
      onSelected: cubits.pipeline.selectProcess,
      onRefresh: cubits.pipeline.refreshProcesses,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.charactersNote} ${l10n.voicesOnTheGraph}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: picker),
            const SizedBox(width: 16),
            SizedBox(
              width: _LanguageRow.actionWidth,
              child: FilledButton.icon(
                key: const ValueKey('charactersSession'),
                onPressed: !canRecord || initializing || pipeline.running
                    ? null
                    : () => cubits.characters.toggleSession(
                        initializing: initializing,
                        process: pipeline.selectedProcess,
                      ),
                icon: characters.status == PipelineStatus.starting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : Icon(
                        characters.running ? Icons.stop_rounded : Icons.fiber_manual_record_rounded,
                      ),
                label: Text(
                  characters.running ? l10n.charactersSessionStop : l10n.charactersSessionStart,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          !canRecord
              ? l10n.charactersNeedsConverter
              : pipeline.running
              ? l10n.snapshotInLive
              : l10n.charactersHowTo,
          style: TextStyle(
            color: canRecord ? LoreDubPalette.mutedInk : LoreDubPalette.warning,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// The cards themselves, with what it takes to add them and hand them on.
///
/// A card dropped here from a pack leaves that pack: the cast holds every
/// character whether a pack names them or not, so this is where a card goes
/// back to being in none.
class _CharacterCast extends StatelessWidget {
  const _CharacterCast({required this.cubits});

  final DashboardCubits cubits;

  Future<void> _exportAll(BuildContext context, List<Character> characters) async {
    final location = await getSaveLocation(suggestedName: 'loredub-characters.json');
    if (location == null) return;
    await cubits.characters.export(location.path, characters);
  }

  Future<void> _export(BuildContext context, Character character) async {
    final location = await getSaveLocation(
      suggestedName: '${character.name.trim().isEmpty ? 'character' : character.name}.json',
    );
    if (location == null) return;
    await cubits.characters.export(location.path, [character]);
  }

  Future<void> _confirmDelete(BuildContext context, Character character) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(l10n.charactersDeleteTitle),
        content: Text(
          l10n.charactersDeleteMessage(character.name),
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.charactersDeleteCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.charactersDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubits.characters.remove(character.id);
  }

  @override
  Widget build(BuildContext context) => _CharactersBuilder(
    cubits: cubits,
    builder: (context, state) {
      final l10n = AppLocalizations.of(context);
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 9, 12, 8),
              child: _AreaHeading(
                label: _ModuleLabel(number: '02', label: l10n.areaCast),
                actions: [
                  TextButton.icon(
                    onPressed: state.characters.isEmpty
                        ? null
                        : () => _exportAll(context, state.characters),
                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                    label: Text(l10n.charactersExportAll),
                    style: TextButton.styleFrom(foregroundColor: LoreDubPalette.mutedInk),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('charactersAdd'),
                    onPressed: () => cubits.characters.add(l10n.charactersNewName),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(l10n.charactersAdd),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            DragTarget<CharacterDrag>(
              // Only a card that came out of a pack has anywhere to land
              // here; one dragged from the cast is already where it is.
              onWillAcceptWithDetails: (details) => details.data.fromPackId != null,
              onAcceptWithDetails: (details) => cubits.characters.removeFromPack(
                details.data.fromPackId!,
                details.data.character.id,
              ),
              builder: (context, candidate, _) => ColoredBox(
                color: candidate.isEmpty
                    ? Colors.transparent
                    : LoreDubPalette.orange.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                  child: state.characters.isEmpty
                      ? _EmptyCast(loading: state.loading)
                      : CharacterTileGrid(
                          children: [
                            for (final character in state.characters)
                              CharacterTile(
                                key: ValueKey(character.id),
                                character: character,
                                recording: state.recordingId == character.id,
                                heardSeconds: state.heardSeconds,
                                packNames: [
                                  for (final pack in state.packs)
                                    if (pack.holds(character.id)) pack.name,
                                ],
                                cast: [
                                  for (final other in state.characters)
                                    if (other.id != character.id) other,
                                ],
                                onRename: (name) => cubits.characters.rename(character.id, name),
                                playing: state.playingId == character.id,
                                onPlay: !state.canPlay(character.id) || state.sounding
                                    ? null
                                    : () => cubits.characters.playClip(character.id),
                                previewing: state.previewingId == character.id,
                                onStopSound: cubits.characters.stopSounding,
                                carriesTimbre: cubits.characters.carriesTimbre,
                                onPreview:
                                    state.sounding || state.running || !cubits.characters.canPreview
                                    ? null
                                    : () => cubits.characters.preview(character.id),
                                onRecord:
                                    !state.running ||
                                        (state.recording && state.recordingId != character.id)
                                    ? null
                                    : () => state.recordingId == character.id
                                          ? cubits.characters.stopRecording()
                                          : cubits.characters.startRecording(character.id),
                                building: state.buildingId == character.id,
                                built: state.builtId == character.id ? state.built : null,
                                onFilesDropped:
                                    state.building ||
                                        state.recording ||
                                        !cubits.characters.canRecord
                                    ? null
                                    : (paths) =>
                                          cubits.characters.voiceFromFiles(character.id, paths),
                                onExport: character.vector.isEmpty
                                    ? null
                                    : () => _export(context, character),
                                onDelete: () => _confirmDelete(context, character),
                              ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// The packs: named areas cards are dropped into, handed on and thrown away
/// as a group. Throwing one away leaves the cards in the cast — the player
/// recorded them, and only the grouping was ever the pack's.
class _CharacterPacks extends StatelessWidget {
  const _CharacterPacks({required this.cubits});

  final DashboardCubits cubits;

  Future<void> _import(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final chosen = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'LoreDub', extensions: ['json']),
      ],
    );
    if (chosen.isEmpty) return;
    final added = await cubits.characters.import([for (final file in chosen) file.path]);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added.packs == 0
              ? l10n.charactersImported(added.characters)
              : l10n.packsImported(added.packs, added.characters),
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context, CharacterPack pack, List<Character> members) async {
    final location = await getSaveLocation(
      suggestedName: '${pack.name.trim().isEmpty ? 'pack' : pack.name}.json',
    );
    if (location == null) return;
    await cubits.characters.export(location.path, members, pack: pack);
  }

  Future<void> _confirmDelete(BuildContext context, CharacterPack pack) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(l10n.packsDeleteTitle),
        content: Text(
          l10n.packsDeleteMessage(pack.name),
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.charactersDeleteCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.charactersDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubits.characters.removePack(pack.id);
  }

  @override
  Widget build(BuildContext context) => _CharactersBuilder(
    cubits: cubits,
    watch: (characters) => (characters.characters, characters.packs, characters.loading),
    builder: (context, state) {
      final l10n = AppLocalizations.of(context);
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 9, 12, 8),
              child: _AreaHeading(
                label: _ModuleLabel(number: '03', label: l10n.areaPacks),
                actions: [
                  TextButton.icon(
                    key: const ValueKey('charactersImport'),
                    onPressed: () => _import(context),
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: Text(l10n.charactersImport),
                    style: TextButton.styleFrom(foregroundColor: LoreDubPalette.mutedInk),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('packsAdd'),
                    onPressed: () => cubits.characters.addPack(l10n.packsNewName),
                    icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                    label: Text(l10n.packsAdd),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
              child: state.packs.isEmpty
                  ? Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 20,
                          color: LoreDubPalette.mutedInk,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(l10n.packsEmpty)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final pack in state.packs) ...[
                          CharacterPackArea(
                            key: ValueKey(pack.id),
                            pack: pack,
                            members: state.membersOf(pack),
                            onRename: (name) => cubits.characters.renamePack(pack.id, name),
                            onExport: pack.characterIds.isEmpty
                                ? null
                                : () => _export(context, pack, state.membersOf(pack)),
                            onDelete: () => _confirmDelete(context, pack),
                            onDrop: (drag) =>
                                cubits.characters.addToPack(pack.id, drag.character.id),
                            onRemoveMember: (character) =>
                                cubits.characters.removeFromPack(pack.id, character.id),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      );
    },
  );
}

class _EmptyCast extends StatelessWidget {
  const _EmptyCast({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) => Center(
    child: loading
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.groups_rounded, size: 42, color: LoreDubPalette.mutedInk),
                const SizedBox(height: 14),
                Text(
                  AppLocalizations.of(context).charactersEmpty,
                  textAlign: TextAlign.center,
                ),
              ],
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
      key: const ValueKey('modelsList'),
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

/// How far one group of settings stands from the next: enough more than the
/// 12 between cards that the break is read as a break rather than a gap.
const _settingsGroupGap = 28.0;

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

  /// The whole screen: four groups of cards, in the order a player meets
  /// them — what is heard, how it sounds, what drives it, where it lives.
  ///
  /// Each group is announced the way the other screens number their areas,
  /// and stands off further from its neighbour than the cards inside it do.
  /// The grouping was a gap alone before, and the same gap the cards within
  /// a group already kept, so eleven cards read as one list and the
  /// interface language sat level with the path to Python.
  Widget _build(BuildContext context, SettingsState state, {required bool running}) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      key: const ValueKey('settingsList'),
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      children: [
        _ModuleLabel(number: '01', label: l10n.settingsGroupInterface),
        const SizedBox(height: 12),
        ..._theInterface(context, l10n, state, running: running),
        const SizedBox(height: _settingsGroupGap),
        _ModuleLabel(number: '02', label: l10n.settingsGroupDubbing),
        const SizedBox(height: 12),
        ..._howItSounds(context, l10n, state, running: running),
        const SizedBox(height: _settingsGroupGap),
        _ModuleLabel(number: '03', label: l10n.settingsGroupCompute),
        const SizedBox(height: 12),
        _ComputeDeviceCard(cubits: cubits),
        const SizedBox(height: _settingsGroupGap),
        // Where the parts come from, and where they are kept: two areas of
        // their own rather than one drawer holding everything a player only
        // opens when something is broken.
        LayoutBuilder(
          builder: (context, constraints) {
            final downloads = _theDownloads(context, l10n, state, running: running);
            final paths = _thePaths(context, l10n, state, running: running);
            return constraints.maxWidth >= _pairedCardsWidth
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: downloads),
                      const SizedBox(width: 12),
                      Expanded(child: paths),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      downloads,
                      const SizedBox(height: _settingsGroupGap),
                      paths,
                    ],
                  );
          },
        ),
      ],
    );
  }

  /// The language LoreDub speaks to the player in. Where the original comes
  /// from is no longer a setting: the game's sound is dubbed on Live, and
  /// the screen is read on its own page, which keeps the frame it reads.
  List<Widget> _theInterface(
    BuildContext context,
    AppLocalizations l10n,
    SettingsState state, {
    required bool running,
  }) {
    final settings = state.settings;
    final language = _SettingCard(
      title: l10n.settingsInterfaceLanguage,
      subtitle: l10n.interfaceLanguageNote,
      child: SizedBox(
        width: double.infinity,
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
    );
    return [
      LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= _pairedCardsWidth
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: language),
                    const SizedBox(width: 12),
                    Expanded(child: _scaleCard(l10n, settings)),
                  ],
                ),
              )
            : Column(
                children: [language, const SizedBox(height: 12), _scaleCard(l10n, settings)],
              ),
      ),
      const SizedBox(height: 12),
      ..._theHotkeys(context, l10n, state, running: running),
    ];
  }

  /// The marking over one of the two areas at the foot, spaced so that both
  /// of them start on the same line.
  Widget _areaHeading(String label, {required String number}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _ModuleLabel(number: number, label: label),
  );

  /// How large the interface itself is drawn, beside the language it speaks:
  /// the two things a player sets once, for their own eyes rather than for
  /// the dubbing.
  Widget _scaleCard(AppLocalizations l10n, AppSettings settings) => _SettingCard(
    title: l10n.settingsScale,
    subtitle: l10n.scaleValue((settings.chosenScale * 100).round()),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Slider(
          key: const ValueKey('interfaceScale'),
          value: settings.chosenScale,
          min: AppSettings.smallestScale,
          max: AppSettings.largestScale,
          divisions: AppSettings.scaleDivisions,
          label: l10n.scaleValue((settings.chosenScale * 100).round()),
          onChanged: (value) => cubits.settings.update(settings.copyWith(interfaceScale: value)),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.scaleNote,
          style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
        ),
      ],
    ),
  );

  /// The proxy the downloads go through.
  Widget _theDownloads(
    BuildContext context,
    AppLocalizations l10n,
    SettingsState state, {
    required bool running,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _areaHeading(l10n.settingsGroupDownloads, number: '04'),
      _proxyCard(context, l10n),
    ],
  );

  /// Where the interpreter and the packages sit on this machine.
  Widget _thePaths(
    BuildContext context,
    AppLocalizations l10n,
    SettingsState state, {
    required bool running,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _areaHeading(l10n.settingsGroupPaths, number: '05'),
      _pythonCard(context, l10n),
      const SizedBox(height: 12),
      _modelDirectoryCard(context, l10n),
    ],
  );

  /// What the dubbing sounds like: how far the game is turned down under it, how fast a line is
  /// read, and in whose voice.
  List<Widget> _howItSounds(
    BuildContext context,
    AppLocalizations l10n,
    SettingsState state, {
    required bool running,
  }) {
    final settings = state.settings;
    final volume = _SettingCard(
      title: l10n.settingsOriginalVolume,
      subtitle: l10n.originalVolumeValue((settings.duckedVolume * 100).round()),
      // The floor is the capture's: the game is heard through this same
      // volume, and silenced outright it would never be dubbed at all.
      // Only the screen session, which has no ear in the game, may take it
      // all the way down -- and it asks for that on its own page.
      child: Column(
        children: [
          Slider(
            key: const ValueKey('originalVolume'),
            value: settings.duckedVolume,
            min: AppSettings.audibleDuck,
            max: AppSettings.loudestDuck,
            divisions: AppSettings.duckDivisions,
            label: '${(settings.duckedVolume * 100).round()}%',
            onChanged: running
                ? null
                : (value) => cubits.settings.update(settings.copyWith(originalVolume: value)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Switch(
                value: settings.duckWhileSpeaking,
                onChanged: running
                    ? null
                    : (value) =>
                          cubits.settings.update(settings.copyWith(duckWhileSpeaking: value)),
              ),
              const SizedBox(width: 6),
              Flexible(child: Text(l10n.duckWhileSpeaking)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.duckWhileSpeakingNote,
            style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
          ),
        ],
      ),
    );
    final pace = _SettingCard(
      title: l10n.settingsTtsSpeed,
      subtitle: l10n.speedValue(settings.chosenSpeed.toStringAsFixed(2)),
      child: Column(
        children: [
          Slider(
            key: const ValueKey('ttsSpeed'),
            value: settings.chosenSpeed,
            min: AppSettings.slowestSpeech,
            max: AppSettings.fastestSpeech,
            divisions: AppSettings.speechDivisions,
            label: l10n.speedValue(settings.chosenSpeed.toStringAsFixed(2)),
            onChanged: running
                ? null
                : (value) => cubits.settings.update(settings.copyWith(ttsSpeed: value)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Switch(
                key: const ValueKey('hurryWhenQueued'),
                value: settings.hurryWhenQueued,
                onChanged: running
                    ? null
                    : (value) => cubits.settings.update(settings.copyWith(hurryWhenQueued: value)),
              ),
              const SizedBox(width: 6),
              Flexible(child: Text(l10n.hurryWhenQueued)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.hurryWhenQueuedNote,
            style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
          ),
        ],
      ),
    );
    return [
      // Two sliders with a switch under each: side by side they are read at
      // a glance, and one under the other only where the screen is too
      // narrow to set either without squeezing its own notes.
      LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= _pairedCardsWidth
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: volume),
                    const SizedBox(width: 12),
                    Expanded(child: pace),
                  ],
                ),
              )
            : Column(children: [volume, const SizedBox(height: 12), pace]),
      ),
      const SizedBox(height: 12),
      _VoiceCard(cubits: cubits),
    ];
  }

  /// What the player drives it with, and what the machine drives it on.
  /// The combinations Windows hands the application wherever the pointer
  /// is. They are the player's own way in, so they stand with the interface
  /// rather than beside the hardware the models run on.
  List<Widget> _theHotkeys(
    BuildContext context,
    AppLocalizations l10n,
    SettingsState state, {
    required bool running,
  }) {
    final settings = state.settings;
    return [
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
                    (_settings.frameHotkey, l10n.hotkeyFrame),
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
                    (_settings.frameHotkey, l10n.hotkeyFrame),
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
                    (_settings.frameHotkey, l10n.hotkeyFrame),
                  ],
                ),
                onChanged: (hotkey) => cubits.settings.update(
                  hotkey == null
                      ? _settings.copyWith(clearSnapshotHotkey: true)
                      : _settings.copyWith(snapshotHotkey: hotkey),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _HotkeyRow(
              label: l10n.hotkeyFrame,
              field: HotkeyField(
                key: const ValueKey('frameHotkey'),
                value: settings.frameHotkey,
                enabled: !running,
                validate: (hotkey) => _hotkeyProblem(
                  l10n,
                  hotkey,
                  others: [
                    (_settings.pauseHotkey, l10n.hotkeyPause),
                    (_settings.resumeHotkey, l10n.hotkeyResume),
                    (_settings.snapshotHotkey, l10n.hotkeySnapshot),
                  ],
                ),
                onChanged: (hotkey) => cubits.settings.update(
                  hotkey == null
                      ? _settings.copyWith(clearFrameHotkey: true)
                      : _settings.copyWith(frameHotkey: hotkey),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// Where the parts come from and where they are kept.
  Widget _pythonCard(BuildContext context, AppLocalizations l10n) => _SettingsBuilder(
    cubits: cubits,
    builder: (context, state) => _SettingCard(
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
              validator: (value) => (value ?? '').trim().isEmpty ? l10n.pythonFieldRequired : null,
              onFieldSubmitted: (_) => _savePython(),
            ),
            const SizedBox(height: 12),
            // Side by side where the card is wide enough for all three, and
            // one under another at a shared width where it is not: wrapped
            // at their own widths they came out ragged, each button a
            // different length down the right edge.
            _PythonActions(
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
  );

  Widget _proxyCard(BuildContext context, AppLocalizations l10n) => _SettingCard(
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
  );

  Widget _modelDirectoryCard(BuildContext context, AppLocalizations l10n) => _SettingCard(
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
  );
}

/// The buttons under the Python path: a row while they fit, a stack of one
/// width when they do not.
class _PythonActions extends StatelessWidget {
  const _PythonActions({required this.children});

  final List<Widget> children;

  /// Below this the three of them no longer share a line.
  static const _oneRow = 520.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth >= _oneRow
        ? Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: children,
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0) const SizedBox(height: 8),
                child,
              ],
            ],
          ),
  );
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
    // A mode this setup cannot honour is shown as the one that will run.
    final mode = switch (settings.voiceMode) {
      VoiceMode.original => VoiceMode.original,
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
              ButtonSegment(value: VoiceMode.original, label: Text(l10n.voiceOriginal)),
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
          ],
          // The converter is what hears who is speaking, so remembering the
          // characters is on offer wherever it is installed — with the
          // original voice it also keeps their timbre.
          if (converterInstalled && mode != VoiceMode.chosen) ...[
            const SizedBox(height: 12),
            _VoiceBankControls(
              cubits: cubits,
              settings: settings,
              size: state.voiceBankSize,
              running: running,
            ),
          ],
          if (!canFollow) ...[
            const SizedBox(height: 10),
            Text(
              l10n.voiceUnavailable,
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
          // What the choice leaves to say: the card a GPU run would use, or
          // -- everything being on the processor -- how much of it to use.
          // Automatic says neither: the table below shows where each stage
          // ended up, which is the answer it would have given.
          if (settings.computeDevice == ComputeDevice.gpu) ...[
            const SizedBox(height: 14),
            Text(
              adapter == null ? l10n.computeNoAdapter : l10n.computeAdapterDetected(adapter.name),
              style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
            ),
          ] else if (settings.computeDevice == ComputeDevice.cpu) ...[
            const SizedBox(height: 14),
            Text(
              l10n.performanceNote(Platform.numberOfProcessors, defaultCpuThreads()),
              style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: const ValueKey('cpuThreads'),
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
          ],
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
      final size = formatPackageSize(l10n, missing.package.approximateBytes);
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

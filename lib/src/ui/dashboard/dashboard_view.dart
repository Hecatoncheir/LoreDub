// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/services/model_catalog.dart';
import '../../domain/app_release.dart';
import '../../domain/app_settings.dart';
import '../../domain/compute_device.dart';
import '../../domain/game_process.dart';
import '../../domain/model_package.dart';
import '../../domain/model_proxy.dart';
import '../../domain/runtime_paths.dart';
import '../../domain/pipeline_state.dart';
import '../../domain/runtime_package.dart';
import '../../domain/spoken_language.dart';
import '../../../l10n/app_localizations.dart';
import '../app_icons.dart';
import '../compute_names.dart';
import '../failure_messages.dart';
import '../language_names.dart';
import '../model_names.dart';
import '../theme.dart';
import 'dashboard_view_model.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key, required this.viewModel});

  final DashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) => Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          final content = SafeArea(
            child: Column(
              children: [
                _Header(viewModel: viewModel),
                if (viewModel.error case final error?)
                  _ErrorBanner(
                    message: describeFailure(AppLocalizations.of(context), error),
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: switch (viewModel.section) {
                      DashboardSection.live => _LivePanel(
                        key: const ValueKey('live'),
                        viewModel: viewModel,
                      ),
                      DashboardSection.models => _ModelsPanel(
                        key: const ValueKey('models'),
                        viewModel: viewModel,
                      ),
                      DashboardSection.settings => _SettingsPanel(
                        key: const ValueKey('settings'),
                        viewModel: viewModel,
                      ),
                    },
                  ),
                ),
              ],
            ),
          );
          if (compact) {
            return Column(
              children: [
                Expanded(child: content),
                _BottomNavigation(viewModel: viewModel),
              ],
            );
          }
          return Row(
            children: [
              _Navigation(viewModel: viewModel),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          );
        },
      ),
    ),
  );
}

class _Navigation extends StatelessWidget {
  const _Navigation({required this.viewModel});

  final DashboardViewModel viewModel;

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
        _NavigationItem(
          icon: (color) => LoreDubIcons.audioCapture(color: color, size: 21),
          label: AppLocalizations.of(context).navLive,
          selected: viewModel.section == DashboardSection.live,
          onTap: () => viewModel.selectSection(DashboardSection.live),
        ),
        _NavigationItem(
          icon: (color) => Icon(Icons.memory_rounded, size: 21, color: color),
          label: AppLocalizations.of(context).navModels,
          selected: viewModel.section == DashboardSection.models,
          onTap: () => viewModel.selectSection(DashboardSection.models),
        ),
        _NavigationItem(
          icon: (color) => Icon(Icons.tune_rounded, size: 21, color: color),
          label: AppLocalizations.of(context).navSettings,
          selected: viewModel.section == DashboardSection.settings,
          onTap: () => viewModel.selectSection(DashboardSection.settings),
        ),
        const Spacer(),
        _VersionButton(viewModel: viewModel),
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
/// nothing else, so the row does not resize. A published newer version adds
/// an arrow that opens its page.
class _VersionButton extends StatelessWidget {
  const _VersionButton({required this.viewModel});

  final DashboardViewModel viewModel;

  String _tooltip(AppLocalizations l10n) => switch (viewModel.updates.status) {
    UpdateStatus.checking => l10n.updateChecking,
    UpdateStatus.current => l10n.updateUpToDate,
    UpdateStatus.failed => l10n.updateFailed,
    _ => l10n.updateCheckAgain,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final updates = viewModel.updates;
    final version = updates.currentVersion;
    return Padding(
      padding: const EdgeInsets.fromLTRB(_footerOuterInset, 0, 8, 2),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: _tooltip(l10n),
              child: TextButton(
                onPressed: updates.checking ? null : () => viewModel.checkForUpdates(),
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
          if (updates.release case final release?)
            Tooltip(
              message: l10n.updateOpenRelease(release.version),
              child: IconButton(
                onPressed: viewModel.openReleasePage,
                icon: const Icon(Icons.arrow_outward_rounded, size: 18),
                color: LoreDubPalette.orange,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              ),
            ),
        ],
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
  const _BottomNavigation({required this.viewModel});

  final DashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NavigationBar(
      height: 68,
      backgroundColor: LoreDubPalette.panel,
      indicatorColor: LoreDubPalette.orange,
      selectedIndex: viewModel.section.index,
      onDestinationSelected: (index) => viewModel.selectSection(DashboardSection.values[index]),
      destinations: [
        NavigationDestination(
          // The bar tints its font icons itself, which leaves the drawing
          // untouched, so it is handed the same two colours by hand.
          icon: LoreDubIcons.audioCapture(color: scheme.onSurfaceVariant),
          selectedIcon: LoreDubIcons.audioCapture(color: scheme.onSecondaryContainer),
          label: AppLocalizations.of(context).navLive,
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
  const _Header({required this.viewModel});

  final DashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 22, 28, 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                switch (viewModel.section) {
                  DashboardSection.live => '01  /  LIVE VOICE',
                  DashboardSection.models => '02  /  MODEL BANK',
                  DashboardSection.settings => '03  /  SIGNAL SETUP',
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
                switch (viewModel.section) {
                  DashboardSection.live => AppLocalizations.of(context).titleLive,
                  DashboardSection.models => AppLocalizations.of(context).titleModels,
                  DashboardSection.settings => AppLocalizations.of(context).titleSettings,
                },
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
        _StatusChip(status: viewModel.status, stage: viewModel.startupStage),
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, this.stage = ''});

  final PipelineStatus status;

  /// What the startup is doing right now, shown instead of a bare "Запуск…".
  final String stage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, color) = switch (status) {
      PipelineStatus.idle => (l10n.statusIdle, LoreDubPalette.mutedInk),
      PipelineStatus.starting => (
        stage.isEmpty ? l10n.statusStarting : describeStartupStage(l10n, stage),
        LoreDubPalette.warning,
      ),
      PipelineStatus.listening => (l10n.statusListening, LoreDubPalette.success),
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
  const _LivePanel({super.key, required this.viewModel});

  final DashboardViewModel viewModel;

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
                    viewModel: viewModel,
                    compact: constraints.maxWidth < 900,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!viewModel.requiredModelsInstalled)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Card(
              child: ListTile(
                leading: const Icon(
                  Icons.download_rounded,
                  color: LoreDubPalette.warning,
                ),
                title: Text(AppLocalizations.of(context).modelsNeededTitle),
                subtitle: Text(AppLocalizations.of(context).modelsNeededNote),
                trailing: TextButton(
                  onPressed: () => viewModel.selectSection(DashboardSection.models),
                  child: Text(AppLocalizations.of(context).modelsNeededAction),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
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
                      Tooltip(
                        message: AppLocalizations.of(context).transcriptClearTooltip,
                        child: TextButton.icon(
                          // Enabled only when there is something to clear, so
                          // the button never claims work it will not do.
                          onPressed: viewModel.transcript.isEmpty
                              ? null
                              : viewModel.clearTranscript,
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
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: viewModel.transcript.isEmpty
                      ? _EmptyTranscript(targetLanguage: viewModel.settings.targetLanguage)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                          itemCount: viewModel.transcript.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 14),
                          itemBuilder: (context, index) =>
                              _TranscriptBubble(entry: viewModel.transcript[index]),
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

class _SourceControls extends StatelessWidget {
  const _SourceControls({required this.viewModel, required this.compact});

  final DashboardViewModel viewModel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final requiresProcess =
        viewModel.settings.captureMode == CaptureMode.ocr ||
        viewModel.settings.audioCaptureSource == AudioCaptureSource.process;
    final selector = DropdownMenu<GameProcess>(
      key: ValueKey(viewModel.selectedProcess?.pid),
      initialSelection: viewModel.selectedProcess,
      expandedInsets: EdgeInsets.zero,
      enabled: !viewModel.running && requiresProcess,
      enableFilter: true,
      enableSearch: true,
      requestFocusOnTap: true,
      label: Text(l10n.processLabel),
      hintText: l10n.processHint,
      dropdownMenuEntries: viewModel.processes
          .map(
            (process) => DropdownMenuEntry(
              value: process,
              label: l10n.processEntry(process.name, process.pid),
            ),
          )
          .toList(),
      onSelected: viewModel.running || !requiresProcess ? null : viewModel.selectProcess,
    );
    final helper = Text(
      requiresProcess ? l10n.captureProcessNote : l10n.captureSystemNote,
      style: Theme.of(context).textTheme.bodySmall,
    );
    final sourceSwitch = viewModel.settings.captureMode == CaptureMode.audio
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
            selected: {viewModel.settings.audioCaptureSource},
            onSelectionChanged: viewModel.running
                ? null
                : (selection) => viewModel.updateSettings(
                    viewModel.settings.copyWith(
                      audioCaptureSource: selection.first,
                    ),
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
          onPressed: viewModel.running ? null : viewModel.refreshProcesses,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
    final language = _LanguageControls(viewModel: viewModel);
    final target = _TargetLanguagePicker(viewModel: viewModel);
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
  const _TargetLanguagePicker({required this.viewModel});

  final DashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languages = dubbingLanguages;
    final selected = viewModel.settings.targetLanguage;
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
                viewModel.isLanguageReady(language)
                    ? spokenLanguageName(l10n, language)
                    : l10n.languageWithoutModels(spokenLanguageName(l10n, language)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: viewModel.running
            ? null
            : (value) {
                if (value != null) viewModel.selectTargetLanguage(value);
              },
      ),
      action: _StartButton(viewModel: viewModel),
    );
  }
}

/// Loading Marian and Silero takes long enough that a plain label would look
/// like a freeze, so the button carries the progress of the startup itself.
class _StartButton extends StatelessWidget {
  const _StartButton({required this.viewModel});

  final DashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final starting = viewModel.status == PipelineStatus.starting;
    final progress = viewModel.startupProgress;
    return Tooltip(
      message: starting && viewModel.startupStage.isNotEmpty
          ? describeStartupStage(l10n, viewModel.startupStage)
          : '',
      child: FilledButton.icon(
        onPressed: viewModel.running || viewModel.canStart ? viewModel.togglePipeline : null,
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
            : Icon(viewModel.running ? Icons.stop_rounded : Icons.play_arrow_rounded),
        label: Text(
          starting
              ? (progress == null
                    ? l10n.startingPlain
                    : l10n.startingProgress((progress * 100).round()))
              : viewModel.running
              ? l10n.stopDubbing
              : l10n.startDubbing,
        ),
      ),
    );
  }
}

/// Language of the original speech. Naming it skips whisper's detection pass,
/// which is a noticeable share of the delay before a phrase is voiced.
class _LanguageControls extends StatelessWidget {
  const _LanguageControls({required this.viewModel});

  final DashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = viewModel.settings;
    final locked = viewModel.running;
    final detected = settings.detectSourceLanguage ? viewModel.detectedLanguage : null;
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
                  viewModel.updateSettings(settings.copyWith(sourceLanguage: value));
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
                : (value) =>
                      viewModel.updateSettings(settings.copyWith(detectSourceLanguage: value)),
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
  const _EmptyTranscript({required this.targetLanguage});

  /// The pipeline ends in whichever language is selected, so the hint says so
  /// rather than always naming Russian.
  final String targetLanguage;

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
                AppLocalizations.of(context).pipelineSummary(
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

class _ModelsPanel extends StatelessWidget {
  const _ModelsPanel({super.key, required this.viewModel});

  final DashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = viewModel.settings.targetLanguage;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      children: [
        _ModuleLabel(number: '01', label: l10n.sectionRecognition),
        const SizedBox(height: 4),
        _SectionNote(l10n.sectionRecognitionNote),
        if (viewModel.recognitionNeedsEnglish) ...[
          const SizedBox(height: 8),
          _SectionNote(l10n.recognitionNeedsEnglish),
        ],
        for (final state in viewModel.recognitionModels) ...[
          const SizedBox(height: 12),
          _ModelCard(
            state: state,
            onInstall: () => viewModel.installModel(state),
            choosable: true,
            selected: state.model.id == viewModel.selectedRecognition?.model.id,
            onSelect: viewModel.running
                ? null
                : () => viewModel.selectRecognitionModel(state.model.id),
          ),
        ],
        const SizedBox(height: 26),
        _ModuleLabel(number: '02', label: l10n.sectionTranslation),
        const SizedBox(height: 4),
        _SectionNote(l10n.sectionTranslationNote),
        for (final state in viewModel.translationModels) ...[
          const SizedBox(height: 12),
          _ModelCard(
            state: state,
            onInstall: () => viewModel.installModel(state),
            language: state.model.language,
            choosable: true,
            selected: state.model.language == selected,
            onSelect: viewModel.running
                ? null
                : () => viewModel.selectTargetLanguage(state.model.language!),
          ),
        ],
        const SizedBox(height: 26),
        _ModuleLabel(number: '03', label: l10n.sectionSpeech),
        const SizedBox(height: 4),
        _SectionNote(l10n.sectionSpeechNote),
        for (final state in viewModel.speechModels) ...[
          const SizedBox(height: 12),
          _ModelCard(
            state: state,
            onInstall: () => viewModel.installModel(state),
            language: state.model.language,
            choosable: true,
            selected: state.model.language == selected,
            onSelect: viewModel.running
                ? null
                : () => viewModel.selectTargetLanguage(state.model.language!),
          ),
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

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.state,
    required this.onInstall,
    this.language,
    this.choosable = false,
    this.selected = false,
    this.onSelect,
  });

  final ModelInstallState state;
  final VoidCallback onInstall;

  /// Set for the packages that come per language; null for the recognition
  /// models, which serve all of them.
  final String? language;

  /// Whether this card is one of a set the player picks between — the
  /// languages, and now the whisper builds. Such a card shows which one is
  /// chosen instead of only whether it is downloaded.
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
                Text('${(progress * 100).round()}%'),
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
      onPressed: state.installed || state.downloading ? null : onInstall,
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
  const _SettingsPanel({super.key, required this.viewModel});

  final DashboardViewModel viewModel;

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  final _proxyFormKey = GlobalKey<FormState>();
  final _pythonFormKey = GlobalKey<FormState>();
  late final TextEditingController _proxyController;
  late final TextEditingController _pythonController;

  DashboardViewModel get viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _proxyController = TextEditingController(
      text: viewModel.settings.modelProxyUrl,
    );
    _pythonController = TextEditingController(
      text: viewModel.settings.pythonExecutable.isEmpty
          ? bundledPythonExecutablePath()
          : viewModel.settings.pythonExecutable,
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

  void _saveProxy() {
    if (!(_proxyFormKey.currentState?.validate() ?? false)) return;
    viewModel.updateSettings(
      viewModel.settings.copyWith(
        modelProxyUrl: _proxyController.text.trim(),
      ),
    );
  }

  Future<void> _findPython() async {
    final executable = await viewModel.findPythonExecutable();
    if (executable == null || !mounted) return;
    _pythonController.text = executable;
  }

  void _savePython() {
    if (!(_pythonFormKey.currentState?.validate() ?? false)) return;
    viewModel.updateSettings(
      viewModel.settings.copyWith(
        pythonExecutable: _pythonController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = viewModel.settings;
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
                viewModel.updateSettings(settings.copyWith(interfaceLanguage: selection.first)),
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
            onSelectionChanged: viewModel.running
                ? null
                : (selection) =>
                      viewModel.updateSettings(settings.copyWith(captureMode: selection.first)),
          ),
        ),
        if (settings.captureMode == CaptureMode.ocr) ...[
          const SizedBox(height: 12),
          _SettingCard(
            title: l10n.settingsOcrRegion,
            subtitle: l10n.ocrRegionValue(((1 - settings.ocrRegionTop) * 100).round()),
            child: Slider(
              value: settings.ocrRegionTop,
              min: 0.25,
              max: 0.8,
              divisions: 11,
              label: '${((1 - settings.ocrRegionTop) * 100).round()}%',
              onChanged: viewModel.running
                  ? null
                  : (value) => viewModel.updateSettings(
                      settings.copyWith(ocrRegionTop: value),
                    ),
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
            onChanged: viewModel.running
                ? null
                : (value) => viewModel.updateSettings(settings.copyWith(originalVolume: value)),
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
            onChanged: viewModel.running
                ? null
                : (value) => viewModel.updateSettings(settings.copyWith(ttsSpeed: value)),
          ),
        ),
        const SizedBox(height: 12),
        _VoiceCard(viewModel: viewModel),
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
            onChanged: viewModel.running
                ? null
                : (value) {
                    if (value != null) {
                      viewModel.updateSettings(settings.copyWith(cpuThreads: value));
                    }
                  },
          ),
        ),
        const SizedBox(height: 12),
        _ComputeDeviceCard(viewModel: viewModel),
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
                      onPressed: viewModel.searchingPython ? null : _findPython,
                      icon: viewModel.searchingPython
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.manage_search_rounded),
                      label: Text(
                        viewModel.searchingPython
                            ? l10n.pythonSearching
                            : l10n.pythonFindAutomatically,
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
              final path = SelectableText(
                viewModel.modelDirectoryPath,
                style: Theme.of(context).textTheme.bodyMedium,
              );
              final open = OutlinedButton.icon(
                onPressed: viewModel.openModelDirectory,
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
  const _VoiceCard({required this.viewModel});

  final DashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = viewModel.settings;
    final voices = viewModel.availableVoices;
    final canFollow = viewModel.canFollowSpeaker;
    final automatic = settings.automaticVoice && canFollow;
    return _SettingCard(
      title: l10n.settingsVoice,
      subtitle: l10n.voiceNote,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: true,
                label: Text(l10n.voiceAutomatic),
                enabled: canFollow,
              ),
              ButtonSegment(value: false, label: Text(l10n.voiceFixed)),
            ],
            selected: {automatic},
            onSelectionChanged: viewModel.running
                ? null
                : (selection) =>
                      viewModel.updateSettings(settings.copyWith(automaticVoice: selection.first)),
          ),
          if (!canFollow) ...[
            const SizedBox(height: 10),
            Text(
              settings.captureMode == CaptureMode.ocr
                  ? l10n.voiceNeedsAudio
                  : l10n.voiceUnavailable,
              style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 12),
            ),
          ],
          if (!automatic && voices.isNotEmpty) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: const ValueKey('voice'),
              initialValue: viewModel.selectedVoice,
              decoration: InputDecoration(labelText: l10n.voiceFieldLabel),
              items: [
                for (final voice in voices)
                  DropdownMenuItem(value: voice.id, child: Text(voiceLabel(l10n, voice))),
              ],
              onChanged: viewModel.running
                  ? null
                  : (value) {
                      if (value != null) {
                        viewModel.updateSettings(settings.copyWith(voice: value));
                      }
                    },
            ),
          ],
          // Which voice the automatic choice actually settled on, so it is
          // not a silent decision — the same courtesy the detected language
          // gets on the live screen.
          if (automatic ? viewModel.spokenVoice : null case final speaking?) ...[
            const SizedBox(height: 10),
            Text(
              l10n.voiceSpeaking(speaking),
              style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

/// The compute section: one preset for the whole pipeline, then a row per
/// stage showing what that preset actually resolved to and letting it be
/// overridden. A backend the machine cannot run is shown but disabled, so an
/// AMD owner can see that CUDA exists and why it is not on offer.
class _ComputeDeviceCard extends StatelessWidget {
  const _ComputeDeviceCard({required this.viewModel});

  final DashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final adapter = viewModel.availability.adapters.firstOrNull;
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
            selected: {viewModel.settings.computeDevice},
            onSelectionChanged: viewModel.running
                ? null
                : (selection) => viewModel.selectComputeDevice(selection.first),
          ),
          const SizedBox(height: 14),
          Text(
            adapter == null ? l10n.computeNoAdapter : l10n.computeAdapterDetected(adapter.name),
            style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
          ),
          const SizedBox(height: 14),
          for (final stage in ComputeStage.values) ...[
            _ComputeStageRow(viewModel: viewModel, stage: stage),
            if (stage != ComputeStage.values.last) const SizedBox(height: 10),
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
}

class _ComputeStageRow extends StatelessWidget {
  const _ComputeStageRow({required this.viewModel, required this.stage});

  final DashboardViewModel viewModel;
  final ComputeStage stage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = viewModel.backendFor(stage);
    final offered = stageBackends(stage);
    // The missing runtime of whichever backend the reader is most likely to
    // want: the best one the hardware could run but has nothing installed for.
    RuntimeInstallState? missing;
    for (final backend in offered) {
      missing ??= viewModel.missingRuntimeFor(stage, backend);
    }
    // A downloaded runtime is worth gigabytes, so it can be given back.
    final installed = missing != null ? null : viewModel.installedRuntimeFor(stage);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            computeStageName(l10n, stage),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final backend in offered)
                _BackendChip(
                  label: computeBackendName(l10n, backend),
                  selected: backend == selected,
                  enabled: !viewModel.running && viewModel.isBackendReady(stage, backend),
                  tooltip: _reasonUnavailable(l10n, backend),
                  onTap: () => viewModel.selectStageBackend(stage, backend),
                ),
              if (missing != null) _RuntimeDownloadButton(viewModel: viewModel, state: missing),
              if (installed != null) _RuntimeRemoveButton(viewModel: viewModel, state: installed),
            ],
          ),
        ),
      ],
    );
  }

  /// Why a chip is greyed out, or null when it is not.
  String? _reasonUnavailable(AppLocalizations l10n, ComputeBackend backend) {
    if (viewModel.isBackendReady(stage, backend)) return null;
    if (!viewModel.availability.supportsHardware(backend)) return l10n.computeBackendNoHardware;
    final package = viewModel.missingRuntimeFor(stage, backend);
    if (package != null) {
      return l10n.computeRuntimeMissing(formatPackageSize(package.package.approximateBytes));
    }
    return l10n.computeBackendUnsupported;
  }
}

class _BackendChip extends StatelessWidget {
  const _BackendChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.tooltip,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final String? tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chip = ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: enabled ? (_) => onTap() : null,
      showCheckmark: false,
      // The same orange the preset above uses: both are selections, and two
      // different selected colours in one card read as two different things.
      selectedColor: scheme.primary,
      disabledColor: LoreDubPalette.panel,
      labelStyle: TextStyle(
        fontFamily: LoreDubFonts.mono,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected
            ? scheme.onPrimary
            : enabled
            ? LoreDubPalette.ink
            : LoreDubPalette.mutedInk,
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

/// Gives a downloaded runtime back, once the user has confirmed it.
///
/// Hundreds of megabytes are not worth losing to a stray click, and this row
/// sits where the download button used to be — so the question is asked.
class _RuntimeRemoveButton extends StatelessWidget {
  const _RuntimeRemoveButton({required this.viewModel, required this.state});

  final DashboardViewModel viewModel;
  final RuntimeInstallState state;

  Future<void> _confirm(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final size = formatPackageSize(state.package.approximateBytes);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(l10n.computeRuntimeRemoveTitle),
        content: Text(
          l10n.computeRuntimeRemoveMessage(size),
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.computeRuntimeRemoveCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              // The theme's default foreground is too dark to read on the
              // error red, and this is the button that must be unmistakable.
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.computeRuntimeRemoveConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await viewModel.removeRuntime(state);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextButton.icon(
      onPressed: viewModel.running ? null : () => _confirm(context),
      icon: const Icon(Icons.delete_outline_rounded, size: 18),
      label: Text(
        '${l10n.computeRuntimeRemove} · '
        '${formatPackageSize(state.package.approximateBytes)}',
      ),
      style: TextButton.styleFrom(foregroundColor: LoreDubPalette.mutedInk),
    );
  }
}

/// Offers the download a backend is waiting on, and shows it running.
class _RuntimeDownloadButton extends StatelessWidget {
  const _RuntimeDownloadButton({required this.viewModel, required this.state});

  final DashboardViewModel viewModel;
  final RuntimeInstallState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (state.installing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 90,
            child: LinearProgressIndicator(value: state.progress, minHeight: 6),
          ),
          const SizedBox(width: 8),
          Text(
            '${((state.progress ?? 0) * 100).round()}%',
            style: const TextStyle(fontFamily: LoreDubFonts.mono, fontSize: 12),
          ),
        ],
      );
    }
    return TextButton.icon(
      onPressed: viewModel.running ? null : () => viewModel.installRuntime(state),
      icon: const Icon(Icons.download_rounded, size: 18),
      label: Text(
        '${l10n.computeRuntimeDownload} · '
        '${formatPackageSize(state.package.approximateBytes)}',
      ),
    );
  }
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

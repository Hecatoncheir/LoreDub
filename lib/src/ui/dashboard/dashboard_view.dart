// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/services/model_catalog.dart';
import '../../domain/app_settings.dart';
import '../../domain/game_process.dart';
import '../../domain/model_package.dart';
import '../../domain/model_proxy.dart';
import '../../domain/runtime_paths.dart';
import '../../domain/pipeline_state.dart';
import '../../domain/spoken_language.dart';
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
                if (viewModel.error case final error?) _ErrorBanner(message: error),
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
          icon: Icons.hearing_rounded,
          label: 'Эфир',
          selected: viewModel.section == DashboardSection.live,
          onTap: () => viewModel.selectSection(DashboardSection.live),
        ),
        _NavigationItem(
          icon: Icons.memory_rounded,
          label: 'Модели',
          selected: viewModel.section == DashboardSection.models,
          onTap: () => viewModel.selectSection(DashboardSection.models),
        ),
        _NavigationItem(
          icon: Icons.tune_rounded,
          label: 'Настройки',
          selected: viewModel.section == DashboardSection.settings,
          onTap: () => viewModel.selectSection(DashboardSection.settings),
        ),
        const Spacer(),
        const Padding(
          padding: EdgeInsets.all(12),
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

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
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
                Icon(
                  icon,
                  size: 21,
                  color: selected ? LoreDubPalette.orange : LoreDubPalette.ink,
                ),
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
  Widget build(BuildContext context) => NavigationBar(
    height: 68,
    backgroundColor: LoreDubPalette.panel,
    indicatorColor: LoreDubPalette.orange,
    selectedIndex: viewModel.section.index,
    onDestinationSelected: (index) => viewModel.selectSection(DashboardSection.values[index]),
    destinations: const [
      NavigationDestination(icon: Icon(Icons.hearing_rounded), label: 'Эфир'),
      NavigationDestination(icon: Icon(Icons.memory_rounded), label: 'Модели'),
      NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Настройки'),
    ],
  );
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
                  DashboardSection.live => 'Перевод игры',
                  DashboardSection.models => 'Локальные модели',
                  DashboardSection.settings => 'Настройки потока',
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
    final (label, color) = switch (status) {
      PipelineStatus.idle => ('Остановлено', LoreDubPalette.mutedInk),
      PipelineStatus.starting => (stage.isEmpty ? 'Запуск…' : stage, LoreDubPalette.warning),
      PipelineStatus.listening => ('Слушаю', LoreDubPalette.success),
      PipelineStatus.stopping => ('Остановка…', LoreDubPalette.warning),
      PipelineStatus.error => ('Ошибка', LoreDubPalette.error),
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
                title: const Text('Для первого запуска нужны модели'),
                subtitle: const Text('Они скачиваются отдельно и не входят в setup.'),
                trailing: TextButton(
                  onPressed: () => viewModel.selectSection(DashboardSection.models),
                  child: const Text('Открыть модели'),
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
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, 12),
                  child: _ModuleLabel(number: '02', label: 'LIVE TRANSCRIPT'),
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
      label: const Text('Процесс игры'),
      hintText: 'Введите название процесса',
      dropdownMenuEntries: viewModel.processes
          .map(
            (process) => DropdownMenuEntry(
              value: process,
              label: '${process.name}  ·  PID ${process.pid}',
            ),
          )
          .toList(),
      onSelected: viewModel.running || !requiresProcess ? null : viewModel.selectProcess,
    );
    final helper = Text(
      requiresProcess
          ? 'Захватывается только звук выбранного процесса'
          : 'Захватывается весь дефолтный поток, кроме звука LoreDub',
      style: Theme.of(context).textTheme.bodySmall,
    );
    final sourceSwitch = viewModel.settings.captureMode == CaptureMode.audio
        ? SegmentedButton<AudioCaptureSource>(
            segments: const [
              ButtonSegment(
                value: AudioCaptureSource.system,
                icon: Icon(Icons.speaker_group_outlined),
                label: Text('Весь звук'),
              ),
              ButtonSegment(
                value: AudioCaptureSource.process,
                icon: Icon(Icons.sports_esports_outlined),
                label: Text('Процесс'),
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
          tooltip: 'Обновить список процессов',
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
    final languages = dubbingLanguages;
    final selected = viewModel.settings.targetLanguage;
    return _LanguageRow(
      field: DropdownButtonFormField<String>(
        key: const ValueKey('targetLanguage'),
        // A value stored by an older build may no longer be on offer.
        initialValue: languages.contains(selected) ? selected : languages.first,
        isDense: true,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Язык перевода', isDense: true),
        items: [
          for (final language in languages)
            DropdownMenuItem(
              value: language,
              child: Text(
                viewModel.isLanguageReady(language)
                    ? spokenLanguageTitle(language)
                    : '${spokenLanguageTitle(language)} · нет моделей',
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
    final starting = viewModel.status == PipelineStatus.starting;
    final progress = viewModel.startupProgress;
    final percent = progress == null ? '' : ' ${(progress * 100).round()}%';
    return Tooltip(
      message: starting && viewModel.startupStage.isNotEmpty ? viewModel.startupStage : '',
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
              ? 'Запуск$percent'
              : viewModel.running
              ? 'Остановить'
              : 'Начать перевод',
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
    final settings = viewModel.settings;
    final locked = viewModel.running;
    final detected = settings.detectSourceLanguage ? viewModel.detectedLanguage : null;
    return _LanguageRow(
      field: DropdownButtonFormField<String>(
        key: const ValueKey('sourceLanguage'),
        initialValue: settings.sourceLanguage,
        isDense: true,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Язык оригинала', isDense: true),
        items: spokenLanguages
            .map(
              (language) => DropdownMenuItem(value: language.code, child: Text(language.title)),
            )
            .toList(),
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
                  ? 'Определять язык'
                  : 'Определён: ${describeSpokenLanguage(detected)}',
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
      '$milliseconds мс',
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
              const Text('Здесь появятся распознанные и переведённые реплики'),
              const SizedBox(height: 6),
              Text(
                'Whisper → English → Marian → ${spokenLanguageTitle(targetLanguage)} → Silero',
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
    final selected = viewModel.settings.targetLanguage;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      children: [
        const _ModuleLabel(number: '01', label: 'РАСПОЗНАВАНИЕ РЕЧИ'),
        const SizedBox(height: 4),
        const _SectionNote(
          'Whisper переводит речь любого языка в английский текст. '
          'Больше для распознавания ничего скачивать не нужно.',
        ),
        for (final state in viewModel.recognitionModels) ...[
          const SizedBox(height: 12),
          _ModelCard(state: state, onInstall: () => viewModel.installModel(state)),
        ],
        const SizedBox(height: 26),
        const _ModuleLabel(number: '02', label: 'МОДЕЛИ ДЛЯ ПЕРЕВОДА ТЕКСТА'),
        const SizedBox(height: 4),
        const _SectionNote('Английский текст переводится на выбранный язык.'),
        for (final state in viewModel.translationModels) ...[
          const SizedBox(height: 12),
          _ModelCard(
            state: state,
            onInstall: () => viewModel.installModel(state),
            language: state.model.language,
            selected: state.model.language == selected,
            onSelect: viewModel.running
                ? null
                : () => viewModel.selectTargetLanguage(state.model.language!),
          ),
        ],
        const SizedBox(height: 26),
        const _ModuleLabel(number: '03', label: 'МОДЕЛИ ДЛЯ ОЗВУЧИВАНИЯ ТЕКСТА'),
        const SizedBox(height: 4),
        const _SectionNote('Голос должен быть того же языка, что и перевод.'),
        for (final state in viewModel.speechModels) ...[
          const SizedBox(height: 12),
          _ModelCard(
            state: state,
            onInstall: () => viewModel.installModel(state),
            language: state.model.language,
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
    this.selected = false,
    this.onSelect,
  });

  final ModelInstallState state;
  final VoidCallback onInstall;

  /// Set for the packages that come per language, which the player chooses
  /// between; null for Whisper, which serves all of them.
  final String? language;
  final bool selected;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final details = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (language != null)
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
                state.model.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              Text(
                state.model.description,
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
                  error,
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
      label: Text(state.installed ? 'Установлена' : 'Скачать'),
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
    final settings = viewModel.settings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      children: [
        _SettingCard(
          title: 'Источник текста',
          child: SegmentedButton<CaptureMode>(
            segments: const [
              ButtonSegment(
                value: CaptureMode.audio,
                icon: Icon(Icons.hearing_rounded),
                label: Text('Аудио игры'),
              ),
              ButtonSegment(
                value: CaptureMode.ocr,
                icon: Icon(Icons.subtitles_rounded),
                label: Text('Субтитры + OCR'),
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
            title: 'Область субтитров',
            subtitle: 'Нижние ${((1 - settings.ocrRegionTop) * 100).round()}% активного окна игры',
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
          title: 'Оригинальный звук',
          subtitle:
              'Громкость процесса игры во время перевода: ${(settings.originalVolume * 100).round()}%',
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
          title: 'Скорость озвучки',
          subtitle: '${settings.ttsSpeed.toStringAsFixed(2)}×',
          child: Slider(
            value: settings.ttsSpeed,
            min: 0.9,
            max: 1.35,
            divisions: 18,
            label: '${settings.ttsSpeed.toStringAsFixed(2)}×',
            onChanged: viewModel.running
                ? null
                : (value) => viewModel.updateSettings(settings.copyWith(ttsSpeed: value)),
          ),
        ),
        const SizedBox(height: 12),
        _SettingCard(
          title: 'Производительность',
          subtitle:
              'Распознавание занимает большую часть задержки и хорошо '
              'ускоряется потоками. Доступно ядер: ${Platform.numberOfProcessors}, '
              'рекомендуется ${defaultCpuThreads()}.',
          child: DropdownButtonFormField<int>(
            initialValue: settings.cpuThreads,
            decoration: const InputDecoration(labelText: 'Потоки CPU'),
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
        _SettingCard(
          title: 'Python runtime',
          subtitle:
              'Marian и Silero запускаются выбранным python.exe. '
              'Setup включает готовый runtime.',
          child: Form(
            key: _pythonFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _pythonController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Путь или команда Python',
                    helperText: 'Можно указать полный путь или python.exe из PATH.',
                    prefixIcon: Icon(Icons.terminal_rounded),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty ? 'Укажите python.exe' : null,
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
                        viewModel.searchingPython ? 'Идёт поиск…' : 'Найти автоматически',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        _pythonController.text = bundledPythonExecutablePath();
                        _savePython();
                      },
                      icon: const Icon(Icons.settings_backup_restore_rounded),
                      label: const Text('Встроенный'),
                    ),
                    FilledButton.icon(
                      onPressed: _savePython,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Сохранить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SettingCard(
          title: 'Загрузка моделей',
          subtitle:
              'Необязательный HTTP или SOCKS5 proxy применяется только '
              'при скачивании моделей.',
          child: Form(
            key: _proxyFormKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final field = TextFormField(
                  controller: _proxyController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'HTTP / SOCKS5 proxy',
                    hintText: 'http://127.0.0.1:7890',
                    helperText:
                        'Формат: http://… или socks5://user:password@host:port. '
                        'Значение хранится локально.',
                    helperMaxLines: 2,
                    prefixIcon: Icon(Icons.lan_outlined),
                  ),
                  validator: _validateProxy,
                  onFieldSubmitted: (_) => _saveProxy(),
                );
                final save = OutlinedButton.icon(
                  onPressed: _saveProxy,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Сохранить'),
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
          title: 'Каталог моделей',
          subtitle: 'Whisper, Marian и Silero хранятся локально.',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final path = SelectableText(
                viewModel.modelDirectoryPath,
                style: Theme.of(context).textTheme.bodyMedium,
              );
              final open = OutlinedButton.icon(
                onPressed: viewModel.openModelDirectory,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Открыть в Explorer'),
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

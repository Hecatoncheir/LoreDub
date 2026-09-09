// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../domain/app_settings.dart';
import '../../domain/game_process.dart';
import '../../domain/model_package.dart';
import '../../domain/pipeline_state.dart';
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
            'WINDOWS  ·  LOCAL PROCESSING',
            style: TextStyle(
              color: LoreDubPalette.mutedInk,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
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
                  color: LoreDubPalette.mutedInk,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
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
        _StatusChip(status: viewModel.status),
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final PipelineStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      PipelineStatus.idle => ('Остановлено', LoreDubPalette.mutedInk),
      PipelineStatus.starting => ('Запуск…', LoreDubPalette.warning),
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
                    compact: constraints.maxWidth < 720,
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
                      ? const _EmptyTranscript()
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: viewModel.transcript.length,
                          separatorBuilder: (_, _) => const Divider(height: 28),
                          itemBuilder: (context, index) {
                            final entry = viewModel.transcript[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.original.isEmpty ? entry.english : entry.original,
                                  style: const TextStyle(
                                    color: LoreDubPalette.mutedInk,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  entry.translated,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${entry.latency.inMilliseconds} мс',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            );
                          },
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
    final selector = DropdownButtonFormField<GameProcess>(
      initialValue: viewModel.selectedProcess,
      decoration: const InputDecoration(
        labelText: 'Процесс игры',
        helperText: 'Захватывается только звук выбранного процесса',
      ),
      items: viewModel.processes
          .map(
            (process) => DropdownMenuItem(
              value: process,
              child: Text('${process.name}  ·  PID ${process.pid}'),
            ),
          )
          .toList(),
      onChanged: viewModel.running ? null : viewModel.selectProcess,
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          tooltip: 'Обновить список процессов',
          onPressed: viewModel.running ? null : viewModel.refreshProcesses,
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: viewModel.running || viewModel.canStart ? viewModel.togglePipeline : null,
          icon: Icon(
            viewModel.running ? Icons.stop_rounded : Icons.play_arrow_rounded,
          ),
          label: Text(viewModel.running ? 'Остановить' : 'Начать перевод'),
        ),
      ],
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          selector,
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: actions),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: selector),
        const SizedBox(width: 16),
        actions,
      ],
    );
  }
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
            color: LoreDubPalette.ink,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      const SizedBox(width: 9),
      Text(
        label,
        style: const TextStyle(
          color: LoreDubPalette.ink,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    ],
  );
}

class _EmptyTranscript extends StatelessWidget {
  const _EmptyTranscript();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.subtitles_outlined,
          size: 42,
          color: LoreDubPalette.mutedInk,
        ),
        SizedBox(height: 14),
        Text('Здесь появятся распознанные и переведённые реплики'),
        SizedBox(height: 6),
        Text(
          'Whisper → English → Marian → Russian → Silero',
          style: TextStyle(color: LoreDubPalette.mutedInk),
        ),
      ],
    ),
  );
}

class _ModelsPanel extends StatelessWidget {
  const _ModelsPanel({super.key, required this.viewModel});

  final DashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
    itemCount: viewModel.models.length,
    separatorBuilder: (_, _) => const SizedBox(height: 12),
    itemBuilder: (context, index) => _ModelCard(
      state: viewModel.models[index],
      onInstall: () => viewModel.installModel(viewModel.models[index]),
    ),
  );
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.state, required this.onInstall});

  final ModelInstallState state;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final details = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
    return Card(
      child: Padding(
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
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({super.key, required this.viewModel});

  final DashboardViewModel viewModel;

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
          subtitle: 'Whisper base работает на CPU, чтобы не мешать игре.',
          child: DropdownButtonFormField<int>(
            initialValue: settings.cpuThreads,
            decoration: const InputDecoration(labelText: 'Потоки CPU'),
            items: const [
              2,
              3,
              4,
              6,
              8,
            ].map((value) => DropdownMenuItem(value: value, child: Text('$value'))).toList(),
            onChanged: viewModel.running
                ? null
                : (value) {
                    if (value != null) {
                      viewModel.updateSettings(settings.copyWith(cpuThreads: value));
                    }
                  },
          ),
        ),
      ],
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

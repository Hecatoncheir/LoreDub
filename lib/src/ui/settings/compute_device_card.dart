// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../../domain/compute_device.dart';
import '../common/labeled_switch.dart';
import '../common/setting_card.dart';
import '../compute_names.dart';
import '../dashboard/cubits/downloads_cubit.dart';
import '../dashboard/cubits/pipeline_cubit.dart';
import '../dashboard/cubits/settings_cubit.dart';
import '../dashboard/dashboard_context.dart';
import '../theme.dart';
import 'compute_preset_detail.dart';
import 'compute_runtimes_section.dart';
import 'stage_backend_table.dart';

/// The compute section: one preset for the whole pipeline, then a table of
/// stage by device showing what that preset actually resolved to and letting
/// any cell be picked, and the GPU packages as tiles. A backend the machine
/// cannot run is shown but faded, so an AMD owner can see that CUDA exists
/// and why it is not on offer.
class ComputeDeviceCard extends StatelessWidget {
  const ComputeDeviceCard({super.key});

  /// OpenVoice runs only for the original voice, so its row waits for it.
  static List<ComputeStage> _stages(AppSettings settings) => [
    for (final stage in ComputeStage.values)
      if (stage != ComputeStage.voiceConversion || settings.originalVoice) stage,
  ];

  @override
  Widget build(BuildContext context) => BlocBuilder<DownloadsCubit, DownloadsState>(
    builder: (context, downloads) => BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) => BlocBuilder<PipelineCubit, LivePipelineState>(
        buildWhen: whenChanged((pipeline) => (pipeline.running, pipeline.backendSignature)),
        builder: (context, pipeline) {
          final l10n = AppLocalizations.of(context);
          final settings = state.settings;
          final running = pipeline.running;
          final settingsCubit = context.read<SettingsCubit>();
          return SettingCard(
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
                      : (picked) => settingsCubit.selectComputeDevice(picked.first),
                ),
                ComputePresetDetail(
                  settings: settings,
                  availability: downloads.availability,
                  running: running,
                ),
                const SizedBox(height: 14),
                // Where recognition spends its time is not a matter of the
                // device, so this stands outside the preset's detail: the
                // window whisper listens over is the same on a processor and
                // on a card.
                LabeledSwitch(
                  switchKey: const ValueKey('roughRecognition'),
                  value: settings.roughRecognition,
                  label: l10n.roughRecognition,
                  onChanged: running
                      ? null
                      : (value) => settingsCubit.update(settings.copyWith(roughRecognition: value)),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.roughRecognitionNote,
                  style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
                ),
                const SizedBox(height: 14),
                StageBackendTable(
                  stages: _stages(settings),
                  downloads: downloads,
                  settings: settings,
                  pipeline: pipeline,
                ),
                ComputeRuntimesSection(
                  stages: _stages(settings),
                  downloads: downloads,
                  settings: settings,
                  pipeline: pipeline,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.computeSpeechNote,
                  style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

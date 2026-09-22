// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../../domain/compute_device.dart';
import '../../domain/cpu_threads.dart';
import '../dashboard/cubits/settings_bloc.dart';

/// What the preset leaves to say: the card a GPU run would use, or --
/// everything being on the processor -- how much of it to use. Automatic
/// says neither: the table below shows where each stage ended up, which is
/// the answer it would have given.
class ComputePresetDetail extends StatelessWidget {
  const ComputePresetDetail({
    super.key,
    required this.settings,
    required this.availability,
    required this.running,
  });

  final AppSettings settings;
  final ComputeAvailability availability;
  final bool running;

  void _chooseThreads(BuildContext context, int? threads) {
    if (threads == null) return;
    context.read<SettingsBloc>().add(SettingsChanged(settings.copyWith(cpuThreads: threads)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final note = Theme.of(context).textTheme.bodySmall;
    return switch (settings.computeDevice) {
      ComputeDevice.gpu => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text(switch (availability.adapters.firstOrNull) {
          final adapter? => l10n.computeAdapterDetected(adapter.name),
          null => l10n.computeNoAdapter,
        }, style: note),
      ),
      ComputeDevice.cpu => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 14),
          Text(
            l10n.performanceNote(
              Platform.numberOfProcessors,
              defaultCpuThreads(Platform.numberOfProcessors),
            ),
            style: note,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: const ValueKey('cpuThreads'),
            initialValue: settings.cpuThreads,
            decoration: InputDecoration(labelText: l10n.cpuThreads),
            items: [
              for (final threads in cpuThreadOptions(
                settings.cpuThreads,
                Platform.numberOfProcessors,
              ))
                DropdownMenuItem(value: threads, child: Text('$threads')),
            ],
            onChanged: running ? null : (threads) => _chooseThreads(context, threads),
          ),
        ],
      ),
      ComputeDevice.auto => const SizedBox.shrink(),
    };
  }
}

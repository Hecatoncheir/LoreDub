// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/compute_device.dart';
import '../../compute_names.dart';
import '../../dashboard/cubits/downloads_bloc.dart';
import '../../dashboard/cubits/settings_bloc.dart';
import '../canvas/pipeline_facts.dart';
import 'inspector_field.dart';

/// What a stage runs on, offered only where the machine can actually run it.
class StageDevicePicker extends StatelessWidget {
  const StageDevicePicker({
    super.key,
    required this.stage,
    required this.facts,
    required this.availability,
  });

  final ComputeStage stage;
  final PipelineFacts facts;
  final ComputeAvailability availability;

  void _choose(BuildContext context, ComputeBackend? backend) {
    if (backend == null) return;
    context.read<SettingsBloc>().add(StageBackendPinned(stage, backend));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final downloads = context.read<DownloadsBloc>().state;
    final ready = [
      for (final backend in stageBackends(stage))
        if (downloads.isBackendReady(stage, backend)) backend,
    ];
    final current = facts.backendOf(stage, availability);
    return InspectorField(
      label: l10n.settingsComputeDevice,
      child: DropdownButtonFormField<ComputeBackend>(
        key: ValueKey('graph-device-${stage.name}-${current.name}'),
        initialValue: ready.contains(current) ? current : null,
        isExpanded: true,
        items: [
          for (final backend in ready)
            DropdownMenuItem(value: backend, child: Text(computeBackendName(l10n, backend))),
        ],
        onChanged: facts.running || ready.length < 2
            ? null
            : (backend) => _choose(context, backend),
      ),
    );
  }
}

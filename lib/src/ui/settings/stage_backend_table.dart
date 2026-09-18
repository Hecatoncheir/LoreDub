// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../../domain/compute_device.dart';
import '../compute_names.dart';
import '../dashboard/cubits/downloads_cubit.dart';
import '../dashboard/cubits/pipeline_cubit.dart';
import 'stage_backend_cell.dart';
import 'stage_backend_status.dart';

/// Stage by device: every cell says at a glance whether the stage runs
/// there, could, needs a package first, or cannot at all.
class StageBackendTable extends StatelessWidget {
  const StageBackendTable({
    super.key,
    required this.stages,
    required this.downloads,
    required this.settings,
    required this.pipeline,
  });

  final List<ComputeStage> stages;
  final DownloadsState downloads;
  final AppSettings settings;
  final LivePipelineState pipeline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
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
                for (final (index, backend) in ComputeBackend.values.indexed) ...[
                  if (index > 0) const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: StageBackendCell(
                        stage: stage,
                        backend: backend,
                        running: pipeline.running,
                        status: stageBackendStatus(
                          downloads,
                          stage,
                          backend,
                          selected: pipeline.backendFor(stage, settings, downloads.availability),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

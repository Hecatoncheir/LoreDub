// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../dashboard/cubits/pipeline_cubit.dart';
import '../dashboard/dashboard_context.dart';
import '../common/module_label.dart';
import '../common/clear_list_button.dart';
import '../live/transcript_bubble.dart';
import 'empty_snapshots.dart';

/// Every selection translated so far, newest first.
class SnapshotHistory extends StatelessWidget {
  const SnapshotHistory({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<PipelineCubit, LivePipelineState>(
    buildWhen: whenChanged((pipeline) => pipeline.snapshots),
    builder: (context, pipeline) => Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 9, 12, 8),
            child: Row(
              children: [
                Flexible(
                  child: ModuleLabel(
                    number: '03',
                    label: AppLocalizations.of(context).areaSelectedText,
                  ),
                ),
                const Spacer(),
                ClearListButton(
                  tooltip: AppLocalizations.of(context).snapshotClearTooltip,
                  onPressed: pipeline.snapshots.isEmpty
                      ? null
                      : context.read<PipelineCubit>().clearSnapshots,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: pipeline.snapshots.isEmpty
                ? const EmptySnapshots()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    itemCount: pipeline.snapshots.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) =>
                        TranscriptBubble(entry: pipeline.snapshots[index]),
                  ),
          ),
        ],
      ),
    ),
  );
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../live/transcript_body.dart';

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
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 9, 12, 8),
            child: Row(
              children: [
                // The heading takes the room and gives way where there is
                // none, so the button that clears the list sits against the
                // card's edge rather than half way to it.
                Expanded(
                  child: ModuleLabel(
                    number: '03',
                    label: AppLocalizations.of(context).areaSelectedText,
                  ),
                ),
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
          // Grown with what it holds to the ten lines worth seeing at
          // once, and scrolling inside itself past them: the page scrolls
          // as a whole, and an area that grew without end would leave the
          // one beside it out of reach.
          TranscriptBody(
            fillsHeight: false,
            empty: pipeline.snapshots.isEmpty,
            lines: pipeline.snapshots.isEmpty
                ? const EmptySnapshots()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    shrinkWrap: true,
                    itemCount: pipeline.snapshots.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) => TranscriptBubble(
                      entry: pipeline.snapshots[index],
                      onSpeakAgain: () =>
                          context.read<PipelineCubit>().speakAgain(pipeline.snapshots[index]),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

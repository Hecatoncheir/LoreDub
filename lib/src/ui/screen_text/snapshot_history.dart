// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../live/transcript_body.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../common/module_label.dart';
import '../common/clear_list_button.dart';
import '../live/transcript_bubble.dart';
import 'empty_snapshots.dart';
import '../dashboard/cubits/transcript_bloc.dart';
import '../../domain/pipeline_state.dart';

/// Every selection translated so far, newest first.
class SnapshotHistory extends StatelessWidget {
  const SnapshotHistory({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocSelector<TranscriptBloc, TranscriptState, List<TranscriptEntry>>(
        selector: (lists) => lists.snapshots,
        builder: _build,
      );

  Widget _build(BuildContext context, List<TranscriptEntry> snapshots) => Card(
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
                onPressed: snapshots.isEmpty
                    ? null
                    : () => context.read<TranscriptBloc>().add(const SnapshotsCleared()),
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
          empty: snapshots.isEmpty,
          lines: snapshots.isEmpty
              ? const EmptySnapshots()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  shrinkWrap: true,
                  itemCount: snapshots.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) => TranscriptBubble(
                    entry: snapshots[index],
                    onSpeakAgain: () =>
                        context.read<TranscriptBloc>().add(LineSpokenAgain(snapshots[index])),
                  ),
                ),
        ),
      ],
    ),
  );
}

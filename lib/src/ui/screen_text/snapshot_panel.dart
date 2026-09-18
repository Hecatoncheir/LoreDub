// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../live/models_needed_notice.dart';
import 'screen_capture_card.dart';
import 'snapshot_history.dart';
import 'subtitle_frame_card.dart';
import 'subtitle_list.dart';
import 'screen_layout.dart';

/// The snapshot screen: a session that loads only the translator and the
/// voice, and translates what the player frames over the game while the
/// snapshot key is held.
///
/// The screen the game writes on, read two ways at once.
///
/// The frame is watched while the session runs, so a line the game adds to
/// it is dubbed as it appears; the snapshot key picks out anything else on
/// the screen by hand. One session answers both -- neither needs whisper,
/// and both end in the same translator and voice -- so what the game keeps
/// writing and what the player asks for arrive side by side.
class SnapshotPanel extends StatelessWidget {
  const SnapshotPanel({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // The frame, the controls and two lists need more room than the live
    // screen does. Given less, the screen scrolls and the lists take a
    // height of their own rather than being crushed to their own headers.
    builder: (context, constraints) {
      final stacked = constraints.maxWidth < ScreenLayout.frameBesideControlsWidth;
      final floor = stacked ? ScreenLayout.stackedMinHeight : ScreenLayout.minHeight;
      final filling = constraints.maxHeight >= floor;
      final content = _content(context, stacked: stacked, filling: filling);
      return filling ? content : SingleChildScrollView(child: content);
    },
  );

  Widget _content(BuildContext context, {required bool stacked, required bool filling}) {
    final lists = stacked
        ? Column(
            children: [
              Expanded(child: SubtitleList()),
              const SizedBox(height: 16),
              Expanded(child: SnapshotHistory()),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: SubtitleList()),
              const SizedBox(width: 16),
              Expanded(child: SnapshotHistory()),
            ],
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      child: Column(
        children: [
          if (stacked)
            Column(
              children: [
                ScreenCaptureCard(),
                const SizedBox(height: 16),
                SubtitleFrameCard(),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: ScreenCaptureCard()),
                const SizedBox(width: 16),
                SizedBox(
                  width: ScreenLayout.frameCardWidth,
                  child: SubtitleFrameCard(),
                ),
              ],
            ),
          ModelsNeededNotice(
            ready: (selection) => selection.screenModelsInstalled,
          ),
          const SizedBox(height: 16),
          if (filling)
            Expanded(child: lists)
          else
            SizedBox(
              height: stacked ? ScreenLayout.listHeight * 2 + 16 : ScreenLayout.listHeight,
              child: lists,
            ),
        ],
      ),
    );
  }
}

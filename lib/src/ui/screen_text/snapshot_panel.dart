// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../live/models_needed_notice.dart';
import 'screen_capture_card.dart';
import 'screen_layout.dart';
import 'snapshot_history.dart';
import 'snippet_only_card.dart';
import 'subtitle_frame_card.dart';
import 'subtitle_list.dart';

/// The Screen page: a session that loads only the translator and the voice,
/// and reads the game's own writing rather than listening to it.
///
/// The screen is read two ways, and each of them is a session of its own:
/// the frame reads itself as the game writes in it, and the key picks
/// anything else out by hand. What is set for both -- the game, the
/// language, whether it is silenced -- stands across the top, and under it
/// each way has its area and the list of what it has read.
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
      final content = _content(stacked: stacked, filling: filling);
      return filling ? content : SingleChildScrollView(child: content);
    },
  );

  Widget _content({required bool stacked, required bool filling}) {
    // Whether the two ways share the height of the window between them.
    // Stacked, or in a window too short to fill, they take a height of
    // their own and the page scrolls instead -- and a column that does not
    // fill must not be told to stretch, there being nothing to stretch to.
    final fills = filling && !stacked;
    // Each way of reading with the list of what it has read under it: the
    // snippets on the left, the frame on the right. Narrow, the four stand
    // in one column in that same order.
    final snippets = Column(
      mainAxisSize: fills ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SnippetOnlyCard(),
        const SizedBox(height: 16),
        if (fills)
          Expanded(child: SnapshotHistory())
        else
          SizedBox(height: ScreenLayout.listHeight, child: SnapshotHistory()),
      ],
    );
    final subtitles = Column(
      mainAxisSize: fills ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SubtitleFrameCard(),
        const SizedBox(height: 16),
        if (fills)
          Expanded(child: SubtitleList())
        else
          SizedBox(height: ScreenLayout.listHeight, child: SubtitleList()),
      ],
    );
    final alongside = fills ? CrossAxisAlignment.stretch : CrossAxisAlignment.start;
    final ways = stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [snippets, const SizedBox(height: 16), subtitles],
          )
        : Row(
            crossAxisAlignment: alongside,
            children: [
              Expanded(child: snippets),
              const SizedBox(width: 16),
              Expanded(child: subtitles),
            ],
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenCaptureCard(),
          ModelsNeededNotice(
            ready: (selection) => selection.screenModelsInstalled,
          ),
          const SizedBox(height: 16),
          if (fills) Expanded(child: ways) else ways,
        ],
      ),
    );
  }
}

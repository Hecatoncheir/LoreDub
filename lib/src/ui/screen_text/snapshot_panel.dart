// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../live/models_needed_notice.dart';
import 'screen_capture_card.dart';
import 'snippet_column.dart';
import 'subtitle_column.dart';
import 'screen_layout.dart';

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
    builder: (context, constraints) {
      // The page scrolls as a whole, so nothing in it has to be squeezed
      // into the window: each area is as tall as what it holds, and the
      // lists are held to what is worth reading rather than to a height.
      final stacked = constraints.maxWidth < ScreenLayout.frameBesideControlsWidth;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenCaptureCard(),
            ModelsNeededNotice(
              ready: (selection) => selection.screenModelsInstalled,
            ),
            const SizedBox(height: 16),
            if (stacked)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [SnippetColumn(), const SizedBox(height: 16), SubtitleColumn()],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: SnippetColumn()),
                  const SizedBox(width: 16),
                  Expanded(child: SubtitleColumn()),
                ],
              ),
          ],
        ),
      );
    },
  );
}

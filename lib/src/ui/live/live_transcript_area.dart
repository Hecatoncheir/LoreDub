// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import 'live_layout.dart';
import 'scene_voices_card.dart';
import 'transcript_card.dart';

/// The transcript and the voices of the scene. They stand side by side where
/// there is room; a narrow window stacks them, the transcript keeping
/// whatever height is left.
class LiveTranscriptArea extends StatelessWidget {
  const LiveTranscriptArea({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= LiveLayout.sceneBesideTranscriptWidth) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: TranscriptCard()),
            const SizedBox(width: 16),
            SizedBox(width: LiveLayout.sceneVoicesWidth, child: SceneVoicesCard()),
          ],
        );
      }
      // Shares of what is left rather than a fixed height. Under a card's
      // worth of room the transcript takes it all: two headers and nothing
      // under them would serve nobody.
      if (constraints.maxHeight < LiveLayout.sceneStackedMinHeight) return TranscriptCard();
      return Column(
        children: [
          Expanded(flex: 3, child: TranscriptCard()),
          const SizedBox(height: 16),
          Expanded(flex: 2, child: SceneVoicesCard()),
        ],
      );
    },
  );
}

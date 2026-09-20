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
      // Each card is as tall as what it holds, to the ten lines worth
      // seeing at once; the page scrolls rather than squeezing them.
      if (constraints.maxWidth >= LiveLayout.sceneBesideTranscriptWidth) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: TranscriptCard(number: '03', fillsHeight: false)),
            const SizedBox(width: 16),
            SizedBox(width: LiveLayout.sceneVoicesWidth, child: SceneVoicesCard()),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TranscriptCard(number: '03', fillsHeight: false),
          const SizedBox(height: 16),
          SceneVoicesCard(),
        ],
      );
    },
  );
}

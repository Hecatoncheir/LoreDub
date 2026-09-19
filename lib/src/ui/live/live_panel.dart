// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import 'live_content.dart';
import 'live_layout.dart';

/// The Эфир screen: where the sound comes from and in which language it is
/// dubbed, the start button, and below them the transcript and the voices
/// of the scene.
class LivePanel extends StatelessWidget {
  const LivePanel({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // The transcript takes what the cards above it leave, and in a short
    // window -- a compact layout with its navigation along the foot, a
    // checklist still to be worked through -- that was less than the card
    // needs for its own header. Under the floor the screen scrolls instead.
    builder: (context, constraints) => constraints.maxHeight >= LiveLayout.minHeight
        ? const LiveContent()
        : const SingleChildScrollView(
            child: SizedBox(height: LiveLayout.minHeight, child: LiveContent()),
          ),
  );
}

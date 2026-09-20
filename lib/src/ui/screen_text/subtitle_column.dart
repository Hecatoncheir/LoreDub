// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import 'subtitle_frame_card.dart';
import 'subtitle_list.dart';

/// The frame, and the lines it has gained. The list grows with them to the
/// ten it keeps, and then the oldest leaves as the newest arrives.
class SubtitleColumn extends StatelessWidget {
  const SubtitleColumn({super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SubtitleFrameCard(),
      const SizedBox(height: 16),
      SubtitleList(),
    ],
  );
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import 'settings_layout.dart';

/// Two cards side by side where the page is wide enough to read both at a
/// glance, and one under the other where it is not.
class PairedCards extends StatelessWidget {
  const PairedCards({
    super.key,
    required this.first,
    required this.second,
    this.sameHeight = true,
    this.stackedGap = SettingsLayout.cardGap,
  });

  final Widget first;
  final Widget second;

  /// Side by side, the shorter card is stretched to the taller one's height.
  final bool sameHeight;

  /// What stands between them one under the other.
  final double stackedGap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < SettingsLayout.pairedCardsWidth) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            first,
            SizedBox(height: stackedGap),
            second,
          ],
        );
      }
      final row = Row(
        crossAxisAlignment: sameHeight ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: SettingsLayout.cardGap),
          Expanded(child: second),
        ],
      );
      return sameHeight ? IntrinsicHeight(child: row) : row;
    },
  );
}

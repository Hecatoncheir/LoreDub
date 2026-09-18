// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../theme.dart';

/// How long a line took from capture to voice, on the orange accent under
/// its bubble.
class LatencyBadge extends StatelessWidget {
  const LatencyBadge({super.key, required this.milliseconds});

  final int milliseconds;

  @override
  Widget build(BuildContext context) => Container(
    height: 22,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 11),
    decoration: BoxDecoration(
      color: LoreDubPalette.orange,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      AppLocalizations.of(context).latencyMs(milliseconds),
      // A fixed height with no leading keeps the label centred in the pill
      // instead of riding on the font's baseline.
      style: const TextStyle(
        fontFamily: LoreDubFonts.mono,
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        height: 1,
      ),
    ),
  );
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../live/transcript_card.dart';

/// What the frame gained as the game wrote in it, in the same card live
/// dubbing lists what it heard in.
class SubtitleList extends StatelessWidget {
  const SubtitleList({super.key});

  @override
  Widget build(BuildContext context) => TranscriptCard(
    number: '05',
    label: AppLocalizations.of(context).areaSubtitles,
    fromScreen: true,
    // The page scrolls; this area grows with the ten lines it keeps.
    fillsHeight: false,
  );
}

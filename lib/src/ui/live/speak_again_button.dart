// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../theme.dart';

/// Reads a line of the transcript again: it went by while the player was
/// looking at the game rather than at the list.
class SpeakAgainButton extends StatelessWidget {
  const SpeakAgainButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context).transcriptSpeakAgain,
    onPressed: onPressed,
    icon: const Icon(Icons.replay_rounded, size: 17),
    style: IconButton.styleFrom(
      foregroundColor: context.colors.mutedInk,
      minimumSize: const Size.square(LoreDubTargets.cross),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}

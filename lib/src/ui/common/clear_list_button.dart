// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../theme.dart';

/// Clears the list under a card's header.
class ClearListButton extends StatelessWidget {
  const ClearListButton({super.key, required this.tooltip, required this.onPressed});

  final String tooltip;

  /// Null when there is nothing to clear, so the button never claims work it
  /// will not do.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.backspace_outlined, size: 16),
      label: Text(AppLocalizations.of(context).transcriptClear),
      style: TextButton.styleFrom(
        foregroundColor: context.colors.mutedInk,
        minimumSize: const Size(0, 28),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(
          fontFamily: LoreDubFonts.mono,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    ),
  );
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../theme.dart';
import 'backend_cell_look.dart';

/// What a backend cell reads: its mark, the backend's name, and a size to
/// fetch or how far the fetch got -- shrunk to fit rather than cut.
class BackendCellLabel extends StatelessWidget {
  const BackendCellLabel({super.key, required this.label, required this.look, this.detail});

  final String label;
  final BackendCellLook look;
  final String? detail;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (look.icon case final icon?) ...[
              Icon(icon, size: 16, color: look.iconColour),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: LoreDubFonts.mono,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: look.ink,
              ),
            ),
            if (detail case final text?) ...[
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  fontFamily: LoreDubFonts.mono,
                  fontSize: 11,
                  color: look.ink.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

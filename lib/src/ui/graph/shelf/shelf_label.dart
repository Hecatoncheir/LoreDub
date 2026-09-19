// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../common/module_number.dart';

/// The shelf's own heading, in the vocabulary the screens' module labels
/// use -- except that the marking carries how many schemes are kept rather
/// than which area of the screen this is. There is one shelf, and the number
/// worth reading is the count.
class ShelfLabel extends StatelessWidget {
  const ShelfLabel({super.key, required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ModuleNumber('$count'),
      const SizedBox(width: 9),
      Text(
        label,
        style: const TextStyle(
          fontFamily: LoreDubFonts.mono,
          fontSize: 11,
          letterSpacing: 1.4,
          color: LoreDubPalette.ink,
        ),
      ),
    ],
  );
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../theme.dart';
import 'module_number.dart';

/// The number and name an area of a screen is known by: the numeral on
/// the orange accent, the name in capitals beside it.
class ModuleLabel extends StatelessWidget {
  const ModuleLabel({super.key, required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    // As wide as the number and the name, and no wider: given room to
    // spread — a heading that wraps — a row of its full width would leave
    // nothing to sit beside it.
    mainAxisSize: MainAxisSize.min,
    children: [
      ModuleNumber(number),
      const SizedBox(width: 9),
      // Cut rather than overflowed: a heading in a column narrower than its
      // own name is a heading that has to give way.
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: LoreDubFonts.mono,
            color: context.colors.ink,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ),
    ],
  );
}

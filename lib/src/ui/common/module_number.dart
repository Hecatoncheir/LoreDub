// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../theme.dart';

/// The numeral an area is known by, on the orange accent with an ink edge:
/// the mark every numbered heading of the interface starts with.
class ModuleNumber extends StatelessWidget {
  const ModuleNumber(this.number, {super.key});

  final String number;

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 22,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: LoreDubPalette.orange,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: LoreDubPalette.ink),
    ),
    child: Text(
      number,
      style: const TextStyle(
        fontFamily: LoreDubFonts.mono,
        color: LoreDubPalette.ink,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

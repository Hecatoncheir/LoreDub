// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../theme.dart';

/// What the screens under it are for. The six sections are two jobs -- the
/// dubbing itself, and everything that has to be ready before it -- and a
/// flat list of six made "Схема" look like as ordinary a way in as "Эфир".
///
/// It names the group and nothing else: the compact navigation indexes into
/// `DashboardSection.values` and has no room for a heading, so the grouping
/// is the wide window's alone.
class NavigationGroup extends StatelessWidget {
  const NavigationGroup({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 24, 8, 8),
    child: Text(
      label,
      style: TextStyle(
        fontFamily: LoreDubFonts.mono,
        color: context.colors.mutedInk,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    ),
  );
}

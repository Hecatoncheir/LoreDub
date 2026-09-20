// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../theme.dart';

/// What an empty pack says in place of what it holds.
class PackHint extends StatelessWidget {
  const PackHint({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
    child: Text(text, style: TextStyle(fontSize: 12, color: context.colors.mutedInk)),
  );
}

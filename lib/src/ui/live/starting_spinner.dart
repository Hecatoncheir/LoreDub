// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// How far a start has got, small enough to stand in a button's icon: a
/// ring that fills with [progress], or spins while there is none.
class StartingSpinner extends StatelessWidget {
  const StartingSpinner({super.key, this.progress});

  final double? progress;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(
      value: progress,
      strokeWidth: 2.4,
      color: Theme.of(context).colorScheme.onPrimary,
    ),
  );
}

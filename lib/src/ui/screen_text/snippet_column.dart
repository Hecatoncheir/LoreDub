// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import 'snapshot_history.dart';
import 'snippet_only_card.dart';

/// What the key picks out, and the list of what it has picked. The list
/// grows with what it holds to the ten lines worth seeing at once, and
/// scrolls inside itself past them.
class SnippetColumn extends StatelessWidget {
  const SnippetColumn({super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SnippetOnlyCard(),
      const SizedBox(height: 16),
      SnapshotHistory(),
    ],
  );
}

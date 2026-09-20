// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import 'screen_layout.dart';
import 'snapshot_history.dart';
import 'snippet_only_card.dart';

/// What the key picks out, and the list of what it has picked.
///
/// That list is a history rather than a running transcript -- the player
/// asked for every line in it -- so it keeps a height of its own and
/// scrolls inside it rather than growing the page without end.
class SnippetColumn extends StatelessWidget {
  const SnippetColumn({super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SnippetOnlyCard(),
      const SizedBox(height: 16),
      SizedBox(height: ScreenLayout.listHeight, child: SnapshotHistory()),
    ],
  );
}

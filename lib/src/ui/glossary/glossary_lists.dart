// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../domain/glossary.dart';
import '../../domain/glossary_view.dart';
import 'glossary_section.dart';

/// The three lists, one to a kind, in the order a line meets them: the
/// phrase answered before the model is asked, the name that replaces what it
/// left in Latin, the word laid over what it said.
class GlossaryLists extends StatelessWidget {
  const GlossaryLists({super.key, required this.view, required this.loaded});

  final GlossaryView view;
  final bool loaded;

  static const _order = [GlossaryKind.phrase, GlossaryKind.name, GlossaryKind.word];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (index, kind) in _order.indexed) ...[
        if (index > 0) const SizedBox(height: 16),
        GlossarySection(
          number: '0${index + 1}',
          kind: kind,
          entries: view.listed(kind),
          held: view.held(kind),
          loaded: loaded,
        ),
      ],
    ],
  );
}

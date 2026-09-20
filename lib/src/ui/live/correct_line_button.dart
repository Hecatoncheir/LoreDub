// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/pipeline_state.dart';
import '../../../l10n/app_localizations.dart';
import '../theme.dart';
import 'correct_line_dialog.dart';

/// Writes this line into the glossary as a phrase, with whatever the player
/// would rather have heard.
class CorrectLineButton extends StatelessWidget {
  const CorrectLineButton({super.key, required this.entry, required this.onCorrect});

  final TranscriptEntry entry;
  final void Function(TranscriptEntry entry, String reading, {bool silent}) onCorrect;

  Future<void> _ask(BuildContext context) async {
    final answer = await showDialog<LineCorrection>(
      context: context,
      builder: (context) => CorrectLineDialog(entry: entry),
    );
    if (answer == null) return;
    // A line the player would rather not hear again is written down with no
    // reading at all: that is what passes it over.
    if (answer.silent) {
      onCorrect(entry, '', silent: true);
      return;
    }
    final said = answer.reading.trim();
    // A reading left as it was heard is still written down. A phrase is
    // answered before the model is asked, so keeping what it said this time
    // pins the line -- the same words next time rather than the wandering
    // the model is free to do. Refusing it made a button that did nothing
    // and said nothing, which is how the player found it.
    if (said.isEmpty) return;
    onCorrect(entry, said);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2, left: 2),
    child: IconButton(
      key: ValueKey('transcript-correct-${entry.english}'),
      iconSize: 16,
      visualDensity: VisualDensity.compact,
      tooltip: AppLocalizations.of(context).transcriptCorrect,
      icon: Icon(Icons.edit_note_rounded, color: context.colors.mutedInk),
      onPressed: () => _ask(context),
    ),
  );
}

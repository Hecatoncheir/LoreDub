// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../domain/pipeline_state.dart';
import '../../../l10n/app_localizations.dart';
import '../theme.dart';

/// The correction itself.
///
/// A widget of its own rather than a controller held by the button: the
/// field outlives the call that opened it -- the dialog is still animating
/// out when [showDialog] returns -- so whoever owns it has to be disposed by
/// the framework rather than by hand.
class CorrectLineDialog extends StatefulWidget {
  const CorrectLineDialog({super.key, required this.entry});

  final TranscriptEntry entry;

  @override
  State<CorrectLineDialog> createState() => _CorrectLineDialogState();
}

class _CorrectLineDialogState extends State<CorrectLineDialog> {
  // Opened on what was said, not on an empty field: a correction is usually
  // a word of the line changed rather than a line rewritten.
  late final _reading = TextEditingController(text: widget.entry.translated);

  @override
  void dispose() {
    _reading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.transcriptCorrectTitle),
      content: SizedBox(
        // A dialog gives its content the width it asks for and no height at
        // all, so a field free to grow would stretch the column past the
        // screen. Three lines is a long line of dialogue and then some.
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.entry.english,
              style: TextStyle(color: context.colors.mutedInk, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('transcript-correction'),
              controller: _reading,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(labelText: l10n.glossaryPhraseReading),
              onSubmitted: (value) => Navigator.of(context).pop(LineCorrection(reading: value)),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.transcriptCorrectNote,
              style: TextStyle(color: context.colors.mutedInk, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.charactersDeleteCancel),
        ),
        // The line is worth writing down even when the answer is that it
        // should not be said at all.
        TextButton.icon(
          key: const ValueKey('transcript-correction-silence'),
          onPressed: () => Navigator.of(context).pop(const LineCorrection(silent: true)),
          icon: const Icon(Icons.volume_off_rounded, size: 18),
          label: Text(l10n.transcriptCorrectSilence),
          style: TextButton.styleFrom(foregroundColor: context.colors.mutedInk),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(LineCorrection(reading: _reading.text)),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// What the correction dialog answers with: the reading the player typed, or
/// the word that the line should not be said at all.
class LineCorrection {
  const LineCorrection({this.reading = '', this.silent = false});

  final String reading;
  final bool silent;
}

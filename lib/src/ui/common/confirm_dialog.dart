// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// Asks before something the player made is thrown away: a card, a pack, a
/// model, the voices a bank kept. The press that throws it away is the red
/// one, so a stray click lands on keeping it.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    title: Text(title),
    content: Text(message, style: const TextStyle(fontSize: 16, height: 1.4)),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: Text(cancelLabel),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Colors.white,
        ),
        child: Text(confirmLabel),
      ),
    ],
  );
}

/// Shows a [ConfirmDialog] and answers whether the player confirmed;
/// dismissing it is keeping what was there.
Future<bool> confirmRemoval(
  BuildContext context, {
  required String title,
  required String message,
  required String cancelLabel,
  required String confirmLabel,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: title,
        message: message,
        cancelLabel: cancelLabel,
        confirmLabel: confirmLabel,
      ),
    ) ??
    false;

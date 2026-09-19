// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// The dialog that asks for a name.
///
/// It owns the field's controller rather than being handed one: a dialog is
/// still on screen while it fades out, and a controller let go of the moment
/// the answer came back is one the field is still reading from — which ends
/// in a torn-down piece of the tree being asked what it depends on.
class NameDialog extends StatefulWidget {
  const NameDialog({super.key, required this.title, required this.action, required this.initial});

  final String title;
  final String action;
  final String initial;

  @override
  State<NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<NameDialog> {
  late final TextEditingController _field = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _answer([String? value]) => Navigator.of(context).pop((value ?? _field.text).trim());

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(controller: _field, autofocus: true, onSubmitted: _answer),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(AppLocalizations.of(context).pipelineSchemeCancel),
      ),
      FilledButton(onPressed: _answer, child: Text(widget.action)),
    ],
  );
}

/// Asks for a name in a dialog, and answers with it or with nothing.
Future<String?> askForName(
  BuildContext context, {
  required String title,
  required String action,
  String initial = '',
}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (context) => NameDialog(title: title, action: action, initial: initial),
  );
  return name == null || name.isEmpty ? null : name;
}

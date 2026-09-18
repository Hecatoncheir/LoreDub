// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// A name edited where it stands and written back only when the player is
/// done with it -- editing completed, or the pointer gone elsewhere -- rather
/// than on every keystroke: half a name is not a name, and every write may
/// reach a running worker.
///
/// A [value] changed elsewhere, an import landing on the card, is shown;
/// what is being typed is left alone. Text left empty or as it was is not
/// written.
class CommittedTextField extends StatefulWidget {
  const CommittedTextField({
    super.key,
    required this.value,
    required this.onCommitted,
    this.decoration = const InputDecoration(isDense: true),
    this.style,
  });

  final String value;
  final ValueChanged<String> onCommitted;
  final InputDecoration decoration;
  final TextStyle? style;

  @override
  State<CommittedTextField> createState() => _CommittedTextFieldState();
}

class _CommittedTextFieldState extends State<CommittedTextField> {
  late final _text = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(CommittedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && !_text.selection.isValid) {
      _text.text = widget.value;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _commit() {
    final written = _text.text.trim();
    if (written.isEmpty || written == widget.value) return;
    widget.onCommitted(written);
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _text,
    style: widget.style,
    decoration: widget.decoration,
    onEditingComplete: _commit,
    onTapOutside: (_) => _commit(),
  );
}

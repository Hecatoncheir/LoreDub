// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// The switch on a glossary node: its pack on or off, where the node stands.
///
/// Drawn small, at the foot of the card beside what the pack puts right, so
/// that muting a pack mid-scene is one click on the canvas rather than a
/// walk to its panel. A bare switch says nothing to a screen reader, so it
/// is named -- once: the tooltip, which says the same to the pointer, is
/// kept out of what is read.
class NodeActiveSwitch extends StatelessWidget {
  const NodeActiveSwitch({super.key, required this.active, required this.onChanged});

  final bool active;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context).pipelineGlossaryActive;
    return Semantics(
      label: label,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: SizedBox(
          width: 40,
          height: 24,
          child: FittedBox(
            child: Switch(value: active, onChanged: onChanged),
          ),
        ),
      ),
    );
  }
}

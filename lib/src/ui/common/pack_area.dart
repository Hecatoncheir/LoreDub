// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import 'ease.dart';
import '../../../l10n/app_localizations.dart';
import '../theme.dart';
import 'committed_text_field.dart';

/// One pack of either shelf -- the cast's or the glossary's: a named area
/// things of type [D] are dragged into, with its name to type in, how much it
/// holds, what is done to it, and what it holds below.
class PackArea<D extends Object> extends StatelessWidget {
  const PackArea({
    super.key,
    required this.name,
    required this.count,
    required this.onRename,
    required this.accepts,
    required this.onDrop,
    required this.child,
    this.trailing = const [],
    this.controls,
    this.active = false,
  });

  final String name;

  /// How much the pack holds, already said in words.
  final String count;
  final ValueChanged<String> onRename;

  /// Whether a dragged thing may be dropped here: one already in the pack is
  /// not offered a place in it again.
  final bool Function(D data) accepts;
  final ValueChanged<D> onDrop;

  /// What the pack holds, or what its being empty means.
  final Widget child;

  /// Buttons at the end of the name's row.
  final List<Widget> trailing;

  /// A row of its own under the name, for a pack whose buttons would leave
  /// the name field a few pixels wide beside it.
  final Widget? controls;

  /// The pack is switched on, and wears the orange edge a chosen thing
  /// wears elsewhere.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DragTarget<D>(
      onWillAcceptWithDetails: (details) => accepts(details.data),
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidate, _) {
        final inviting = candidate.isNotEmpty;
        final marked = inviting || active;
        return AnimatedContainer(
          duration: ease(context, 150),
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
          decoration: BoxDecoration(
            color: inviting ? context.colors.raised : context.colors.panel,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(
              color: marked ? context.colors.accent : context.colors.outline,
              width: marked ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CommittedTextField(
                      value: name,
                      onCommitted: onRename,
                      style: TextStyle(
                        fontFamily: LoreDubFonts.display,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(labelText: l10n.packsNameLabel, isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(count, style: context.textStyles.monoCaption),
                  ...trailing,
                ],
              ),
              ?controls,
              SizedBox(height: controls == null ? 10 : 4),
              child,
            ],
          ),
        );
      },
    );
  }
}

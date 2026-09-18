// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/glossary.dart';
import '../common/committed_text_field.dart';
import '../theme.dart';
import 'glossary_drag.dart';
import 'glossary_pack_controls.dart';
import 'glossary_pack_members.dart';

/// One pack: its name, how many entries it holds, whether the dubbing reads
/// it, and those entries as chips that can be dragged out again. An entry
/// dragged onto it is filed in it.
class GlossaryPackArea extends StatelessWidget {
  const GlossaryPackArea({
    super.key,
    required this.pack,
    required this.members,
    required this.held,
    required this.searching,
    required this.onRename,
    required this.onActive,
    required this.onExport,
    required this.onDelete,
    required this.onDrop,
    required this.onRemoveMember,
  });

  final GlossaryPack pack;

  /// What the pack shows: its entries, narrowed by the search when there is
  /// one.
  final List<GlossaryEntry> members;

  /// How many it actually holds, which the count says whatever is shown.
  final int held;
  final bool searching;
  final ValueChanged<String> onRename;
  final ValueChanged<bool> onActive;

  /// Null while the pack holds nothing worth writing to a file.
  final VoidCallback? onExport;
  final VoidCallback onDelete;
  final ValueChanged<GlossaryDrag> onDrop;
  final ValueChanged<GlossaryEntry> onRemoveMember;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DragTarget<GlossaryDrag>(
      // An entry already in this pack is not offered a place in it again.
      onWillAcceptWithDetails: (details) => !pack.holds(details.data.entry.packKey),
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidate, _) {
        final inviting = candidate.isNotEmpty;
        // An active pack wears the same orange edge a chosen thing wears
        // elsewhere: what is switched on is what the dubbing is reading.
        final marked = inviting || pack.active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
          decoration: BoxDecoration(
            color: inviting ? LoreDubPalette.raised : LoreDubPalette.panel,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(
              color: marked ? LoreDubPalette.orange : LoreDubPalette.outline,
              width: marked ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The name on one line and what is done to the pack on the
              // next: in the column beside the lists a single row would
              // leave the name field a few pixels wide.
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CommittedTextField(
                      value: pack.name,
                      onCommitted: onRename,
                      style: const TextStyle(
                        fontFamily: LoreDubFonts.display,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(labelText: l10n.packsNameLabel, isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.glossaryPackCount(held),
                    style: const TextStyle(
                      fontFamily: LoreDubFonts.mono,
                      fontSize: 11,
                      color: LoreDubPalette.mutedInk,
                    ),
                  ),
                ],
              ),
              GlossaryPackControls(
                pack: pack,
                onActive: onActive,
                onExport: onExport,
                onDelete: onDelete,
              ),
              const SizedBox(height: 4),
              GlossaryPackMembers(
                pack: pack,
                members: members,
                held: held,
                searching: searching,
                onRemoveMember: onRemoveMember,
              ),
            ],
          ),
        );
      },
    );
  }
}

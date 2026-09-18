// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/character.dart';
import '../theme.dart';
import '../common/committed_text_field.dart';
import 'character_drag.dart';
import 'character_pack_member.dart';
import '../models/model_action.dart';
import '../models/model_action_button.dart';

/// One pack: a named area cards are dropped into, exported from and taken
/// out of again.
///
/// The cards inside are drawn small — the whole card, with its name field
/// and buttons, already stands in the cast above; here what matters is who
/// is in the group.
class CharacterPackArea extends StatelessWidget {
  const CharacterPackArea({
    super.key,
    required this.pack,
    required this.members,
    required this.onRename,
    required this.onExport,
    required this.onDelete,
    required this.onDrop,
    required this.onRemoveMember,
  });

  final CharacterPack pack;
  final List<Character> members;
  final ValueChanged<String> onRename;

  /// Null while the pack holds no card that could be written.
  final VoidCallback? onExport;
  final VoidCallback onDelete;
  final ValueChanged<CharacterDrag> onDrop;
  final ValueChanged<Character> onRemoveMember;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DragTarget<CharacterDrag>(
      // A card already in this pack is not offered a place in it again.
      onWillAcceptWithDetails: (details) => !pack.holds(details.data.character.id),
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidate, _) {
        final inviting = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
          decoration: BoxDecoration(
            color: inviting ? LoreDubPalette.raised : LoreDubPalette.panel,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(
              color: inviting ? LoreDubPalette.orange : LoreDubPalette.outline,
              width: inviting ? 2 : 1,
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
                      value: pack.name,
                      onCommitted: onRename,
                      style: const TextStyle(
                        fontFamily: LoreDubFonts.display,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.packsNameLabel,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.packsCount(members.length),
                    style: const TextStyle(
                      fontFamily: LoreDubFonts.mono,
                      fontSize: 11,
                      color: LoreDubPalette.mutedInk,
                    ),
                  ),
                  ModelActionButton(
                    onDark: false,
                    action: ModelAction(
                      icon: Icons.file_upload_outlined,
                      tooltip: l10n.packsExportHint,
                      onPressed: onExport,
                    ),
                  ),
                  ModelActionButton(
                    onDark: false,
                    action: ModelAction(
                      icon: Icons.delete_outline_rounded,
                      tooltip: l10n.packsDelete,
                      onPressed: onDelete,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (members.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                  child: Text(
                    l10n.packsDropHint,
                    style: const TextStyle(
                      fontSize: 12,
                      color: LoreDubPalette.mutedInk,
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final member in members)
                      CharacterPackMember(
                        character: member,
                        packId: pack.id,
                        onRemove: () => onRemoveMember(member),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

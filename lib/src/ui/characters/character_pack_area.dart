// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/character.dart';
import '../common/pack_area.dart';
import '../common/pack_hint.dart';
import '../models/model_action.dart';
import '../models/model_action_button.dart';
import 'character_drag.dart';
import 'character_pack_member.dart';

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
    return PackArea<CharacterDrag>(
      name: pack.name,
      count: l10n.packsCount(members.length),
      onRename: onRename,
      accepts: (drag) => !pack.holds(drag.character.id),
      onDrop: onDrop,
      trailing: [
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
      child: members.isEmpty
          ? PackHint(text: l10n.packsDropHint)
          : Wrap(
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
    );
  }
}

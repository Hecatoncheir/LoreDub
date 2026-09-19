// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/character.dart';
import '../theme.dart';

/// The card's rarer actions, in the shape the schemes shelf keeps its own in:
/// write it to a file, file it in a pack, throw it away.
///
/// Filing is here as well as on the shelf's drop areas because dragging is
/// the one thing a keyboard cannot do: every pack a card can go into is named
/// in the menu, and the ones already holding it are shown and left out.
class CharacterCardMenu extends StatelessWidget {
  const CharacterCardMenu({
    super.key,
    required this.characterId,
    required this.onExport,
    required this.onDelete,
    this.packs = const [],
    this.onFileInPack,
  });

  final String characterId;
  final VoidCallback? onExport;
  final VoidCallback onDelete;

  /// Every pack on the shelf.
  final List<CharacterPack> packs;

  /// Files the card in the pack of that id. Null while nothing may be filed.
  final ValueChanged<String>? onFileInPack;

  static const _export = 'export';
  static const _delete = 'delete';
  static const _pack = 'pack:';

  void _chosen(String choice) {
    switch (choice) {
      case _export:
        onExport?.call();
      case _delete:
        onDelete();
      default:
        onFileInPack?.call(choice.substring(_pack.length));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      // Named, or a reader hears an unlabelled button beside two that say
      // what they do.
      tooltip: l10n.charactersCardMenu,
      icon: const Icon(Icons.more_horiz_rounded, size: 19),
      style: IconButton.styleFrom(
        foregroundColor: LoreDubPalette.ink,
        hoverColor: LoreDubPalette.orange.withValues(alpha: 0.18),
        minimumSize: const Size.square(LoreDubTargets.dense),
        fixedSize: const Size.square(LoreDubTargets.dense),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onSelected: _chosen,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _export,
          enabled: onExport != null,
          child: Text(l10n.charactersExportHint),
        ),
        for (final pack in packs)
          PopupMenuItem(
            value: '$_pack${pack.id}',
            enabled: onFileInPack != null && !pack.holds(characterId),
            child: Text(l10n.packsFileInto(pack.name)),
          ),
        PopupMenuItem(value: _delete, child: Text(l10n.charactersDelete)),
      ],
    );
  }
}

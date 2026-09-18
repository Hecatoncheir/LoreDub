// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/glossary.dart';
import '../theme.dart';
import 'glossary_packed_entry.dart';

/// The entries a pack shows, as chips that can be dragged out again -- or,
/// with none shown, what that means: an empty pack asks to be filled, and
/// one whose entries the search hid says so instead, or the player would
/// read it as empty.
class GlossaryPackMembers extends StatelessWidget {
  const GlossaryPackMembers({
    super.key,
    required this.pack,
    required this.members,
    required this.held,
    required this.searching,
    required this.onRemoveMember,
  });

  final GlossaryPack pack;
  final List<GlossaryEntry> members;
  final int held;
  final bool searching;
  final ValueChanged<GlossaryEntry> onRemoveMember;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (members.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
        child: Text(
          searching && held > 0 ? l10n.glossaryPackNothingFound : l10n.glossaryPackDropHint,
          style: const TextStyle(fontSize: 12, color: LoreDubPalette.mutedInk),
        ),
      );
    }
    // A Wrap gives its children all the room they ask for, and a phrase asks
    // for the whole of itself: without a cap the chips run off the side of
    // the card.
    return LayoutBuilder(
      builder: (context, room) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final member in members)
            GlossaryPackedEntry(
              entry: member,
              packId: pack.id,
              maxWidth: room.maxWidth,
              onRemove: () => onRemoveMember(member),
            ),
        ],
      ),
    );
  }
}

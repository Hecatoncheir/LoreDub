// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/glossary.dart';
import '../common/pack_area.dart';
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
  Widget build(BuildContext context) => PackArea<GlossaryDrag>(
    name: pack.name,
    count: AppLocalizations.of(context).glossaryPackCount(held),
    onRename: onRename,
    accepts: (drag) => !pack.holds(drag.entry.packKey),
    onDrop: onDrop,
    active: pack.active,
    // The name on one line and what is done to the pack on the next: in the
    // column beside the lists a single row would leave the name field a few
    // pixels wide.
    controls: GlossaryPackControls(
      pack: pack,
      onActive: onActive,
      onExport: onExport,
      onDelete: onDelete,
    ),
    child: GlossaryPackMembers(
      pack: pack,
      members: members,
      held: held,
      searching: searching,
      onRemoveMember: onRemoveMember,
    ),
  );
}

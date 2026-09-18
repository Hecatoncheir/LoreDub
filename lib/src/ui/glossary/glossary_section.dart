// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/glossary.dart';
import '../theme.dart';
import '../dashboard/cubits/glossary_cubit.dart';
import 'glossary_kind_texts.dart';
import 'glossary_add_row.dart';
import 'glossary_entry_row.dart';
import 'glossary_heading.dart';

/// One list of the glossary: its heading and note, its entries edited where
/// they stand, and the empty line at its foot that becomes the next one.
class GlossarySection extends StatelessWidget {
  const GlossarySection({
    super.key,
    required this.number,
    required this.kind,
    required this.entries,
    required this.held,
    required this.loaded,
  });

  final String number;
  final GlossaryKind kind;

  /// What the list shows: its entries, narrowed by the search and the
  /// presets.
  final List<GlossaryEntry> entries;

  /// How many are written down, whatever is shown of them, which is what
  /// tells a list with nothing in it from one narrowed to nothing.
  final int held;
  final bool loaded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final texts = GlossaryKindTexts.of(l10n, kind);
    final glossary = context.read<GlossaryCubit>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlossaryHeading(number: number, label: texts.label),
            const SizedBox(height: 10),
            Text(
              texts.note,
              style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
            ),
            const SizedBox(height: 14),
            if (loaded && entries.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  // A list with nothing in it says so; one whose entries the
                  // search or a preset hid says that instead, as a pack does.
                  // "In no pack" is on to begin with, so names filed in a
                  // game's pack would open on "nothing here yet" -- and one
                  // written under a narrowed list, hidden the moment it is
                  // kept, would read as not having been written.
                  held > 0 ? l10n.glossaryAllHidden : l10n.glossaryEmpty,
                  style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
                ),
              ),
            for (final entry in entries)
              GlossaryEntryRow(
                // By what it matches on: an entry being edited keeps its
                // field while the reading beside it is typed, and a source
                // renamed is a different entry.
                key: ValueKey('${kind.name}:${entry.key}'),
                entry: entry,
                sourceLabel: texts.sourceLabel,
                readingLabel: texts.readingLabel,
                onWrite: (written) => glossary.write(written),
                onRemove: () => glossary.remove(kind, entry.source),
              ),
            const SizedBox(height: 6),
            GlossaryAddRow(
              kind: kind,
              sourceLabel: texts.sourceLabel,
              readingLabel: texts.readingLabel,
              onWrite: (written) => glossary.write(written),
            ),
          ],
        ),
      ),
    );
  }
}

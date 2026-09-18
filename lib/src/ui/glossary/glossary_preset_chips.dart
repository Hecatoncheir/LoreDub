// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/glossary_view.dart';

/// Two ready answers to questions the player asks often enough to deserve a
/// press rather than a typed word: only what no pack holds, only what is
/// passed over.
class GlossaryPresetChips extends StatelessWidget {
  const GlossaryPresetChips({super.key, required this.filter, required this.onChanged});

  final GlossaryFilter filter;
  final ValueChanged<GlossaryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          FilterChip(
            key: const ValueKey('glossary-preset-loose'),
            label: Text(l10n.glossaryOnlyLoose),
            selected: filter.looseOnly,
            onSelected: (value) => onChanged(filter.copyWith(looseOnly: value)),
            showCheckmark: true,
            visualDensity: VisualDensity.compact,
          ),
          FilterChip(
            key: const ValueKey('glossary-preset-silent'),
            label: Text(l10n.glossaryOnlySilent),
            selected: filter.silentOnly,
            onSelected: (value) => onChanged(filter.copyWith(silentOnly: value)),
            showCheckmark: true,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

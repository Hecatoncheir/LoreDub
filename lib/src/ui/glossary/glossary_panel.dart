// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/glossary.dart';
import '../../domain/glossary_view.dart';
import '../dashboard/cubits/glossary_cubit.dart';
import 'glossary_layout.dart';
import 'glossary_lists.dart';
import 'glossary_packs_section.dart';
import 'glossary_preset_chips.dart';
import 'glossary_toolbar.dart';

/// The screen where the player writes down what the dubbing cannot know.
///
/// Three lists rather than one, because the entries reach a line at
/// different moments and behave differently: a phrase is answered before the
/// model is asked at all, a name only replaces what the model left in Latin
/// script, and a word is matched on what was said. Kept apart so that none is
/// expected to do another's work.
class GlossaryPanel extends StatefulWidget {
  const GlossaryPanel({super.key});

  @override
  State<GlossaryPanel> createState() => _GlossaryPanelState();
}

class _GlossaryPanelState extends State<GlossaryPanel> {
  static const _json = [
    XTypeGroup(label: 'LoreDub', extensions: ['json']),
  ];

  var _filter = const GlossaryFilter();

  Future<void> _export() async {
    final glossary = context.read<GlossaryCubit>();
    final location = await getSaveLocation(
      suggestedName: 'loredub-glossary.json',
      acceptedTypeGroups: _json,
    );
    if (location == null) return;
    await glossary.export(location.path);
  }

  /// A pack read back is merged the way the whole glossary is -- the entries
  /// it carries join the lists, and the grouping joins the shelf -- so one
  /// import serves both.
  Future<void> _import() async {
    final glossary = context.read<GlossaryCubit>();
    final chosen = await openFiles(acceptedTypeGroups: _json);
    if (chosen.isEmpty) return;
    await glossary.import([for (final file in chosen) file.path]);
  }

  Future<void> _exportPack(GlossaryPack pack) async {
    final glossary = context.read<GlossaryCubit>();
    final name = pack.name.trim().isEmpty ? 'pack' : pack.name.trim();
    final location = await getSaveLocation(
      suggestedName: 'loredub-$name.json',
      acceptedTypeGroups: _json,
    );
    if (location == null) return;
    await glossary.exportPack(location.path, pack.id);
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<GlossaryCubit, GlossaryState>(
    builder: (context, state) {
      final view = GlossaryView(state.glossary, _filter);
      final lists = GlossaryLists(view: view, loaded: state.loaded);
      final packs = GlossaryPacksSection(
        view: view,
        onImport: _import,
        onExport: _exportPack,
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
        child: ListView(
          key: const ValueKey('glossaryList'),
          padding: EdgeInsets.zero,
          children: [
            GlossaryToolbar(
              searching: _filter.searching,
              canExport: !state.glossary.isEmpty,
              onSearch: (looking) => setState(() => _filter = _filter.copyWith(looking: looking)),
              onImport: _import,
              onExport: _export,
            ),
            GlossaryPresetChips(
              filter: _filter,
              onChanged: (filter) => setState(() => _filter = filter),
            ),
            // The packs stand beside the lists where there is room for both:
            // a pack is chosen while looking at what goes into it, and under
            // three long lists it would be a scroll away from them. A narrow
            // window puts it back underneath, where a column of its own would
            // leave neither side readable.
            LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth < GlossaryLayout.packsBesideListsWidth
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [lists, const SizedBox(height: 16), packs],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: lists),
                        const SizedBox(width: 16),
                        SizedBox(width: GlossaryLayout.packsWidth, child: packs),
                      ],
                    ),
            ),
          ],
        ),
      );
    },
  );
}

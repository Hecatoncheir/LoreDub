// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../common/file_dialogs.dart';
import '../../domain/glossary.dart';
import '../../domain/glossary_view.dart';
import '../dashboard/cubits/glossary_bloc.dart';
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
  var _filter = const GlossaryFilter();

  Future<void> _export() async {
    final glossary = context.read<GlossaryBloc>();
    final location = await context.read<FileDialogs>().saveJson('loredub-glossary.json');
    if (location == null) return;
    glossary.add(GlossaryExported(location));
  }

  /// A pack read back is merged the way the whole glossary is -- the entries
  /// it carries join the lists, and the grouping joins the shelf -- so one
  /// import serves both. What was read is said by [_sayImported], as it is
  /// for the cast: a file that brought nothing new otherwise looks like one
  /// never opened.
  Future<void> _import() async {
    final glossary = context.read<GlossaryBloc>();
    final chosen = await context.read<FileDialogs>().openJson();
    if (chosen.isEmpty) return;
    glossary.add(GlossaryFilesImported(chosen));
  }

  void _sayImported(BuildContext context, GlossaryState state) {
    final read = state.lastImport;
    if (read == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).glossaryImported(read.entries, read.packs)),
      ),
    );
  }

  Future<void> _exportPack(GlossaryPack pack) async {
    final glossary = context.read<GlossaryBloc>();
    final name = pack.name.trim().isEmpty ? 'pack' : pack.name.trim();
    final location = await context.read<FileDialogs>().saveJson('loredub-$name.json');
    if (location == null) return;
    glossary.add(GlossaryPackExported(location, pack.id));
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<GlossaryBloc, GlossaryState>(
    // Once for each import, however much it held.
    listenWhen: (was, now) => was.lastImport != now.lastImport,
    listener: _sayImported,
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

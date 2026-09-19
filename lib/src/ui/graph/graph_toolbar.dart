// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../common/ease.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../common/file_dialogs.dart';
import '../../domain/pipeline_graph.dart';
import '../../../l10n/app_localizations.dart';
import '../theme.dart';
import '../dashboard/cubits/pipeline_cubit.dart';
import '../dashboard/cubits/pipeline_graph_bloc.dart';
import 'shelf/pipeline_shelf.dart';
import 'canvas/connection_messages.dart';
import 'canvas/pipeline_facts.dart';
import 'shelf/name_dialog.dart';

/// The presets, the steps back, and the cards waiting to be put on the
/// canvas. Under them, whatever the last attempt at a link came to.
class GraphToolbar extends StatelessWidget {
  const GraphToolbar({super.key, required this.state, required this.facts});

  final PipelineGraphState state;
  final PipelineFacts facts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // How the canvas is worked, on the row the buttons that work
                // it are on: the two chips that used to stand here picked
                // between the audio route and the subtitles, and the screen
                // is read on its own page now. Whatever the last attempt at
                // a link came to takes the same place, so a refusal is read
                // where the hand already is.
                Expanded(
                  child: AnimatedSwitcher(
                    duration: ease(context, 180),
                    child: switch (state.refusal) {
                      final refusal? => Text(
                        describeConnectionRefusal(l10n, refusal),
                        key: ValueKey(refusal),
                        style: const TextStyle(fontSize: 12, color: LoreDubPalette.error),
                      ),
                      _ => Text(
                        l10n.pipelineGraphHint,
                        key: const ValueKey('hint'),
                        style: const TextStyle(fontSize: 12, color: LoreDubPalette.mutedInk),
                      ),
                    },
                  ),
                ),
                const SizedBox(width: 12),
                _addCharacter(context, l10n),
                // The session is rested from here as well as from Live: the
                // cast is rewired on this screen, and walking to another one
                // to stop the dubbing first is a walk for nothing.
                if (facts.running) ...[
                  IconButton(
                    key: const ValueKey('graphPause'),
                    tooltip: facts.paused ? l10n.resumeDubbing : l10n.pauseHint,
                    icon: Icon(
                      facts.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 20,
                      color: facts.paused ? LoreDubPalette.orange : null,
                    ),
                    onPressed: facts.paused
                        ? context.read<PipelineCubit>().resume
                        : context.read<PipelineCubit>().pause,
                  ),
                  IconButton(
                    key: const ValueKey('graphStop'),
                    tooltip: l10n.stopDubbing,
                    icon: const Icon(Icons.stop_rounded, size: 20),
                    onPressed: context.read<PipelineCubit>().stop,
                  ),
                ],
                IconButton(
                  tooltip: l10n.pipelineSaveScheme,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 20),
                  onPressed: () => _saveScheme(context, l10n),
                ),
                IconButton(
                  tooltip: l10n.pipelineSchemeImport,
                  icon: const Icon(Icons.file_open_outlined, size: 20),
                  onPressed: () => _importScheme(context),
                ),
                IconButton(
                  tooltip: l10n.pipelineResetLayout,
                  icon: const Icon(Icons.grid_view_rounded, size: 20),
                  onPressed: () =>
                      context.read<PipelineGraphBloc>().add(const PipelineLayoutReset()),
                ),
                IconButton(
                  tooltip: l10n.pipelineUndo,
                  icon: const Icon(Icons.undo_rounded, size: 20),
                  onPressed: state.canUndo
                      ? () => context.read<PipelineGraphBloc>().add(const PipelineGraphUndone())
                      : null,
                ),
                IconButton(
                  tooltip: l10n.pipelineRedo,
                  icon: const Icon(Icons.redo_rounded, size: 20),
                  onPressed: state.canRedo
                      ? () => context.read<PipelineGraphBloc>().add(const PipelineGraphRedone())
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            // The shelf of kept schemes, each with a picture of itself: a
            // click puts it on the canvas and it is the one that runs. It is
            // folded away until asked for — the canvas is what the screen is
            // for, and a shelf of pictures would take the top of it every
            // time the screen is opened.
            PipelineShelf(
              schemes: state.schemes,
              cast: facts.characters,
              onChoose: (id) => context.read<PipelineGraphBloc>().add(PipelineSchemeChosen(id)),
              onReplace: (id) => context.read<PipelineGraphBloc>().add(PipelineSchemeReplaced(id)),
              onRename: (id, name) =>
                  context.read<PipelineGraphBloc>().add(PipelineSchemeRenamed(id, name)),
              onRemove: (id) => context.read<PipelineGraphBloc>().add(PipelineSchemeRemoved(id)),
              onExport: (id) => _exportScheme(context, id),
            ),
          ],
        ),
      ),
    );
  }

  /// Keeps the scheme as it stands, under a name the player types.
  Future<void> _saveScheme(BuildContext context, AppLocalizations l10n) async {
    final graph = context.read<PipelineGraphBloc>();
    final name = await askForName(
      context,
      title: l10n.pipelineSchemeName,
      action: l10n.pipelineSaveScheme,
      initial: l10n.pipelineSchemeNew,
    );
    if (name != null) graph.add(PipelineSchemeSaved(name));
  }

  Future<void> _exportScheme(BuildContext context, String id) async {
    final graph = context.read<PipelineGraphBloc>();
    final scheme = state.schemes.where((value) => value.id == id).firstOrNull;
    if (scheme == null) return;
    final destination = await context.read<FileDialogs>().saveJson(
      '${scheme.name}.loredub-scheme.json',
    );
    if (destination == null) return;
    graph.add(PipelineSchemeExported(id, destination));
  }

  Future<void> _importScheme(BuildContext context) async {
    final graph = context.read<PipelineGraphBloc>();
    final files = await context.read<FileDialogs>().openJson();
    if (files.isEmpty) return;
    graph.add(PipelineSchemeImported(files));
  }

  /// Every card of the cast, drawn or not: a card already on the canvas can
  /// be drawn again beside the character whose part it takes over, and the
  /// count beside its name says how many of it are there.
  Widget _addCharacter(BuildContext context, AppLocalizations l10n) {
    final drawn = <String, int>{};
    for (final node in state.graph.ofKind(PipelineNodeKind.character)) {
      drawn.update(node.characterId ?? '', (count) => count + 1, ifAbsent: () => 1);
    }
    return PopupMenuButton<String>(
      tooltip: facts.characters.isEmpty ? l10n.pipelineNoCharacters : l10n.pipelineAddCharacter,
      enabled: facts.characters.isNotEmpty,
      icon: const Icon(Icons.person_add_alt_rounded, size: 20),
      onSelected: (id) => context.read<PipelineGraphBloc>().add(PipelineCharacterPlaced(id)),
      itemBuilder: (context) => [
        for (final character in facts.characters)
          PopupMenuItem(
            value: character.id,
            child: Row(
              children: [
                Expanded(child: Text(character.name)),
                if (drawn[character.id] case final count?)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      '×$count',
                      style: const TextStyle(
                        fontFamily: LoreDubFonts.mono,
                        fontSize: 11,
                        color: LoreDubPalette.mutedInk,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

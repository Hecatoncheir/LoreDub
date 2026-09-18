// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/compute_device.dart';
import '../../domain/model_selection.dart';
import '../../domain/pipeline_graph.dart';
import '../../domain/pipeline_state.dart';
import '../../../l10n/app_localizations.dart';
import '../failure_messages.dart';
import '../theme.dart';
import 'cubits/characters_cubit.dart';
import 'cubits/dashboard_cubits.dart';
import 'cubits/downloads_cubit.dart';
import 'cubits/pipeline_cubit.dart';
import 'cubits/pipeline_graph_bloc.dart';
import 'cubits/settings_cubit.dart';
import 'cubits/shell_cubit.dart';
import 'glossary_screen.dart';
import 'dashboard_context.dart';
import 'pipeline_canvas.dart';
import 'pipeline_inspector.dart';
import 'pipeline_shelf.dart';
import '../common/error_banner.dart';
import '../shell/side_navigation.dart';
import '../shell/bottom_navigation.dart';
import '../shell/dashboard_header.dart';
import '../live/live_panel.dart';
import '../screen_text/snapshot_panel.dart';
import '../characters/characters_panel.dart';
import '../models/models_panel.dart';
import '../settings/settings_panel.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key, required this.cubits});

  final DashboardCubits cubits;

  /// Everything below reads the cubits it needs off the context, so a
  /// widget's dependencies are the providers it looks up rather than one bag
  /// handed down through every constructor.
  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider.value(value: cubits.shell),
      BlocProvider.value(value: cubits.settings),
      BlocProvider.value(value: cubits.downloads),
      BlocProvider.value(value: cubits.pipeline),
      BlocProvider.value(value: cubits.characters),
      BlocProvider.value(value: cubits.glossary),
      BlocProvider.value(value: cubits.graph),
    ],
    child: const _Dashboard(),
  );
}

class _Dashboard extends StatelessWidget {
  const _Dashboard();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final content = SafeArea(
          child: Column(
            children: [
              DashboardHeader(),
              BlocBuilder<ShellCubit, ShellState>(
                builder: (context, shell) => switch (shell.error) {
                  final error? => ErrorBanner(
                    message: describeFailure(AppLocalizations.of(context), error),
                  ),
                  _ => const SizedBox.shrink(),
                },
              ),
              Expanded(
                child: BlocBuilder<ShellCubit, ShellState>(
                  builder: (context, shell) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: switch (shell.section) {
                      DashboardSection.live => LivePanel(
                        key: const ValueKey('live'),
                      ),
                      DashboardSection.pipeline => _PipelinePanel(
                        key: const ValueKey('pipeline'),
                      ),
                      DashboardSection.snapshot => SnapshotPanel(
                        key: const ValueKey('snapshot'),
                      ),
                      DashboardSection.models => ModelsPanel(
                        key: const ValueKey('models'),
                      ),
                      DashboardSection.characters => CharactersPanel(
                        key: const ValueKey('characters'),
                      ),
                      DashboardSection.glossary => GlossaryPanel(
                        key: const ValueKey('glossary'),
                      ),
                      DashboardSection.settings => SettingsPanel(
                        key: const ValueKey('settings'),
                      ),
                    },
                  ),
                ),
              ),
            ],
          ),
        );
        if (compact) {
          return Column(
            children: [
              Expanded(child: content),
              BottomNavigation(),
            ],
          );
        }
        return Row(
          children: [
            SideNavigation(),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        );
      },
    ),
  );
}

/// The pipeline as a scheme: the stages as nodes, the route between them,
/// and the cards of the cast that take a voice from one another.
///
/// Nothing is configured here that is not configured elsewhere. The canvas
/// is drawn from the settings and the cast, and every link the player draws
/// is turned straight back into one of them, so the scheme and the screens
/// can never say different things.
class _PipelinePanel extends StatelessWidget {
  const _PipelinePanel({super.key});

  /// The scheme is listened to innermost, under everything it is drawn
  /// from. A pan or a dragged node is a new graph state every frame, and
  /// with that listener on the outside each of those frames built a fresh
  /// `ModelSelection` and `PipelineFacts` and handed the canvas cards it
  /// could tell apart from the ones it already had. Under them, what the
  /// scheme is drawn from keeps the instance it had between edits.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
    child: BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settings) => BlocBuilder<DownloadsCubit, DownloadsState>(
        // What is on disk and what the machine can run it on. A download
        // ticking must not redraw the scheme.
        buildWhen: whenChanged((downloads) => downloads.installed),
        builder: (context, downloads) => BlocBuilder<PipelineCubit, LivePipelineState>(
          buildWhen: whenChanged(
            (pipeline) => (
              pipeline.running,
              pipeline.status,
              pipeline.selectedProcess,
              pipeline.processes,
              pipeline.backendSignature,
            ),
          ),
          builder: (context, pipeline) => BlocBuilder<CharactersCubit, CharactersState>(
            buildWhen: whenChanged((characters) => (characters.characters, characters.running)),
            builder: (context, characters) {
              final facts = PipelineFacts(
                settings: settings.settings,
                selection: ModelSelection(models: downloads.models, settings: settings.settings),
                process: pipeline.selectedProcess,
                characters: characters.characters,
                activeBackends: pipeline.activeBackends,
                running: pipeline.running,
                paused: pipeline.status == PipelineStatus.paused,
                recordingVoice: characters.running,
              );
              return _build(context, availability: downloads.availability, facts: facts);
            },
          ),
        ),
      ),
    ),
  );

  /// Whether the toolbar would draw itself differently. It reads what can
  /// be undone, what a link came to, the schemes kept and which cards are on
  /// the canvas: panning the scheme or dragging a node is none of those, and
  /// both of those are a new state on every frame.
  static bool _toolbarChanged(PipelineGraphState was, PipelineGraphState now) {
    if (was.canUndo != now.canUndo ||
        was.canRedo != now.canRedo ||
        was.refusal != now.refusal ||
        !identical(was.schemes, now.schemes)) {
      return true;
    }
    final before = was.graph.ofKind(PipelineNodeKind.character);
    final after = now.graph.ofKind(PipelineNodeKind.character);
    if (before.length != after.length) return true;
    for (var index = 0; index < after.length; index++) {
      if (before[index].characterId != after[index].characterId) return true;
    }
    return false;
  }

  Widget _build(
    BuildContext context, {
    required PipelineFacts facts,
    required ComputeAvailability availability,
  }) {
    return Column(
      children: [
        // Two listeners rather than one over the pair: the canvas answers
        // every frame of a drag, and the toolbar has no business being
        // built again for it.
        BlocBuilder<PipelineGraphBloc, PipelineGraphState>(
          buildWhen: _toolbarChanged,
          builder: (context, graph) => _GraphToolbar(state: graph, facts: facts),
        ),
        const SizedBox(height: 12),
        // The panel floats over the canvas rather than beside it: opening it
        // must not move the scheme out from under the pointer that opened it.
        Expanded(
          child: BlocBuilder<PipelineGraphBloc, PipelineGraphState>(
            builder: (context, graph) => _scheme(context, graph, facts, availability),
          ),
        ),
      ],
    );
  }

  Widget _scheme(
    BuildContext context,
    PipelineGraphState graph,
    PipelineFacts facts,
    ComputeAvailability availability,
  ) {
    final selected = graph.selectedNode;
    // One card holds the scheme and the panel over it, and it clips: the
    // panel comes out from under the frame the scheme is drawn in rather
    // than past it. Standing beside the card the panel slid in from
    // somewhere to the right of the editing area, which is a place the
    // screen has not got.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: PipelineCanvas(
              bloc: context.read<PipelineGraphBloc>(),
              state: graph,
              facts: facts,
              availability: availability,
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: _InspectorSlot(
              panel: selected == null
                  ? null
                  : PipelineInspector(
                      key: ValueKey(selected.id),
                      node: selected,
                      facts: facts,
                      availability: availability,
                      chained: graph.graph.chained,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The panel down the right edge of the canvas, coming and going.
///
/// It travels its own whole width, so the edge it comes out from under is
/// the frame of the editing area: the card the scheme is drawn in clips it,
/// and until it is out it is under that frame rather than beside it.
///
/// Which curve carries it is decided here rather than left to the switcher,
/// because [AnimatedSwitcher] hands a panel its curves once, as that panel
/// is made. Another node is another panel, keyed by the node so the switcher
/// sees it as one, and those two take turns rather than crossing: the panel
/// of the node let go of leaves over the half of the run that is its own,
/// and the one clicked comes in over the other half. A panel opening on a
/// canvas with nothing on it has nobody to wait for, and waiting all the
/// same is what made the first click read as a click that missed.
class _InspectorSlot extends StatefulWidget {
  const _InspectorSlot({required this.panel});

  /// The panel of the chosen node, or nothing while no node is chosen.
  final Widget? panel;

  @override
  State<_InspectorSlot> createState() => _InspectorSlotState();
}

class _InspectorSlotState extends State<_InspectorSlot> {
  /// Half of this is what a panel has to itself when it takes turns with
  /// another; a panel with the canvas to itself travels for all of it.
  static const _run = Duration(milliseconds: 360);

  /// The half of the run a panel waits out before it comes in, when there
  /// is one leaving ahead of it.
  static const _behind = Interval(0.5, 1, curve: Curves.easeOutCubic);

  /// A panel's own curve is run backwards as it leaves, so the back half of
  /// the range is the front half of the leaving: it is gone by the time the
  /// panel replacing it starts to move.
  static const _leaving = Interval(0.5, 1, curve: Curves.easeInCubic);

  /// Whether the panel now coming in has one to wait for.
  bool _behindAnother = false;

  @override
  void didUpdateWidget(covariant _InspectorSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _behindAnother = oldWidget.panel != null && widget.panel != null;
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: _run,
    switchInCurve: _behindAnother ? _behind : Curves.easeOutCubic,
    switchOutCurve: _leaving,
    transitionBuilder: (child, animation) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(animation),
      // Solid for all but the first third of the way out, while it is
      // still mostly under the frame: the panel slides rather than fades,
      // and the fade is here to take the shadow it casts on the scheme off
      // the canvas with it rather than to be seen. At full strength that
      // shadow stands at the edge of the canvas for as long as the panel is
      // held there, and then goes out all at once.
      child: FadeTransition(
        opacity: CurveTween(curve: const Interval(0, 0.35)).animate(animation),
        child: child,
      ),
    ),
    child: widget.panel,
  );
}

/// The presets, the steps back, and the cards waiting to be put on the
/// canvas. Under them, whatever the last attempt at a link came to.
class _GraphToolbar extends StatelessWidget {
  const _GraphToolbar({required this.state, required this.facts});

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
                    duration: const Duration(milliseconds: 180),
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
    final destination = await getSaveLocation(
      suggestedName: '${scheme.name}.loredub-scheme.json',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'LoreDub', extensions: ['json']),
      ],
    );
    if (destination == null) return;
    graph.add(PipelineSchemeExported(id, destination.path));
  }

  Future<void> _importScheme(BuildContext context) async {
    final graph = context.read<PipelineGraphBloc>();
    final files = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'LoreDub', extensions: ['json']),
      ],
    );
    if (files.isEmpty) return;
    graph.add(PipelineSchemeImported([for (final file in files) file.path]));
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

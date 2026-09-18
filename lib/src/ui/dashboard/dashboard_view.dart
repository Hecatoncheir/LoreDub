// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/app_settings.dart';
import '../../domain/character.dart';
import '../../domain/compute_device.dart';
import '../../domain/model_package.dart';
import '../../domain/model_proxy.dart';
import '../../domain/model_selection.dart';
import '../../domain/pipeline_graph.dart';
import '../../domain/runtime_paths.dart';
import '../../domain/pipeline_state.dart';
import '../../domain/spoken_language.dart';
import '../../../l10n/app_localizations.dart';
import '../compute_names.dart';
import '../failure_messages.dart';
import '../language_names.dart';
import '../model_names.dart';
import '../theme.dart';
import 'cubits/characters_cubit.dart';
import 'cubits/dashboard_cubits.dart';
import 'cubits/downloads_cubit.dart';
import 'cubits/pipeline_cubit.dart';
import 'cubits/pipeline_graph_bloc.dart';
import 'cubits/settings_cubit.dart';
import 'cubits/shell_cubit.dart';
import 'character_tiles.dart';
import 'glossary_screen.dart';
import 'compute_matrix.dart';
import 'dashboard_context.dart';
import 'hotkey_field.dart';
import 'model_tiles.dart';
import 'model_visuals.dart';
import 'process_picker.dart';
import 'pipeline_canvas.dart';
import 'pipeline_inspector.dart';
import 'pipeline_shelf.dart';
import 'whisper_model_chart.dart';
import '../common/module_label.dart';
import '../common/area_heading.dart';
import '../common/setting_card.dart';
import '../common/section_note.dart';
import '../common/error_banner.dart';
import '../common/language_row.dart';
import '../shell/side_navigation.dart';
import '../shell/bottom_navigation.dart';
import '../shell/dashboard_header.dart';
import '../live/live_panel.dart';
import '../live/models_needed_notice.dart';
import '../screen_text/snapshot_panel.dart';

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
                      DashboardSection.models => _ModelsPanel(
                        key: const ValueKey('models'),
                      ),
                      DashboardSection.characters => _CharactersPanel(
                        key: const ValueKey('characters'),
                      ),
                      DashboardSection.glossary => GlossaryPanel(
                        key: const ValueKey('glossary'),
                      ),
                      DashboardSection.settings => _SettingsPanel(
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

/// Beyond this two setting cards stand side by side rather than one under
/// the other. Below it a slider and its own notes would be squeezed.
const _pairedCardsWidth = 900.0;

/// The characters screen: the player's cast, and the session their voices
/// are recorded through.
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

class _CharactersPanel extends StatelessWidget {
  const _CharactersPanel({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
    child: Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ModuleLabel(
                  number: '01',
                  label: AppLocalizations.of(context).areaVoiceRecording,
                ),
                const SizedBox(height: 14),
                _CharacterSessionControls(),
              ],
            ),
          ),
        ),
        ModelsNeededNotice(
          ready: (selection) => selection.voiceConverter?.installed ?? false,
        ),
        const SizedBox(height: 16),
        // The cast on the left, the packs beside it on the right: a card is
        // carried across rather than down a scroll, and both ends of the
        // journey stay in sight the whole way. A window too narrow to hold
        // the two side by side puts the packs back underneath, where a drag
        // is longer but possible.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < _packsBeside
                ? ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _CharacterCast(),
                      const SizedBox(height: 16),
                      _CharacterPacks(),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Each side scrolls on its own, so reaching for a pack
                      // does not move the cards under the pointer.
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [_CharacterCast()],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: (constraints.maxWidth * 0.36).clamp(340.0, 480.0),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [_CharacterPacks()],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    ),
  );
}

/// How much room the characters screen needs before the packs stand beside
/// the cast rather than under it: two columns of cards, and the gap.
const _packsBeside = 880.0;

/// Which game to listen to, and whether the session that measures voices is
/// running. Live dubbing holds the same worker, so the two never run at once.
class _CharacterSessionControls extends StatelessWidget {
  const _CharacterSessionControls();

  @override
  Widget build(BuildContext context) => BlocBuilder<ShellCubit, ShellState>(
    builder: (context, shell) => BlocBuilder<DownloadsCubit, DownloadsState>(
      buildWhen: whenChanged((downloads) => downloads.installed),
      builder: (context, _) => BlocBuilder<PipelineCubit, LivePipelineState>(
        buildWhen: whenChanged(
          (pipeline) => (pipeline.processes, pipeline.selectedProcess, pipeline.running),
        ),
        builder: (context, pipeline) => BlocBuilder<CharactersCubit, CharactersState>(
          buildWhen: whenChanged((characters) => (characters.status, characters.recordingId)),
          builder: (context, characters) =>
              _build(context, pipeline, characters, initializing: shell.initializing),
        ),
      ),
    ),
  );

  Widget _build(
    BuildContext context,
    LivePipelineState pipeline,
    CharactersState characters, {
    required bool initializing,
  }) {
    final l10n = AppLocalizations.of(context);
    final canRecord = context.read<CharactersCubit>().canRecord;
    final locked = characters.running || pipeline.running;
    final picker = ProcessPicker(
      processes: pipeline.processes,
      selected: pipeline.selectedProcess,
      enabled: !locked,
      onSelected: context.read<PipelineCubit>().selectProcess,
      onRefresh: context.read<PipelineCubit>().refreshProcesses,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.charactersNote} ${l10n.voicesOnTheGraph}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: picker),
            const SizedBox(width: 16),
            SizedBox(
              width: LanguageRow.actionWidth,
              child: FilledButton.icon(
                key: const ValueKey('charactersSession'),
                onPressed: !canRecord || initializing || pipeline.running
                    ? null
                    : () => context.read<CharactersCubit>().toggleSession(
                        initializing: initializing,
                        process: pipeline.selectedProcess,
                      ),
                icon: characters.status == PipelineStatus.starting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : Icon(
                        characters.running ? Icons.stop_rounded : Icons.fiber_manual_record_rounded,
                      ),
                label: Text(
                  characters.running ? l10n.charactersSessionStop : l10n.charactersSessionStart,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          !canRecord
              ? l10n.charactersNeedsConverter
              : pipeline.running
              ? l10n.snapshotInLive
              : l10n.charactersHowTo,
          style: TextStyle(
            color: canRecord ? LoreDubPalette.mutedInk : LoreDubPalette.warning,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// The cards themselves, with what it takes to add them and hand them on.
///
/// A card dropped here from a pack leaves that pack: the cast holds every
/// character whether a pack names them or not, so this is where a card goes
/// back to being in none.
class _CharacterCast extends StatelessWidget {
  const _CharacterCast();

  Future<void> _exportAll(BuildContext context, List<Character> characters) async {
    final charactersCubit = context.read<CharactersCubit>();
    final location = await getSaveLocation(suggestedName: 'loredub-characters.json');
    if (location == null) return;
    await charactersCubit.export(location.path, characters);
  }

  Future<void> _export(BuildContext context, Character character) async {
    final characters = context.read<CharactersCubit>();
    final location = await getSaveLocation(
      suggestedName: '${character.name.trim().isEmpty ? 'character' : character.name}.json',
    );
    if (location == null) return;
    await characters.export(location.path, [character]);
  }

  Future<void> _confirmDelete(BuildContext context, Character character) async {
    final characters = context.read<CharactersCubit>();
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(l10n.charactersDeleteTitle),
        content: Text(
          l10n.charactersDeleteMessage(character.name),
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.charactersDeleteCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.charactersDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await characters.remove(character.id);
  }

  @override
  Widget build(BuildContext context) => BlocSelector<PipelineCubit, LivePipelineState, bool>(
    // Whether a dubbing session holds the worker, and nothing more of it: a
    // recognized phrase must not redraw every card.
    selector: (pipeline) => pipeline.running,
    builder: (context, dubbing) => BlocBuilder<CharactersCubit, CharactersState>(
      builder: (context, state) => _build(context, state, dubbing: dubbing),
    ),
  );

  /// [dubbing] is a dubbing session holding the worker. A sample and a card
  /// measured from files each bring up a worker of their own, which would be
  /// taken from under that session, so both wait for it to end — the way the
  /// button that starts the recording does.
  Widget _build(BuildContext context, CharactersState state, {required bool dubbing}) {
    final l10n = AppLocalizations.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 9, 12, 8),
            child: AreaHeading(
              label: ModuleLabel(number: '02', label: l10n.areaCast),
              actions: [
                TextButton.icon(
                  onPressed: state.characters.isEmpty
                      ? null
                      : () => _exportAll(context, state.characters),
                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                  label: Text(l10n.charactersExportAll),
                  style: TextButton.styleFrom(foregroundColor: LoreDubPalette.mutedInk),
                ),
                FilledButton.icon(
                  key: const ValueKey('charactersAdd'),
                  onPressed: () => context.read<CharactersCubit>().add(l10n.charactersNewName),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l10n.charactersAdd),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          DragTarget<CharacterDrag>(
            // Only a card that came out of a pack has anywhere to land
            // here; one dragged from the cast is already where it is.
            onWillAcceptWithDetails: (details) => details.data.fromPackId != null,
            onAcceptWithDetails: (details) => context.read<CharactersCubit>().removeFromPack(
              details.data.fromPackId!,
              details.data.character.id,
            ),
            builder: (context, candidate, _) => ColoredBox(
              color: candidate.isEmpty
                  ? Colors.transparent
                  : LoreDubPalette.orange.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                child: state.characters.isEmpty
                    ? _EmptyCast(loading: state.loading)
                    : CharacterTileGrid(
                        children: [
                          for (final character in state.characters)
                            CharacterTile(
                              key: ValueKey(character.id),
                              character: character,
                              recording: state.recordingId == character.id,
                              heardSeconds: state.heardSeconds,
                              packNames: [
                                for (final pack in state.packs)
                                  if (pack.holds(character.id)) pack.name,
                              ],
                              cast: [
                                for (final other in state.characters)
                                  if (other.id != character.id) other,
                              ],
                              onRename: (name) =>
                                  context.read<CharactersCubit>().rename(character.id, name),
                              playing: state.playingId == character.id,
                              onPlay: !state.canPlay(character.id) || state.sounding
                                  ? null
                                  : () => context.read<CharactersCubit>().playClip(character.id),
                              previewing: state.previewingId == character.id,
                              onStopSound: context.read<CharactersCubit>().stopSounding,
                              carriesTimbre: context.read<CharactersCubit>().carriesTimbre,
                              dubbing: dubbing,
                              onPreview:
                                  dubbing ||
                                      state.sounding ||
                                      state.running ||
                                      state.building ||
                                      !context.read<CharactersCubit>().canPreview
                                  ? null
                                  : () => context.read<CharactersCubit>().preview(character.id),
                              onRecord:
                                  !state.running ||
                                      (state.recording && state.recordingId != character.id)
                                  ? null
                                  : () => state.recordingId == character.id
                                        ? context.read<CharactersCubit>().stopRecording()
                                        : context.read<CharactersCubit>().startRecording(
                                            character.id,
                                          ),
                              building: state.buildingId == character.id,
                              built: state.builtId == character.id ? state.built : null,
                              onFilesDropped:
                                  dubbing ||
                                      state.building ||
                                      state.recording ||
                                      !context.read<CharactersCubit>().canRecord
                                  ? null
                                  : (paths) => context.read<CharactersCubit>().voiceFromFiles(
                                      character.id,
                                      paths,
                                    ),
                              onExport: character.vector.isEmpty
                                  ? null
                                  : () => _export(context, character),
                              onDelete: () => _confirmDelete(context, character),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The packs: named areas cards are dropped into, handed on and thrown away
/// as a group. Throwing one away leaves the cards in the cast — the player
/// recorded them, and only the grouping was ever the pack's.
class _CharacterPacks extends StatelessWidget {
  const _CharacterPacks();

  Future<void> _import(BuildContext context) async {
    final charactersCubit = context.read<CharactersCubit>();
    final l10n = AppLocalizations.of(context);
    final chosen = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'LoreDub', extensions: ['json']),
      ],
    );
    if (chosen.isEmpty) return;
    final added = await charactersCubit.import([for (final file in chosen) file.path]);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added.packs == 0
              ? l10n.charactersImported(added.characters)
              : l10n.packsImported(added.packs, added.characters),
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context, CharacterPack pack, List<Character> members) async {
    final characters = context.read<CharactersCubit>();
    final location = await getSaveLocation(
      suggestedName: '${pack.name.trim().isEmpty ? 'pack' : pack.name}.json',
    );
    if (location == null) return;
    await characters.export(location.path, members, pack: pack);
  }

  Future<void> _confirmDelete(BuildContext context, CharacterPack pack) async {
    final characters = context.read<CharactersCubit>();
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(l10n.packsDeleteTitle),
        content: Text(
          l10n.packsDeleteMessage(pack.name),
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.charactersDeleteCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.charactersDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await characters.removePack(pack.id);
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<CharactersCubit, CharactersState>(
    buildWhen: whenChanged(
      (characters) => (characters.characters, characters.packs, characters.loading),
    ),
    builder: (context, state) {
      final l10n = AppLocalizations.of(context);
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 9, 12, 8),
              child: AreaHeading(
                label: ModuleLabel(number: '03', label: l10n.areaPacks),
                actions: [
                  TextButton.icon(
                    key: const ValueKey('charactersImport'),
                    onPressed: () => _import(context),
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: Text(l10n.charactersImport),
                    style: TextButton.styleFrom(foregroundColor: LoreDubPalette.mutedInk),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('packsAdd'),
                    onPressed: () => context.read<CharactersCubit>().addPack(l10n.packsNewName),
                    icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                    label: Text(l10n.packsAdd),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
              child: state.packs.isEmpty
                  ? Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 20,
                          color: LoreDubPalette.mutedInk,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(l10n.packsEmpty)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final pack in state.packs) ...[
                          CharacterPackArea(
                            key: ValueKey(pack.id),
                            pack: pack,
                            members: state.membersOf(pack),
                            onRename: (name) =>
                                context.read<CharactersCubit>().renamePack(pack.id, name),
                            onExport: pack.characterIds.isEmpty
                                ? null
                                : () => _export(context, pack, state.membersOf(pack)),
                            onDelete: () => _confirmDelete(context, pack),
                            onDrop: (drag) => context.read<CharactersCubit>().addToPack(
                              pack.id,
                              drag.character.id,
                            ),
                            onRemoveMember: (character) => context
                                .read<CharactersCubit>()
                                .removeFromPack(pack.id, character.id),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      );
    },
  );
}

class _EmptyCast extends StatelessWidget {
  const _EmptyCast({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) => Center(
    child: loading
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.groups_rounded, size: 42, color: LoreDubPalette.mutedInk),
                const SizedBox(height: 14),
                Text(
                  AppLocalizations.of(context).charactersEmpty,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
  );
}

class _ModelsPanel extends StatelessWidget {
  const _ModelsPanel({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<DownloadsCubit, DownloadsState>(
    builder: (context, downloads) => BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settings) => BlocBuilder<PipelineCubit, LivePipelineState>(
        buildWhen: whenChanged((pipeline) => pipeline.running),
        builder: (context, pipeline) => _build(context, downloads, running: pipeline.running),
      ),
    ),
  );

  Widget _build(BuildContext context, DownloadsState downloads, {required bool running}) {
    final l10n = AppLocalizations.of(context);
    final selection = context.selection;
    final selected = selection.settings.targetLanguage;
    return ListView(
      key: const ValueKey('modelsList'),
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      children: [
        ModuleLabel(number: '01', label: l10n.sectionRecognition),
        const SizedBox(height: 4),
        SectionNote(l10n.sectionRecognitionNote),
        if (selection.recognitionNeedsEnglish) ...[
          const SizedBox(height: 8),
          SectionNote(l10n.recognitionNeedsEnglish),
        ],
        // Size against quality is the whole choice, so it is drawn as a chart;
        // a window too narrow for the bars gets the plain cards instead.
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= WhisperModelChart.minimumWidth) {
              return Padding(
                padding: const EdgeInsets.only(top: 18),
                child: WhisperModelChart(
                  models: selection.recognitionModels,
                  selectedId: selection.recognition?.model.id,
                  running: running,
                  isStopping: downloads.isStopping,
                  onInstall: context.read<DownloadsCubit>().installModel,
                  onPause: (state) => context.read<DownloadsCubit>().pauseDownload(state.model.id),
                  onCancel: (state) =>
                      context.read<DownloadsCubit>().cancelDownload(state.model.id),
                  onRemove: context.read<DownloadsCubit>().removeModel,
                  onSelect: running
                      ? null
                      : (state) =>
                            context.read<SettingsCubit>().selectRecognitionModel(state.model.id),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final state in selection.recognitionModels) ...[
                  const SizedBox(height: 12),
                  _ModelCard(
                    state: state,
                    onInstall: () => context.read<DownloadsCubit>().installModel(state),
                    onPause: () => context.read<DownloadsCubit>().pauseDownload(state.model.id),
                    onCancel: () => context.read<DownloadsCubit>().cancelDownload(state.model.id),
                    stopping: downloads.isStopping(state.model.id),
                    choosable: true,
                    selected: state.model.id == selection.recognition?.model.id,
                    onSelect: running
                        ? null
                        : () =>
                              context.read<SettingsCubit>().selectRecognitionModel(state.model.id),
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 26),
        // A translator and a voice are only ever useful together, so a
        // language is one tile: downloaded, picked and deleted as a pair.
        ModuleLabel(number: '02', label: l10n.sectionLanguages),
        const SizedBox(height: 4),
        SectionNote(l10n.sectionLanguagesNote),
        const SizedBox(height: 12),
        ModelTileGrid(
          children: [
            for (final pair in selection.languagePairs)
              LanguagePairTile(
                key: ValueKey('languageTile-${pair.language}'),
                pair: pair,
                selected: pair.language == selected,
                running: running,
                isStopping: downloads.isStopping,
                onSelect: running
                    ? null
                    : () => context.read<SettingsCubit>().selectTargetLanguage(pair.language),
                onInstall: context.read<DownloadsCubit>().installModel,
                onPause: (state) => context.read<DownloadsCubit>().pauseDownload(state.model.id),
                onCancel: (state) => context.read<DownloadsCubit>().cancelDownload(state.model.id),
                onRemove: context.read<DownloadsCubit>().removeModel,
              ),
          ],
        ),
        for (final pair in selection.languagePairs)
          for (final part in pair.parts)
            if (part.error != null) ...[
              const SizedBox(height: 10),
              ModelFailureRow(state: part),
            ],
        const SizedBox(height: 26),
        ModuleLabel(number: '03', label: l10n.sectionVoiceConversion),
        const SizedBox(height: 4),
        SectionNote(l10n.sectionVoiceConversionNote),
        const SizedBox(height: 12),
        ModelTileGrid(
          children: [
            for (final state in selection.voiceConverters)
              ConverterTile(
                key: ValueKey('converterTile-${state.model.id}'),
                state: state,
                inUse: selection.clonesVoice,
                running: running,
                isStopping: downloads.isStopping,
                onInstall: context.read<DownloadsCubit>().installModel,
                onPause: (state) => context.read<DownloadsCubit>().pauseDownload(state.model.id),
                onCancel: (state) => context.read<DownloadsCubit>().cancelDownload(state.model.id),
                onRemove: context.read<DownloadsCubit>().removeModel,
              ),
          ],
        ),
        for (final state in selection.voiceConverters)
          if (state.error != null) ...[
            const SizedBox(height: 10),
            ModelFailureRow(state: state),
          ],
      ],
    );
  }
}

/// Pause/resume and cancel for a download in flight.
///
/// Kept to two small buttons so it fits the Whisper cards a narrow window
/// falls back to.
class _DownloadControls extends StatelessWidget {
  const _DownloadControls({
    required this.paused,
    required this.stopping,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  final bool paused;
  final bool stopping;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: stopping
              ? l10n.downloadStopping
              : (paused ? l10n.downloadResume : l10n.downloadPause),
          onPressed: stopping ? null : (paused ? onResume : onPause),
          icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 20),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          padding: EdgeInsets.zero,
        ),
        IconButton(
          tooltip: l10n.downloadCancel,
          onPressed: stopping ? null : onCancel,
          icon: const Icon(Icons.close_rounded, size: 20),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.state,
    required this.onInstall,
    required this.onPause,
    required this.onCancel,
    this.stopping = false,
    this.choosable = false,
    this.selected = false,
    this.onSelect,
  });

  final ModelInstallState state;
  final VoidCallback onInstall;

  /// Stopping keeps what arrived; cancelling throws it away.
  final VoidCallback onPause;
  final VoidCallback onCancel;

  /// A stop has been asked for and the download has not noticed yet.
  final bool stopping;

  /// Whether this card is one of a set the player picks between. Only the
  /// Whisper builds are drawn as cards now, in a window too narrow for
  /// their chart; such a card shows which one is chosen.
  final bool choosable;
  final bool selected;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final details = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (choosable)
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: selected ? LoreDubPalette.orange : LoreDubPalette.outline,
          )
        else
          Icon(
            state.installed ? Icons.check_circle_rounded : Icons.memory_rounded,
            color: state.installed ? LoreDubPalette.success : LoreDubPalette.mutedInk,
          ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                modelTitle(l10n, state.model),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              Text(
                modelDescription(l10n, state.model),
                style: const TextStyle(color: LoreDubPalette.mutedInk),
              ),
              if (state.progress case final progress?) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      state.paused
                          ? '${(progress * 100).round()}% · ${l10n.downloadPaused}'
                          : '${(progress * 100).round()}%',
                    ),
                    const Spacer(),
                    _DownloadControls(
                      paused: state.paused,
                      stopping: stopping,
                      onPause: onPause,
                      onResume: onInstall,
                      onCancel: onCancel,
                    ),
                  ],
                ),
              ],
              if (state.error case final error?) ...[
                const SizedBox(height: 8),
                Text(
                  describeFailure(l10n, error),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    final action = OutlinedButton.icon(
      onPressed: state.installed || state.stoppable ? null : onInstall,
      icon: Icon(state.installed ? Icons.check_rounded : Icons.download_rounded),
      label: Text(state.installed ? l10n.modelInstalled : l10n.modelDownload),
    );
    final body = Padding(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: details),
              const SizedBox(width: 20),
              action,
            ],
          );
        },
      ),
    );
    return Card(
      // The whole card picks the language, not just the small indicator.
      child: onSelect == null
          ? body
          : InkWell(
              onTap: onSelect,
              borderRadius: BorderRadius.circular(12),
              child: body,
            ),
    );
  }
}

/// How far one group of settings stands from the next: enough more than the
/// 12 between cards that the break is read as a break rather than a gap.
const _settingsGroupGap = 28.0;

class _SettingsPanel extends StatefulWidget {
  const _SettingsPanel({super.key});

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  final _proxyFormKey = GlobalKey<FormState>();
  final _pythonFormKey = GlobalKey<FormState>();
  late final TextEditingController _proxyController;
  late final TextEditingController _pythonController;

  AppSettings get _settings => context.read<SettingsCubit>().settings;

  @override
  void initState() {
    super.initState();
    _proxyController = TextEditingController(
      text: _settings.modelProxyUrl,
    );
    _pythonController = TextEditingController(
      text: _settings.pythonExecutable.isEmpty
          ? bundledPythonExecutablePath()
          : _settings.pythonExecutable,
    );
  }

  @override
  void dispose() {
    _proxyController.dispose();
    _pythonController.dispose();
    super.dispose();
  }

  String? _validateProxy(String? value) {
    try {
      parseModelProxyUrl(value ?? '');
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  /// Why a combination cannot be bound: one that takes a key from the game,
  /// or one another action already has. [others] pairs each other action's
  /// combination with its name.
  String? _hotkeyProblem(
    AppLocalizations l10n,
    Hotkey hotkey, {
    required List<(Hotkey?, String)> others,
  }) {
    if (!hotkey.leavesGameKeys) return l10n.hotkeyNeedsModifier;
    for (final (other, name) in others) {
      if (other != null && other.sameCombination(hotkey)) return l10n.hotkeyDuplicate(name);
    }
    return null;
  }

  void _saveProxy() {
    if (!(_proxyFormKey.currentState?.validate() ?? false)) return;
    context.read<SettingsCubit>().update(
      _settings.copyWith(modelProxyUrl: _proxyController.text.trim()),
    );
  }

  Future<void> _findPython() async {
    final executable = await context.read<SettingsCubit>().findPythonExecutable();
    if (executable == null || !mounted) return;
    _pythonController.text = executable;
  }

  void _savePython() {
    if (!(_pythonFormKey.currentState?.validate() ?? false)) return;
    context.read<SettingsCubit>().update(
      _settings.copyWith(pythonExecutable: _pythonController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<SettingsCubit, SettingsState>(
    builder: (context, state) => BlocBuilder<PipelineCubit, LivePipelineState>(
      buildWhen: whenChanged((pipeline) => pipeline.running),
      // The compute card and the model directory listen to the downloads
      // themselves, so a runtime arriving does not redraw the whole page.
      builder: (context, pipeline) => _build(context, state, running: pipeline.running),
    ),
  );

  /// The whole screen: four groups of cards, in the order a player meets
  /// them — what is heard, how it sounds, what drives it, where it lives.
  ///
  /// Each group is announced the way the other screens number their areas,
  /// and stands off further from its neighbour than the cards inside it do.
  /// The grouping was a gap alone before, and the same gap the cards within
  /// a group already kept, so eleven cards read as one list and the
  /// interface language sat level with the path to Python.
  Widget _build(BuildContext context, SettingsState state, {required bool running}) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      key: const ValueKey('settingsList'),
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      children: [
        ModuleLabel(number: '01', label: l10n.settingsGroupInterface),
        const SizedBox(height: 12),
        ..._theInterface(context, l10n, state, running: running),
        const SizedBox(height: _settingsGroupGap),
        ModuleLabel(number: '02', label: l10n.settingsGroupDubbing),
        const SizedBox(height: 12),
        ..._howItSounds(context, l10n, state, running: running),
        const SizedBox(height: _settingsGroupGap),
        ModuleLabel(number: '03', label: l10n.settingsGroupCompute),
        const SizedBox(height: 12),
        _ComputeDeviceCard(),
        const SizedBox(height: _settingsGroupGap),
        // Where the parts come from, and where they are kept: two areas of
        // their own rather than one drawer holding everything a player only
        // opens when something is broken.
        LayoutBuilder(
          builder: (context, constraints) {
            final downloads = _theDownloads(context, l10n, state, running: running);
            final paths = _thePaths(context, l10n, state, running: running);
            return constraints.maxWidth >= _pairedCardsWidth
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: downloads),
                      const SizedBox(width: 12),
                      Expanded(child: paths),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      downloads,
                      const SizedBox(height: _settingsGroupGap),
                      paths,
                    ],
                  );
          },
        ),
      ],
    );
  }

  /// The language LoreDub speaks to the player in. Where the original comes
  /// from is no longer a setting: the game's sound is dubbed on Live, and
  /// the screen is read on its own page, which keeps the frame it reads.
  List<Widget> _theInterface(
    BuildContext context,
    AppLocalizations l10n,
    SettingsState state, {
    required bool running,
  }) {
    final settings = state.settings;
    final language = SettingCard(
      title: l10n.settingsInterfaceLanguage,
      subtitle: l10n.interfaceLanguageNote,
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<String>(
          segments: [
            for (final language in interfaceLanguages)
              ButtonSegment(
                value: language,
                label: Text(interfaceLanguageName(language)),
              ),
          ],
          selected: {settings.interfaceLanguage},
          onSelectionChanged: (selection) => context.read<SettingsCubit>().update(
            settings.copyWith(interfaceLanguage: selection.first),
          ),
        ),
      ),
    );
    return [
      LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= _pairedCardsWidth
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: language),
                    const SizedBox(width: 12),
                    Expanded(child: _scaleCard(l10n, settings)),
                  ],
                ),
              )
            : Column(
                children: [language, const SizedBox(height: 12), _scaleCard(l10n, settings)],
              ),
      ),
      const SizedBox(height: 12),
      ..._theHotkeys(context, l10n, state, running: running),
    ];
  }

  /// The marking over one of the two areas at the foot, spaced so that both
  /// of them start on the same line.
  Widget _areaHeading(String label, {required String number}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: ModuleLabel(number: number, label: label),
  );

  /// How large the interface itself is drawn, beside the language it speaks:
  /// the two things a player sets once, for their own eyes rather than for
  /// the dubbing.
  Widget _scaleCard(AppLocalizations l10n, AppSettings settings) => SettingCard(
    title: l10n.settingsScale,
    subtitle: l10n.scaleValue((settings.chosenScale * 100).round()),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Slider(
          key: const ValueKey('interfaceScale'),
          value: settings.chosenScale,
          min: AppSettings.smallestScale,
          max: AppSettings.largestScale,
          divisions: AppSettings.scaleDivisions,
          label: l10n.scaleValue((settings.chosenScale * 100).round()),
          onChanged: (value) =>
              context.read<SettingsCubit>().update(settings.copyWith(interfaceScale: value)),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.scaleNote,
          style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
        ),
      ],
    ),
  );

  /// The proxy the downloads go through.
  Widget _theDownloads(
    BuildContext context,
    AppLocalizations l10n,
    SettingsState state, {
    required bool running,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _areaHeading(l10n.settingsGroupDownloads, number: '04'),
      _proxyCard(context, l10n),
    ],
  );

  /// Where the interpreter and the packages sit on this machine.
  Widget _thePaths(
    BuildContext context,
    AppLocalizations l10n,
    SettingsState state, {
    required bool running,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _areaHeading(l10n.settingsGroupPaths, number: '05'),
      _pythonCard(context, l10n),
      const SizedBox(height: 12),
      _modelDirectoryCard(context, l10n),
    ],
  );

  /// What the dubbing sounds like: how far the game is turned down under it, how fast a line is
  /// read, and in whose voice.
  List<Widget> _howItSounds(
    BuildContext context,
    AppLocalizations l10n,
    SettingsState state, {
    required bool running,
  }) {
    final settings = state.settings;
    final volume = SettingCard(
      title: l10n.settingsOriginalVolume,
      subtitle: l10n.originalVolumeValue((settings.duckedVolume * 100).round()),
      // The floor is the capture's: the game is heard through this same
      // volume, and silenced outright it would never be dubbed at all.
      // Only the screen session, which has no ear in the game, may take it
      // all the way down -- and it asks for that on its own page.
      child: Column(
        children: [
          Slider(
            key: const ValueKey('originalVolume'),
            value: settings.duckedVolume,
            min: AppSettings.audibleDuck,
            max: AppSettings.loudestDuck,
            divisions: AppSettings.duckDivisions,
            label: '${(settings.duckedVolume * 100).round()}%',
            onChanged: running
                ? null
                : (value) => context.read<SettingsCubit>().update(
                    settings.copyWith(originalVolume: value),
                  ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Switch(
                value: settings.duckWhileSpeaking,
                onChanged: running
                    ? null
                    : (value) => context.read<SettingsCubit>().update(
                        settings.copyWith(duckWhileSpeaking: value),
                      ),
              ),
              const SizedBox(width: 6),
              Flexible(child: Text(l10n.duckWhileSpeaking)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.duckWhileSpeakingNote,
            style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
          ),
        ],
      ),
    );
    final pace = SettingCard(
      title: l10n.settingsTtsSpeed,
      subtitle: l10n.speedValue(settings.chosenSpeed.toStringAsFixed(2)),
      child: Column(
        children: [
          Slider(
            key: const ValueKey('ttsSpeed'),
            value: settings.chosenSpeed,
            min: AppSettings.slowestSpeech,
            max: AppSettings.fastestSpeech,
            divisions: AppSettings.speechDivisions,
            label: l10n.speedValue(settings.chosenSpeed.toStringAsFixed(2)),
            onChanged: running
                ? null
                : (value) =>
                      context.read<SettingsCubit>().update(settings.copyWith(ttsSpeed: value)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Switch(
                key: const ValueKey('hurryWhenQueued'),
                value: settings.hurryWhenQueued,
                onChanged: running
                    ? null
                    : (value) => context.read<SettingsCubit>().update(
                        settings.copyWith(hurryWhenQueued: value),
                      ),
              ),
              const SizedBox(width: 6),
              Flexible(child: Text(l10n.hurryWhenQueued)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.hurryWhenQueuedNote,
            style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
          ),
        ],
      ),
    );
    return [
      // Two sliders with a switch under each: side by side they are read at
      // a glance, and one under the other only where the screen is too
      // narrow to set either without squeezing its own notes.
      LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= _pairedCardsWidth
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: volume),
                    const SizedBox(width: 12),
                    Expanded(child: pace),
                  ],
                ),
              )
            : Column(children: [volume, const SizedBox(height: 12), pace]),
      ),
      const SizedBox(height: 12),
      _VoiceCard(),
    ];
  }

  /// What the player drives it with, and what the machine drives it on.
  /// The combinations Windows hands the application wherever the pointer
  /// is. They are the player's own way in, so they stand with the interface
  /// rather than beside the hardware the models run on.
  List<Widget> _theHotkeys(
    BuildContext context,
    AppLocalizations l10n,
    SettingsState state, {
    required bool running,
  }) {
    final settings = state.settings;
    return [
      SettingCard(
        title: l10n.settingsHotkeys,
        subtitle: l10n.hotkeysNote,
        child: Column(
          children: [
            _HotkeyRow(
              label: l10n.hotkeyPause,
              field: HotkeyField(
                key: const ValueKey('pauseHotkey'),
                value: settings.pauseHotkey,
                enabled: !running,
                validate: (hotkey) => _hotkeyProblem(
                  l10n,
                  hotkey,
                  others: [
                    (_settings.resumeHotkey, l10n.hotkeyResume),
                    (_settings.snapshotHotkey, l10n.hotkeySnapshot),
                    (_settings.frameHotkey, l10n.hotkeyFrame),
                  ],
                ),
                onChanged: (hotkey) => context.read<SettingsCubit>().update(
                  hotkey == null
                      ? _settings.copyWith(clearPauseHotkey: true)
                      : _settings.copyWith(pauseHotkey: hotkey),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _HotkeyRow(
              label: l10n.hotkeyResume,
              field: HotkeyField(
                key: const ValueKey('resumeHotkey'),
                value: settings.resumeHotkey,
                enabled: !running,
                validate: (hotkey) => _hotkeyProblem(
                  l10n,
                  hotkey,
                  others: [
                    (_settings.pauseHotkey, l10n.hotkeyPause),
                    (_settings.snapshotHotkey, l10n.hotkeySnapshot),
                    (_settings.frameHotkey, l10n.hotkeyFrame),
                  ],
                ),
                onChanged: (hotkey) => context.read<SettingsCubit>().update(
                  hotkey == null
                      ? _settings.copyWith(clearResumeHotkey: true)
                      : _settings.copyWith(resumeHotkey: hotkey),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _HotkeyRow(
              label: l10n.hotkeySnapshot,
              field: HotkeyField(
                key: const ValueKey('snapshotHotkey'),
                value: settings.snapshotHotkey,
                enabled: !running,
                validate: (hotkey) => _hotkeyProblem(
                  l10n,
                  hotkey,
                  others: [
                    (_settings.pauseHotkey, l10n.hotkeyPause),
                    (_settings.resumeHotkey, l10n.hotkeyResume),
                    (_settings.frameHotkey, l10n.hotkeyFrame),
                  ],
                ),
                onChanged: (hotkey) => context.read<SettingsCubit>().update(
                  hotkey == null
                      ? _settings.copyWith(clearSnapshotHotkey: true)
                      : _settings.copyWith(snapshotHotkey: hotkey),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _HotkeyRow(
              label: l10n.hotkeyFrame,
              field: HotkeyField(
                key: const ValueKey('frameHotkey'),
                value: settings.frameHotkey,
                enabled: !running,
                validate: (hotkey) => _hotkeyProblem(
                  l10n,
                  hotkey,
                  others: [
                    (_settings.pauseHotkey, l10n.hotkeyPause),
                    (_settings.resumeHotkey, l10n.hotkeyResume),
                    (_settings.snapshotHotkey, l10n.hotkeySnapshot),
                  ],
                ),
                onChanged: (hotkey) => context.read<SettingsCubit>().update(
                  hotkey == null
                      ? _settings.copyWith(clearFrameHotkey: true)
                      : _settings.copyWith(frameHotkey: hotkey),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// Where the parts come from and where they are kept.
  Widget _pythonCard(BuildContext context, AppLocalizations l10n) =>
      BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) => SettingCard(
          title: l10n.settingsPython,
          subtitle: l10n.pythonNote,
          child: Form(
            key: _pythonFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _pythonController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.pythonFieldLabel,
                    helperText: l10n.pythonFieldHelper,
                    prefixIcon: const Icon(Icons.terminal_rounded),
                  ),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? l10n.pythonFieldRequired : null,
                  onFieldSubmitted: (_) => _savePython(),
                ),
                const SizedBox(height: 12),
                // Side by side where the card is wide enough for all three, and
                // one under another at a shared width where it is not: wrapped
                // at their own widths they came out ragged, each button a
                // different length down the right edge.
                _PythonActions(
                  children: [
                    TextButton.icon(
                      onPressed: state.searchingPython ? null : _findPython,
                      icon: state.searchingPython
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.manage_search_rounded),
                      label: Text(
                        state.searchingPython ? l10n.pythonSearching : l10n.pythonFindAutomatically,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        _pythonController.text = bundledPythonExecutablePath();
                        _savePython();
                      },
                      icon: const Icon(Icons.settings_backup_restore_rounded),
                      label: Text(l10n.pythonBundled),
                    ),
                    FilledButton.icon(
                      onPressed: _savePython,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(l10n.save),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _proxyCard(BuildContext context, AppLocalizations l10n) => SettingCard(
    title: l10n.settingsModelDownloads,
    subtitle: l10n.proxyNote,
    child: Form(
      key: _proxyFormKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final field = TextFormField(
            controller: _proxyController,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.proxyLabel,
              hintText: 'http://127.0.0.1:7890',
              helperText: l10n.proxyHelper,
              helperMaxLines: 2,
              prefixIcon: const Icon(Icons.lan_outlined),
            ),
            validator: _validateProxy,
            onFieldSubmitted: (_) => _saveProxy(),
          );
          final save = OutlinedButton.icon(
            onPressed: _saveProxy,
            icon: const Icon(Icons.save_outlined),
            label: Text(l10n.save),
          );
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: save),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: field),
              const SizedBox(width: 16),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: save,
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _modelDirectoryCard(BuildContext context, AppLocalizations l10n) => SettingCard(
    title: l10n.settingsModelDirectory,
    subtitle: l10n.modelDirectoryNote,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final path = BlocBuilder<DownloadsCubit, DownloadsState>(
          builder: (context, downloads) => SelectableText(
            downloads.modelDirectoryPath,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
        final open = OutlinedButton.icon(
          onPressed: context.read<DownloadsCubit>().openModelDirectory,
          icon: const Icon(Icons.folder_open_rounded),
          label: Text(l10n.openInExplorer),
        );
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              path,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: open),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: path),
            const SizedBox(width: 16),
            open,
          ],
        );
      },
    ),
  );
}

/// The buttons under the Python path: a row while they fit, a stack of one
/// width when they do not.
class _PythonActions extends StatelessWidget {
  const _PythonActions({required this.children});

  final List<Widget> children;

  /// Below this the three of them no longer share a line.
  static const _oneRow = 520.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth >= _oneRow
        ? Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: children,
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0) const SizedBox(height: 8),
                child,
              ],
            ],
          ),
  );
}

/// Thread counts worth offering on this machine, always including whatever is
/// currently selected so a setting carried over from another CPU still shows.
List<int> _threadOptions(int selected) {
  final options =
      <int>{2, 3, 4, 6, 8, 12, 16}.where((value) => value <= Platform.numberOfProcessors).toSet()
        ..add(selected)
        ..add(defaultCpuThreads());
  return options.toList()..sort();
}

/// Which voice reads the dubbing, and whether it follows the original.
///
/// The automatic half only makes sense when the language's package ships
/// both a man's and a woman's voice and there is audio to hear, so when it
/// does not, the option is disabled and the reason is written out rather
/// than left for the user to guess at.
class _VoiceCard extends StatelessWidget {
  const _VoiceCard();

  @override
  Widget build(BuildContext context) => BlocBuilder<SettingsCubit, SettingsState>(
    // Which voices exist comes from the downloaded package.
    builder: (context, state) => BlocBuilder<DownloadsCubit, DownloadsState>(
      buildWhen: whenChanged((downloads) => downloads.installed),
      builder: (context, _) => BlocBuilder<PipelineCubit, LivePipelineState>(
        buildWhen: whenChanged((pipeline) => (pipeline.running, pipeline.spokenVoice)),
        builder: (context, pipeline) => _build(context, state, pipeline),
      ),
    ),
  );

  Widget _build(BuildContext context, SettingsState state, LivePipelineState pipeline) {
    final l10n = AppLocalizations.of(context);
    final settings = state.settings;
    final selection = context.selection;
    final running = pipeline.running;
    final voices = selection.availableVoices;
    final canFollow = selection.canFollowSpeaker;
    // A mode this setup cannot honour is shown as the one that will run.
    final mode = switch (settings.voiceMode) {
      VoiceMode.original => VoiceMode.original,
      VoiceMode.automatic || VoiceMode.original when canFollow => VoiceMode.automatic,
      _ => VoiceMode.chosen,
    };
    final converterInstalled = selection.voiceConverter?.installed ?? false;
    return SettingCard(
      title: l10n.settingsVoice,
      subtitle: l10n.voiceNote,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<VoiceMode>(
            segments: [
              ButtonSegment(
                value: VoiceMode.automatic,
                label: Text(l10n.voiceAutomatic),
                enabled: canFollow,
              ),
              ButtonSegment(value: VoiceMode.chosen, label: Text(l10n.voiceFixed)),
              ButtonSegment(value: VoiceMode.original, label: Text(l10n.voiceOriginal)),
            ],
            selected: {mode},
            onSelectionChanged: running
                ? null
                : (picked) =>
                      context.read<SettingsCubit>().update(settings.withVoiceMode(picked.first)),
          ),
          if (mode == VoiceMode.original) ...[
            const SizedBox(height: 10),
            Text(
              converterInstalled ? l10n.voiceOriginalNote : l10n.voiceOriginalMissing,
              style: TextStyle(
                color: converterInstalled ? LoreDubPalette.mutedInk : LoreDubPalette.warning,
                fontSize: 12,
              ),
            ),
          ],
          // The converter is what hears who is speaking, so remembering the
          // characters is on offer wherever it is installed — with the
          // original voice it also keeps their timbre.
          if (converterInstalled && mode != VoiceMode.chosen) ...[
            const SizedBox(height: 12),
            _VoiceBankControls(
              settings: settings,
              size: state.voiceBankSize,
              running: running,
            ),
          ],
          if (!canFollow) ...[
            const SizedBox(height: 10),
            Text(
              l10n.voiceUnavailable,
              style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 12),
            ),
          ],
          // The original voice needs a base to lay its timbre over; when the
          // package cannot follow the speaker, that base is chosen by hand.
          if ((mode == VoiceMode.chosen || (mode == VoiceMode.original && !canFollow)) &&
              voices.isNotEmpty) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: const ValueKey('voice'),
              initialValue: selection.voice,
              decoration: InputDecoration(labelText: l10n.voiceFieldLabel),
              items: [
                for (final voice in voices)
                  DropdownMenuItem(value: voice.id, child: Text(voiceLabel(l10n, voice))),
              ],
              onChanged: running
                  ? null
                  : (value) {
                      if (value != null) {
                        context.read<SettingsCubit>().update(settings.copyWith(voice: value));
                      }
                    },
            ),
          ],
          // With one voice for every line there is nobody to tell apart.
          if (mode != VoiceMode.chosen) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Switch(
                  value: settings.overlapVoices,
                  onChanged: running
                      ? null
                      : (value) => context.read<SettingsCubit>().update(
                          settings.copyWith(overlapVoices: value),
                        ),
                ),
                const SizedBox(width: 6),
                Flexible(child: Text(l10n.voiceOverlap)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.voiceOverlapNote,
              style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 12),
            ),
          ],
          // Which voice the automatic choice actually settled on, so it is
          // not a silent decision — the same courtesy the detected language
          // gets on the live screen.
          if (mode != VoiceMode.chosen ? pipeline.spokenVoice : null case final speaking?) ...[
            const SizedBox(height: 10),
            Text(
              mode == VoiceMode.original
                  ? l10n.voiceOriginalSpeaking(speaking)
                  : l10n.voiceSpeaking(speaking),
              style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

/// Whether the original voice remembers the characters, how many it has,
/// and a way to forget them. Forgetting cannot be undone, so it is asked.
class _VoiceBankControls extends StatelessWidget {
  const _VoiceBankControls({
    required this.settings,
    required this.size,
    required this.running,
  });

  final AppSettings settings;
  final int size;
  final bool running;

  Future<void> _confirmClear(BuildContext context) async {
    final settings = context.read<SettingsCubit>();
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(l10n.voiceBankClearTitle),
        content: Text(
          l10n.voiceBankClearMessage,
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.voiceBankClearCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.voiceBankClearConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await settings.clearVoiceBank();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Switch(
              value: settings.voiceBank,
              onChanged: running
                  ? null
                  : (value) =>
                        context.read<SettingsCubit>().update(settings.copyWith(voiceBank: value)),
            ),
            const SizedBox(width: 6),
            Flexible(child: Text(l10n.voiceBank)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          settings.voiceBank ? l10n.voiceBankOnNote : l10n.voiceBankOffNote,
          style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 12),
        ),
        // Shown with the switch off too: voices kept earlier are still on
        // disk, and this is where they are given back.
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.voiceBankCount(size),
                style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
              ),
            ),
            TextButton.icon(
              // The running worker holds the bank and would write it back.
              onPressed: running || size == 0 ? null : () => _confirmClear(context),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(l10n.voiceBankClear),
              style: TextButton.styleFrom(foregroundColor: LoreDubPalette.mutedInk),
            ),
          ],
        ),
      ],
    );
  }
}

/// The compute section: one preset for the whole pipeline, then a table of
/// stage by device showing what that preset actually resolved to and letting
/// any cell be picked, and the GPU packages as tiles. A backend the machine
/// cannot run is shown but faded, so an AMD owner can see that CUDA exists
/// and why it is not on offer.
class _ComputeDeviceCard extends StatelessWidget {
  const _ComputeDeviceCard();

  @override
  Widget build(BuildContext context) => BlocBuilder<DownloadsCubit, DownloadsState>(
    builder: (context, downloads) => BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) => BlocBuilder<PipelineCubit, LivePipelineState>(
        buildWhen: whenChanged((pipeline) => (pipeline.running, pipeline.backendSignature)),
        builder: (context, pipeline) => _build(context, downloads, state.settings, pipeline),
      ),
    ),
  );

  Widget _build(
    BuildContext context,
    DownloadsState downloads,
    AppSettings settings,
    LivePipelineState pipeline,
  ) {
    final l10n = AppLocalizations.of(context);
    final running = pipeline.running;
    final adapter = downloads.availability.adapters.firstOrNull;
    // OpenVoice runs only for the original voice, so its row waits for it.
    final stages = [
      for (final stage in ComputeStage.values)
        if (stage != ComputeStage.voiceConversion || settings.originalVoice) stage,
    ];
    final availability = downloads.availability;
    // The packages this machine could use, and any already on disk: a card
    // that was taken out must not strand gigabytes nobody can give back.
    final runtimes = [
      for (final runtime in downloads.runtimes)
        if (runtime.installed ||
            runtime.stoppable ||
            _servesHardware(runtime.package.id, availability))
          runtime,
    ];
    return SettingCard(
      title: l10n.settingsComputeDevice,
      subtitle: l10n.computeDeviceNote,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<ComputeDevice>(
            segments: [
              for (final device in ComputeDevice.values)
                ButtonSegment(value: device, label: Text(computeDeviceName(l10n, device))),
            ],
            selected: {settings.computeDevice},
            onSelectionChanged: running
                ? null
                : (selection) => context.read<SettingsCubit>().selectComputeDevice(selection.first),
          ),
          // What the choice leaves to say: the card a GPU run would use, or
          // -- everything being on the processor -- how much of it to use.
          // Automatic says neither: the table below shows where each stage
          // ended up, which is the answer it would have given.
          if (settings.computeDevice == ComputeDevice.gpu) ...[
            const SizedBox(height: 14),
            Text(
              adapter == null ? l10n.computeNoAdapter : l10n.computeAdapterDetected(adapter.name),
              style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
            ),
          ] else if (settings.computeDevice == ComputeDevice.cpu) ...[
            const SizedBox(height: 14),
            Text(
              l10n.performanceNote(Platform.numberOfProcessors, defaultCpuThreads()),
              style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: const ValueKey('cpuThreads'),
              initialValue: settings.cpuThreads,
              decoration: InputDecoration(labelText: l10n.cpuThreads),
              items: _threadOptions(settings.cpuThreads)
                  .map((value) => DropdownMenuItem(value: value, child: Text('$value')))
                  .toList(),
              onChanged: running
                  ? null
                  : (value) {
                      if (value != null) {
                        context.read<SettingsCubit>().update(settings.copyWith(cpuThreads: value));
                      }
                    },
            ),
          ],
          const SizedBox(height: 14),
          // Where recognition spends its time is not a matter of the device,
          // so this stands outside the branch above: the window whisper
          // listens over is the same on a processor and on a card.
          Row(
            children: [
              Switch(
                key: const ValueKey('roughRecognition'),
                value: settings.roughRecognition,
                onChanged: running
                    ? null
                    : (value) => context.read<SettingsCubit>().update(
                        settings.copyWith(roughRecognition: value),
                      ),
              ),
              const SizedBox(width: 6),
              Flexible(child: Text(l10n.roughRecognition)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.roughRecognitionNote,
            style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 13),
          ),
          const SizedBox(height: 14),
          // Stage by device: every cell says at a glance whether the stage
          // runs there, could, needs a package first, or cannot at all.
          for (final stage in stages)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 104,
                    child: Text(
                      computeStageName(l10n, stage),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  for (final backend in ComputeBackend.values) ...[
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: _cell(context, l10n, stage, backend, downloads, settings, pipeline),
                      ),
                    ),
                    if (backend != ComputeBackend.values.last) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          if (runtimes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l10n.computeRuntimesTitle,
              style: const TextStyle(
                fontFamily: LoreDubFonts.mono,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: LoreDubPalette.mutedInk,
              ),
            ),
            const SizedBox(height: 10),
            ModelTileGrid(
              children: [
                for (final runtime in runtimes)
                  RuntimeTile(
                    key: ValueKey('runtimeTile-${runtime.package.id}'),
                    state: runtime,
                    inUse: _inUse(runtime.package.id, stages, settings, pipeline, availability),
                    running: running,
                    stopping: downloads.isStopping(runtime.package.id),
                    onInstall: () => context.read<DownloadsCubit>().installRuntime(runtime),
                    onPause: () => context.read<DownloadsCubit>().pauseDownload(runtime.package.id),
                    onCancel: () =>
                        context.read<DownloadsCubit>().cancelDownload(runtime.package.id),
                    onRemove: () => context.read<DownloadsCubit>().removeRuntime(runtime),
                  ),
              ],
            ),
            // A failed install puts the tile back as it was, so without the
            // reason spelled out the press looked like it had done nothing.
            for (final runtime in runtimes)
              if (runtime.error case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SelectableText(
                    '${runtimeName(l10n, runtime.package.id)}: ${describeFailure(l10n, error)}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                  ),
                ),
          ],
          const SizedBox(height: 12),
          Text(
            l10n.computeSpeechNote,
            style: const TextStyle(color: LoreDubPalette.mutedInk, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    AppLocalizations l10n,
    ComputeStage stage,
    ComputeBackend backend,
    DownloadsState downloads,
    AppSettings settings,
    LivePipelineState pipeline,
  ) {
    final key = ValueKey('backendCell-${stage.name}-${backend.name}');
    final label = computeBackendName(l10n, backend);
    final running = pipeline.running;
    if (!stageBackends(stage).contains(backend)) {
      return BackendCell(
        key: key,
        label: label,
        state: BackendCellState.unsupported,
        tooltip: l10n.computeBackendUnsupported,
      );
    }
    if (!downloads.availability.supportsHardware(backend)) {
      return BackendCell(
        key: key,
        label: label,
        state: BackendCellState.noHardware,
        tooltip: l10n.computeBackendNoHardware,
      );
    }
    if (downloads.missingRuntimeFor(stage, backend) case final missing?) {
      final size = formatPackageSize(l10n, missing.package.approximateBytes);
      if (missing.progress case final progress?) {
        return BackendCell(
          key: key,
          label: label,
          state: BackendCellState.downloading,
          progress: progress,
          detail: missing.paused ? l10n.downloadPaused : '${(progress * 100).round()}%',
          tooltip: l10n.computeRuntimeDownloading(size),
        );
      }
      return BackendCell(
        key: key,
        label: label,
        state: BackendCellState.needsRuntime,
        detail: size,
        tooltip: '${l10n.computeRuntimeMissing(size)}\n${l10n.computeCellHintDownload}',
        onTap: running ? null : () => context.read<DownloadsCubit>().installRuntime(missing),
      );
    }
    // A runtime that is missing and not in the catalogue either: the cell
    // used to read as ready, and the press it invited stored a pin the
    // resolver then refused, so nothing moved and nothing said why.
    if (downloads.lacksBuiltInRuntime(stage, backend)) {
      return BackendCell(
        key: key,
        label: label,
        state: BackendCellState.unsupported,
        tooltip: l10n.computeBackendNotShipped,
      );
    }
    // While dubbing runs this is what the stage really settled on.
    final selected = pipeline.backendFor(stage, settings, downloads.availability) == backend;
    return BackendCell(
      key: key,
      label: label,
      state: selected ? BackendCellState.selected : BackendCellState.ready,
      tooltip: selected
          ? l10n.computeCellSelected
          : running
          ? l10n.computeCellLocked
          : l10n.computeCellSelect,
      onTap: selected || running
          ? null
          : () => context.read<SettingsCubit>().selectStageBackend(stage, backend),
    );
  }

  /// Whether any stage could put a runtime to use on this machine.
  static bool _servesHardware(String id, ComputeAvailability availability) {
    for (final stage in ComputeStage.values) {
      for (final backend in stageBackends(stage)) {
        if (requiredRuntimeId(stage, backend) == id && availability.supportsHardware(backend)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Whether a stage on the card runs on this runtime right now.
  static bool _inUse(
    String id,
    List<ComputeStage> stages,
    AppSettings settings,
    LivePipelineState pipeline,
    ComputeAvailability availability,
  ) => stages.any(
    (stage) => requiredRuntimeId(stage, pipeline.backendFor(stage, settings, availability)) == id,
  );
}

/// An action and the field that binds its combination.
class _HotkeyRow extends StatelessWidget {
  const _HotkeyRow({required this.label, required this.field});

  final String label;
  final Widget field;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 160,
        child: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      Expanded(child: field),
    ],
  );
}

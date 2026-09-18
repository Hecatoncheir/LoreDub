// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/app_settings.dart';
import '../../domain/compute_device.dart';
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
import '../theme.dart';
import 'cubits/characters_cubit.dart';
import 'cubits/dashboard_cubits.dart';
import 'cubits/downloads_cubit.dart';
import 'cubits/pipeline_cubit.dart';
import 'cubits/pipeline_graph_bloc.dart';
import 'cubits/settings_cubit.dart';
import 'cubits/shell_cubit.dart';
import 'glossary_screen.dart';
import 'compute_matrix.dart';
import 'dashboard_context.dart';
import 'hotkey_field.dart';
import 'model_tiles.dart';
import 'pipeline_canvas.dart';
import 'pipeline_inspector.dart';
import 'pipeline_shelf.dart';
import '../common/module_label.dart';
import '../common/setting_card.dart';
import '../common/error_banner.dart';
import '../shell/side_navigation.dart';
import '../shell/bottom_navigation.dart';
import '../shell/dashboard_header.dart';
import '../live/live_panel.dart';
import '../screen_text/snapshot_panel.dart';
import '../common/confirm_dialog.dart';
import '../characters/characters_panel.dart';
import '../models/models_panel.dart';

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
    final confirmed = await confirmRemoval(
      context,
      title: l10n.voiceBankClearTitle,
      message: l10n.voiceBankClearMessage,
      cancelLabel: l10n.voiceBankClearCancel,
      confirmLabel: l10n.voiceBankClearConfirm,
    );
    if (confirmed) await settings.clearVoiceBank();
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

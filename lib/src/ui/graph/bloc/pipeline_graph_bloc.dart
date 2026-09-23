// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:developer' show log;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/cast_repository.dart';
import '../../../data/repositories/glossary_repository.dart';
import '../../../data/repositories/install_repository.dart';
import '../../../domain/model_selection.dart';
import '../../../domain/session_coordinator.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/model_catalog.dart';
import '../../../domain/app_settings.dart';
import '../../../domain/character.dart';
import '../../../domain/glossary.dart';
import '../../../domain/id_source.dart';
import '../../../domain/pipeline_graph.dart';
import '../../../domain/saved_pipeline.dart';
import '../../../domain/spoken_language.dart';
import '../../shell/bloc/failure_cubit.dart';
import '../../../data/repositories/scheme_repository.dart';

part 'pipeline_graph_event.dart';
part 'pipeline_graph_state.dart';

/// Where a move of the translator leaves a canvas: what it reads and what
/// it says it in, or none -- with [refusal] saying why.
typedef _TranslatorMove = ({ScreenLanguages? languages, ConnectionRefusal refusal});

/// What one step back restores: where the nodes were, whether the game's
/// sound was drawn in, whose voice read whom, and which packs of the
/// glossary were switched on.
///
/// The canvas owns none of those but the first — they are the settings, the
/// cast and the glossary — so undo puts them back through the same calls an
/// edit makes, and the screen that shows them is right without being told.
class _GraphMemento {
  const _GraphMemento({
    required this.layout,
    required this.routed,
    required this.readers,
    required this.activePacks,
  });

  final PipelineLayout layout;

  /// Whether the game's sound was drawn in -- the way into Эфир's pipeline,
  /// the voices behind the Screen page's -- so a step back over a cut route
  /// puts the link there again.
  final bool routed;

  final Map<String, String?> readers;

  /// The packs whose lines ran into the voice.
  final Set<String> activePacks;
}

/// One of the two canvases: Эфир's, drawing the dubbing of the game's
/// sound, or -- with [scheme] set to it -- the Screen page's, drawing the
/// reading of its screen.
///
/// The two are the same machine over different stages. Each keeps its own
/// arrangement and its own shelf, and tells what it cuts and what it lets
/// the glossary apply only to a session started from it; the settings, the
/// cast and the glossary they draw are the same ones, so a card or a pack
/// changed on one is changed on the other.
class PipelineGraphBloc extends Bloc<PipelineGraphEvent, PipelineGraphState> {
  PipelineGraphBloc(
    this._schemes,
    this._settings,
    this._characters,
    this._glossary,
    this._installed,
    this._sessions,
    this._errors, {
    DateTime Function()? clock,
    PipelineScheme scheme = PipelineScheme.live,
  }) : _ids = IdSource(clock: clock),
       _scheme = scheme,
       super(PipelineGraphState(layout: PipelineLayout.standardOf(scheme))) {
    on<PipelineGraphOpened>(_onOpened);
    on<PipelineGraphRefreshed>((event, emit) => emit(_redrawn(state)));
    on<PipelineNodeGrabbed>(_onGrabbed);
    on<PipelineNodeMoved>(_onMoved);
    on<PipelineArrangementSettled>((event, emit) => _persist());
    on<PipelineNodeSelected>(_onSelected);
    on<PipelineSelectionSet>(
      (event, emit) => emit(_choosing(event.nodeIds)),
    );
    on<PipelineLinkStarted>(
      (event, emit) => emit(
        state.copyWith(
          drag: PipelineLinkDrag(from: event.port, at: event.at),
          clearRefusal: true,
        ),
      ),
    );
    on<PipelineLinkDragged>((event, emit) {
      final drag = state.drag;
      if (drag == null) return;
      emit(
        state.copyWith(
          drag: PipelineLinkDrag(from: drag.from, at: event.at),
        ),
      );
    });
    on<PipelineLinkReleased>(_onReleased);
    on<PipelineLinkCut>(_onCut);
    on<PipelineCharacterPlaced>(_onCharacterPlaced);
    on<PipelineNodeRemoved>(_onNodeRemoved);
    on<PipelineGlossaryPlaced>(_onGlossaryPlaced);
    on<PipelineGlossaryPackChosen>(_onGlossaryPackChosen);
    on<PipelineGlossarySwitched>(_onGlossarySwitched);
    // The switch on the detection is its route drawn or cut: one setting,
    // with the same refusals.
    on<PipelineVoicesSwitched>((event, emit) => _apply(VoicesConnection(event.heard), emit));
    on<PipelineViewPanned>(
      (event, emit) => emit(_withView(state.layout.view.panned(event.dx, event.dy))),
    );
    on<PipelineViewZoomed>(
      (event, emit) => emit(_withView(state.layout.view.zoomedAt(event.zoom, event.focus))),
    );
    on<PipelineViewSet>((event, emit) => emit(_withView(event.view)));
    on<PipelineLayoutReset>(_onReset);
    on<PipelineSchemeSaved>(_onSchemeSaved);
    on<PipelineSchemeChosen>(_onSchemeChosen);
    on<PipelineSchemeReplaced>(_onSchemeReplaced);
    on<PipelineSchemeRenamed>(_onSchemeRenamed);
    on<PipelineSchemeRemoved>(_onSchemeRemoved);
    on<PipelineSchemeExported>(_onSchemeExported);
    on<PipelineSchemeImported>(_onSchemeImported);
    on<PipelineGraphUndone>(_onUndone);
    on<PipelineGraphRedone>(_onRedone);

    // The canvas is a second window onto the settings, the cast and the
    // glossary: a language picked here or on another screen is the same
    // change, and so is a pack switched on, so it is redrawn from them
    // rather than kept twice.
    _settingsChanges = _settings.changes.listen((_) => add(const PipelineGraphRefreshed()));
    _characterChanges = _characters.changes.listen((_) => add(const PipelineGraphRefreshed()));
    _glossaryChanges = _glossary.changes.listen((_) => add(const PipelineGraphRefreshed()));
  }

  final SchemeRepository _schemes;
  final SettingsRepository _settings;
  final CastRepository _characters;
  final GlossaryRepository _glossary;
  final InstallRepository _installed;

  /// Which of the two canvases this is.
  final PipelineScheme _scheme;

  /// Where the engine stands, which the route may not be changed under.
  final SessionCoordinator _sessions;
  final FailureSink _errors;
  final IdSource _ids;

  late final StreamSubscription<AppSettings> _settingsChanges;
  late final StreamSubscription<CharacterLibrary> _characterChanges;
  late final StreamSubscription<Glossary> _glossaryChanges;

  /// What the glossary was last told the packs on the canvas may apply, so
  /// it is told again only when that changes.
  GlossaryReach? _toldReach;

  /// How far back the canvas remembers. Long enough to undo an evening's
  /// rewiring, short enough that the list is never a concern.
  static const historyDepth = 40;

  final List<_GraphMemento> _past = [];
  final List<_GraphMemento> _future = [];

  List<Character> get _cast => _characters.cast;

  /// The repository raises what went wrong; this screen has a banner of
  /// its own to put it in.
  Future<void> _voiceCharacterAs(String id, String? target) async {
    try {
      await _characters.voiceAs(id, target);
    } catch (exception) {
      _errors.report(exception);
    }
  }

  Future<void> _readAsHeard(Set<String> ids) async {
    try {
      await _characters.readAsHeard(ids, scheme: _scheme);
    } catch (exception) {
      _errors.report(exception);
    }
  }

  Future<void> _saveGlossary(Glossary glossary) async {
    try {
      await _glossary.save(glossary);
    } catch (exception) {
      _errors.report(exception);
    }
  }

  Future<void> _narrow(GlossaryReach reach) async {
    try {
      await _glossary.narrow(reach, scheme: _scheme);
    } catch (exception) {
      _errors.report(exception);
    }
  }

  /// The packs switched on now.
  Set<String> get _activePacks => {for (final pack in _glossary.glossary.activePacks) pack.id};

  /// Whether this canvas's translator stands in the line: Эфир's while the
  /// dubbing is not into English, the Screen page's while its text is
  /// English to be translated.
  bool get _translates => switch (_scheme) {
    PipelineScheme.live => _settings.settings.translates,
    PipelineScheme.screen => _settings.settings.screenTranslates,
  };

  /// Whether the game's sound is drawn in: the way into Эфир's pipeline,
  /// or into the Screen page's character detection. It is what a scheme on
  /// the shelf keeps of the route, and what a step back puts back of it.
  bool get _routed => switch (_scheme) {
    PipelineScheme.live => _settings.settings.captureRouted,
    PipelineScheme.screen => _settings.settings.screenVoices,
  };

  /// The settings with the game's sound drawn in, or not, on this canvas.
  AppSettings _withRoute(bool routed) => switch (_scheme) {
    PipelineScheme.live => _settings.settings.copyWith(captureRouted: routed),
    PipelineScheme.screen => _settings.settings.copyWith(screenVoices: routed),
  };

  /// Keeps [glossary] when it is not what is kept already, and answers with
  /// the write, or null when there is none to wait for.
  ///
  /// The repository publishes it before the disk is asked, so a layout
  /// emitted right after the call is drawn with its packs switched as they
  /// now are, in the same frame rather than a redraw later.
  Future<void>? _keepPacks(Glossary glossary) =>
      identical(glossary, _glossary.glossary) ? null : _saveGlossary(glossary);

  /// Draws [layout], an edit of the canvas, and the switches of the glossary
  /// made to follow it: a pack the edit put in the line of text is switched
  /// on, and one it took out switched off.
  Future<void> _settle(
    PipelineLayout layout,
    Emitter<PipelineGraphState> emit, {
    String? select,
    bool clearSelected = false,
  }) async {
    final saving = _keepPacks(packsFollowingLine(_glossary.glossary, state.layout, layout));
    final was = state.layout.silent;
    emit(
      _redrawn(
        state.copyWith(
          layout: layout,
          selected: select,
          clearSelected: clearSelected,
          clearRefusal: true,
        ),
      ),
    );
    _persist();
    if (!_sameCards(was, layout.silent)) await _readAsHeard(layout.silent);
    await saving;
  }

  /// The pack drawn at [event]'s node switched on or off. Nothing of the
  /// drawing moves: switched off, it stays in the line and the text passes
  /// through it as it came. The switch is the pack's -- the glossary screen
  /// shows the same one -- so every drawing of the pack answers together.
  Future<void> _onGlossarySwitched(
    PipelineGlossarySwitched event,
    Emitter<PipelineGraphState> emit,
  ) async {
    final pack = _glossary.glossary.packWithId(state.layout.glossaryAt(event.nodeId)?.packId ?? '');
    if (pack == null || pack.active == event.active) return;
    _remember();
    emit(state.copyWith(clearRefusal: true));
    await _saveGlossary(_glossary.glossary.activating(pack.id, active: event.active));
  }

  /// Whether the route may be changed at all. A running session holds the
  /// models it started with, so the way in is settled until it stops; whose
  /// voice reads whom is not, and the worker is told of it as it runs.
  bool get _routeLocked => _sessions.dubbingRuns;

  Future<void> _onOpened(PipelineGraphOpened event, Emitter<PipelineGraphState> emit) async {
    if (!state.loading) return;
    // Drawn from the settings, the cast and the glossary, so after all
    // three are read; each is read once whoever asks first, so it does not
    // matter who started. A read that failed is reported by the screen that
    // owns it; the canvas draws what there is.
    try {
      await Future.wait([_settings.load(), _characters.load(), _glossary.load()]);
    } catch (exception) {
      log('scheme drawn without what it is drawn from: $exception', name: 'PipelineGraphBloc');
    }
    // What the canvas stood on when the disk was asked. A bloc serves each
    // kind of event on a stream of its own, so a card placed while this was
    // waiting has already landed — and the arrangement read here must not
    // undo it.
    final before = state.layout;
    var layout = PipelineLayout.standardOf(_scheme);
    var schemes = const <SavedPipeline>[];
    try {
      layout = await _schemes.loadLayout(scheme: _scheme);
    } catch (exception) {
      log('pipeline layout not read: $exception', name: 'PipelineGraphBloc');
    }
    try {
      schemes = (await _schemes.loadSchemes(scheme: _scheme)).pipelines;
    } catch (exception) {
      log('saved schemes not read: $exception', name: 'PipelineGraphBloc');
    }
    if (isClosed) return;
    emit(
      _redrawn(
        state.copyWith(
          loading: false,
          layout: identical(state.layout, before) ? layout : state.layout,
          schemes: schemes,
        ),
      ),
    );
  }

  /// The scheme as it stands: the route, the arrangement, whose voice
  /// reads whom among the cards drawn on it, and which packs of the
  /// glossary are switched on. The models and the languages are left out —
  /// they belong to the machine, not to the drawing.
  SavedPipeline _asScheme(String id, String name) {
    final drawn = {for (final placement in state.layout.cast) placement.characterId};
    return SavedPipeline(
      id: id,
      name: name,
      scheme: _scheme,
      captureRouted: _routed,
      layout: state.layout,
      readers: {
        for (final character in _cast)
          if (drawn.contains(character.id)) character.id: character.voicedBy,
      },
      activePacks: _activePacks,
    );
  }

  Future<void> _onSchemeSaved(
    PipelineSchemeSaved event,
    Emitter<PipelineGraphState> emit,
  ) async {
    final name = event.name.trim();
    if (name.isEmpty) return;
    final scheme = _asScheme(_ids.next(), name);
    await _keep([...state.schemes, scheme], emit);
  }

  /// Draws a kept scheme and makes it the one that runs.
  ///
  /// Everything goes back through the calls an edit makes — the settings for
  /// the route, the cast for the substitutions — so the other screens are
  /// right without being told, and one step back puts the old scheme up.
  Future<void> _onSchemeChosen(
    PipelineSchemeChosen event,
    Emitter<PipelineGraphState> emit,
  ) async {
    final scheme = state.schemes.where((value) => value.id == event.id).firstOrNull;
    if (scheme == null) return;
    if (_routeLocked && scheme.captureRouted != _routed) {
      emit(state.copyWith(refusal: ConnectionRefusal.locked));
      return;
    }
    final wasSilent = state.layout.silent;
    _remember();
    // Which packs are read is the whole picture as well, over the whole
    // glossary; a scheme kept before the glossary was drawn says nothing of
    // them and leaves them as they are. Switched before the arrangement is
    // drawn, so its nodes are drawn switched as the scheme has them.
    final switching = _keepPacks(switch (scheme.activePacks) {
      final packs? => _glossary.glossary.switchedTo(packs),
      null => _glossary.glossary,
    });
    emit(
      _redrawn(
        state.copyWith(
          layout: scheme.layout,
          chosen: const {},
          clearSelected: true,
          clearRefusal: true,
        ),
      ),
    );
    _persist();
    await _settings.save(_withRoute(scheme.captureRouted));
    // Which cards the scheme cuts out of the mix travels with its
    // arrangement, so a session already running is told the moment it is put
    // up rather than at the next start.
    if (!_sameCards(wasSilent, scheme.layout.silent)) {
      await _readAsHeard(scheme.layout.silent);
    }
    // The scheme is the whole picture of who reads whom, so it is put back
    // over the whole cast rather than over the cards it happens to name: a
    // card this scheme does not draw is read by nobody. Kept the other way,
    // an empty scheme changed nothing at all and the arrangement it replaced
    // went on sounding under a canvas that said nothing about it.
    for (final character in _cast) {
      final reader = scheme.readers[character.id];
      if (character.voicedBy == reader) continue;
      await _voiceCharacterAs(character.id, reader);
    }
    await switching;
  }

  /// The scheme keeps its name and its place on the shelf; everything the
  /// canvas says now is written into it.
  Future<void> _onSchemeReplaced(
    PipelineSchemeReplaced event,
    Emitter<PipelineGraphState> emit,
  ) async {
    final kept = state.schemes.where((value) => value.id == event.id).firstOrNull;
    if (kept == null) return;
    final written = _asScheme(kept.id, kept.name);
    await _keep([
      for (final scheme in state.schemes)
        if (scheme.id == kept.id) written else scheme,
    ], emit);
  }

  Future<void> _onSchemeRenamed(
    PipelineSchemeRenamed event,
    Emitter<PipelineGraphState> emit,
  ) async {
    final name = event.name.trim();
    if (name.isEmpty) return;
    await _keep([
      for (final scheme in state.schemes)
        if (scheme.id == event.id) scheme.copyWith(name: name) else scheme,
    ], emit);
  }

  Future<void> _onSchemeRemoved(
    PipelineSchemeRemoved event,
    Emitter<PipelineGraphState> emit,
  ) async {
    await _keep([
      for (final scheme in state.schemes)
        if (scheme.id != event.id) scheme,
    ], emit);
  }

  Future<void> _onSchemeExported(
    PipelineSchemeExported event,
    Emitter<PipelineGraphState> emit,
  ) async {
    final scheme = state.schemes.where((value) => value.id == event.id).firstOrNull;
    if (scheme == null) return;
    try {
      await _schemes.exportSchemes(event.destination, [scheme]);
    } catch (exception) {
      _errors.report(exception);
    }
  }

  /// Schemes read from files. One that carries an id already on the shelf
  /// lands on the scheme it came from, the way an imported card does. Only
  /// this canvas's are read: a file holding the other one's is refused by
  /// name, as a file holding none is.
  Future<void> _onSchemeImported(
    PipelineSchemeImported event,
    Emitter<PipelineGraphState> emit,
  ) async {
    List<SavedPipeline> incoming;
    try {
      incoming = await _schemes.importSchemes(event.sources, scheme: _scheme);
    } catch (exception) {
      _errors.report(exception);
      return;
    }
    final byId = {for (final scheme in state.schemes) scheme.id: scheme};
    for (final scheme in incoming) {
      byId[scheme.id] = scheme;
    }
    await _keep(byId.values.toList(), emit);
  }

  /// Writes the shelf and shows it. The schemes are the player's own, so a
  /// folder that cannot be written to costs a message rather than the edit.
  Future<void> _keep(List<SavedPipeline> schemes, Emitter<PipelineGraphState> emit) async {
    emit(state.copyWith(schemes: schemes));
    try {
      await _schemes.saveSchemes(PipelineLibrary(pipelines: schemes), scheme: _scheme);
    } catch (exception) {
      _errors.report(exception);
    }
  }

  /// A click on a node, with or without shift. Without, the choice becomes
  /// that node alone; with, the node joins the choice or leaves it.
  void _onSelected(PipelineNodeSelected event, Emitter<PipelineGraphState> emit) {
    final nodeId = event.nodeId;
    if (nodeId == null) {
      emit(state.copyWith(clearSelected: true, chosen: const {}));
      return;
    }
    if (!event.add) {
      emit(state.copyWith(selected: nodeId, chosen: {nodeId}));
      return;
    }
    final chosen = {...state.chosen};
    if (!chosen.remove(nodeId)) chosen.add(nodeId);
    emit(_choosing(chosen));
  }

  /// The state with [nodeIds] chosen. The inspector follows a choice of one
  /// and closes over any other number: it shows the settings of a node, and
  /// there is no such thing as the settings of five.
  PipelineGraphState _choosing(Set<String> nodeIds) => nodeIds.length == 1
      ? state.copyWith(selected: nodeIds.first, chosen: nodeIds)
      : state.copyWith(clearSelected: true, chosen: nodeIds);

  void _onGrabbed(PipelineNodeGrabbed event, Emitter<PipelineGraphState> emit) {
    _remember();
    // A node taken hold of from outside the choice becomes the choice; one
    // already in it keeps the others, so a group is dragged by any of them.
    emit(
      state.chosen.contains(event.nodeId)
          ? state.copyWith(clearRefusal: true)
          : state.copyWith(selected: event.nodeId, chosen: {event.nodeId}, clearRefusal: true),
    );
  }

  void _onMoved(PipelineNodeMoved event, Emitter<PipelineGraphState> emit) {
    final node = state.graph.node(event.nodeId);
    if (node == null) return;
    // Everything chosen moves with the node the pointer has: a group keeps
    // its shape, so the whole choice is held back by whichever of them
    // reaches the edge of the world first rather than folding against it.
    final moving = [
      for (final id in state.chosen.contains(event.nodeId) ? state.chosen : {event.nodeId})
        ?state.graph.node(id),
    ];
    if (moving.isEmpty) return;
    var dx = event.dx;
    var dy = event.dy;
    for (final chosen in moving) {
      final held = GraphWorld.hold(chosen.position.translate(dx, dy));
      dx = held.x - chosen.position.x;
      dy = held.y - chosen.position.y;
    }
    if (dx == 0 && dy == 0) return;
    var layout = state.layout;
    for (final chosen in moving) {
      layout = layout.withPosition(chosen.id, chosen.position.translate(dx, dy));
    }
    emit(_redrawn(state.copyWith(layout: layout)));
  }

  Future<void> _onReleased(
    PipelineLinkReleased event,
    Emitter<PipelineGraphState> emit,
  ) async {
    final drag = state.drag;
    emit(state.copyWith(clearDrag: true));
    final target = event.target;
    if (drag == null || target == null) return;
    await _apply(
      proposeConnection(state.graph, drag.from, target, characters: _cast),
      emit,
      joining: {drag.from.nodeId, target.nodeId},
    );
  }

  Future<void> _onCut(PipelineLinkCut event, Emitter<PipelineGraphState> emit) =>
      _apply(proposeDisconnect(event.link), emit);

  /// [layout] with every card [nodeIds] names back in the mix.
  ///
  /// A line drawn to a card or away from one is the player wiring that card
  /// up, whichever end they started at: a card left cut would take the line
  /// and show nothing for it, which reads as a drop that missed.
  PipelineLayout _joined(PipelineLayout layout, Set<String> nodeIds) {
    var next = layout;
    for (final nodeId in nodeIds) {
      if (PipelineNodeIds.characterOf(nodeId) case final character?) {
        next = next.withVoiced(character, true);
      }
    }
    return next;
  }

  /// What the settings and the downloads together say.
  ModelSelection get _selection =>
      ModelSelection(models: _installed.parts.models, settings: _settings.settings);

  /// The language the translator is put back on: the first one downloaded
  /// that has a translator at all, in the order the models screen lists them.
  ///
  /// The canvas cannot ask which language was meant -- a line has no room for
  /// the question -- and a player who has downloaded one pair means that one.
  /// The models screen shows at once which it was, and one step back undoes
  /// it, so the guess costs nothing when it is wrong.
  String? get _languageToTranslateInto {
    for (final pair in _selection.languagePairs) {
      if (pair.language == untranslatedDubbingLanguage) continue;
      if (pair.installed) return pair.language;
    }
    return null;
  }

  /// The language the Screen page's translator is put back on: the dubbing
  /// language itself where its translator is on disk -- the player reading
  /// Russian text who draws the translator back means English into the same
  /// Russian -- and otherwise the one Эфир's canvas would take.
  String? get _screenLanguageToTranslateInto {
    final dubbing = _settings.settings.targetLanguage;
    final kept = dubbing != untranslatedDubbingLanguage && _selection.isLanguageReady(dubbing);
    return kept ? dubbing : _languageToTranslateInto;
  }

  /// Эфир's translator moved: out of the line is dubbing into English,
  /// which whisper hands over already, and back into it a language that has
  /// a translator. A catalogue carrying no English voice would have no line
  /// without the translator at all, and the cut is refused rather than left
  /// to end in a session with nothing to read it.
  _TranslatorMove _liveTranslatorMoved(bool routed) {
    if (!routed && !dubbingLanguages.contains(untranslatedDubbingLanguage)) {
      return (languages: null, refusal: ConnectionRefusal.unsupported);
    }
    final language = routed ? _languageToTranslateInto : untranslatedDubbingLanguage;
    return (
      languages: language == null ? null : (text: fallbackSpokenLanguage, dubbing: language),
      refusal: ConnectionRefusal.translatorMissing,
    );
  }

  /// The Screen page's translator moved: out of the line, what the screen
  /// shows is read as the dubbing language itself -- there is always its
  /// voice to read it -- and back into it, it is English to be translated.
  _TranslatorMove _screenTranslatorMoved(bool routed) {
    final dubbing = _settings.settings.targetLanguage;
    if (!routed) {
      return (languages: (text: dubbing, dubbing: dubbing), refusal: ConnectionRefusal.unsupported);
    }
    final language = _screenLanguageToTranslateInto;
    return (
      languages: language == null ? null : (text: fallbackSpokenLanguage, dubbing: language),
      refusal: ConnectionRefusal.translatorMissing,
    );
  }

  /// [settings] reading and saying [languages] on this canvas: the dubbing
  /// language on Эфир, where what is read is always whisper's English, and
  /// both on the Screen page, where the text's language is chosen as well.
  AppSettings _speaking(AppSettings settings, ScreenLanguages languages) => switch (_scheme) {
    PipelineScheme.live => settings.withTargetLanguage(languages.dubbing),
    PipelineScheme.screen => settings.withScreenLanguages(
      text: languages.text,
      dubbing: languages.dubbing,
    ),
  };

  /// Carries out what the canvas proposed, or says why it could not.
  ///
  /// [joining] is the two ends of a line just drawn, which is what tells a
  /// link the player made from one the canvas is taking apart.
  Future<void> _apply(
    GraphConnection connection,
    Emitter<PipelineGraphState> emit, {
    Set<String> joining = const {},
  }) async {
    switch (connection) {
      case UnchangedConnection():
        return;
      case RefusedConnection(:final reason):
        emit(state.copyWith(refusal: reason));
      case RouteConnection(:final routed):
        if (_routeLocked) {
          emit(state.copyWith(refusal: ConnectionRefusal.locked));
          return;
        }
        _remember();
        emit(state.copyWith(clearRefusal: true));
        await _settings.save(_settings.settings.copyWith(captureRouted: routed));
      case TranslationConnection(:final routed, :final edits):
        await _moveTranslator(routed, edits, emit);
      case VoicesConnection(:final heard):
        await _hearVoices(heard, emit);
      // A card into the mix, or out of it. Not locked with the route: a
      // session keeps its cast loaded either way, and the worker is told.
      //
      // Joined, the drawing the line came from is one the game is expected
      // to speak: a card with no part of its own and nobody to read for has
      // nothing to send, and the line would come to nothing.
      case CastConnection(:final characterId, :final nodeId, :final routed):
        _remember();
        await _voiceCard(
          characterId,
          routed,
          routed ? _joined(state.layout, joining).withHeard(nodeId, true) : state.layout,
          emit,
        );
      case ReaderConnection(:final characterId, :final readerId):
        _remember();
        await _relayout(_joined(state.layout, joining), emit);
        await _voiceCharacterAs(characterId, readerId);
      // A note on the card, kept with the arrangement: nothing of the
      // pipeline changes with it, so nothing is written through.
      case HeardConnection(:final nodeId, :final heard):
        _remember();
        await _relayout(_joined(state.layout, joining).withHeard(nodeId, heard), emit);
      // Packs of the glossary into the line of text, out of it, or along it:
      // the arrangement's, with the switches following. Not locked with the
      // route -- a running worker is told what its glossary puts right now,
      // as it is when an entry is written down.
      case GlossaryLineConnection(:final edits):
        _remember();
        await _settle(state.layout.withLine(edits, translates: _translates), emit);
    }
  }

  /// The translator out of the line, or back into it, and the packs of the
  /// glossary the same line moved.
  ///
  /// There is no setting of its own behind this: it is what is read and
  /// what it is said in. On Эфир dubbing into English is what has nothing to
  /// translate, so taking the stage out chooses English and putting it back
  /// chooses a language that has a translator; on the Screen page it is the
  /// language of the text on the screen. Locked with the route, the models
  /// being loaded for the session that runs.
  Future<void> _moveTranslator(
    bool routed,
    List<LineEdit> edits,
    Emitter<PipelineGraphState> emit,
  ) async {
    if (_routeLocked) {
      emit(state.copyWith(refusal: ConnectionRefusal.locked));
      return;
    }
    final moved = switch (_scheme) {
      PipelineScheme.live => _liveTranslatorMoved(routed),
      PipelineScheme.screen => _screenTranslatorMoved(routed),
    };
    final languages = moved.languages;
    if (languages == null) {
      emit(state.copyWith(refusal: moved.refusal));
      return;
    }
    _remember();
    emit(state.copyWith(clearRefusal: true));
    if (edits.isNotEmpty) await _settle(state.layout.withLine(edits, translates: routed), emit);
    // Both the translator and the voice: text in one language read by a
    // voice for another would be gibberish.
    await _settings.save(_speaking(_settings.settings, languages));
  }

  /// Whether the voices behind the screen are told apart: the detection's
  /// route drawn or cut, or its switch thrown -- one setting three ways.
  ///
  /// It is the converter that hears who is speaking, so without it on disk
  /// nothing is drawn in; and it is loaded for the session that runs, so the
  /// route stays as it is until that session stops, as Эфир's does.
  Future<void> _hearVoices(bool heard, Emitter<PipelineGraphState> emit) async {
    if (_routeLocked) {
      emit(state.copyWith(refusal: ConnectionRefusal.locked));
      return;
    }
    if (heard && !_selection.measuresVoices) {
      emit(state.copyWith(refusal: ConnectionRefusal.converterMissing));
      return;
    }
    if (_settings.settings.screenVoices == heard) return;
    _remember();
    emit(state.copyWith(clearRefusal: true));
    await _settings.save(_settings.settings.copyWith(screenVoices: heard));
  }

  Future<void> _onCharacterPlaced(
    PipelineCharacterPlaced event,
    Emitter<PipelineGraphState> emit,
  ) async {
    _remember();
    final layout = state.layout.withCharacter(event.characterId);
    emit(_redrawn(state.copyWith(layout: layout, selected: layout.cast.last.nodeId)));
    _persist();
  }

  /// A pack drawn on the canvas, out of the line until a line puts it
  /// there -- or in it at once, where more of it applies, when the pack is
  /// switched on and stands in the line nowhere else. Its panel opens with
  /// it.
  Future<void> _onGlossaryPlaced(
    PipelineGlossaryPlaced event,
    Emitter<PipelineGraphState> emit,
  ) async {
    if (_glossary.glossary.packWithId(event.packId) == null) return;
    _remember();
    final layout = state.layout.withGlossary(event.packId);
    await _settle(layout, emit, select: layout.glossaries.last.nodeId);
  }

  /// The drawing at [event]'s node reading another pack, where it stands:
  /// the pack it read leaves the line with it, and the one it reads now
  /// joins it there.
  Future<void> _onGlossaryPackChosen(
    PipelineGlossaryPackChosen event,
    Emitter<PipelineGraphState> emit,
  ) async {
    final placement = state.layout.glossaryAt(event.nodeId);
    if (placement == null || placement.packId == event.packId) return;
    if (_glossary.glossary.packWithId(event.packId) == null) return;
    _remember();
    await _settle(state.layout.withGlossaryPack(event.nodeId, event.packId), emit);
  }

  Future<void> _onNodeRemoved(
    PipelineNodeRemoved event,
    Emitter<PipelineGraphState> emit,
  ) async {
    _remember();
    await _settle(
      state.layout.withoutNode(event.nodeId),
      emit,
      clearSelected: state.selected == event.nodeId,
    );
  }

  /// Every node back where a scheme nobody arranged puts it. What is drawn
  /// stays drawn -- the cards, and the packs with the text each reads --
  /// only where it stands is forgotten.
  Future<void> _onReset(PipelineLayoutReset event, Emitter<PipelineGraphState> emit) async {
    _remember();
    emit(
      _redrawn(
        state.copyWith(
          layout: PipelineLayout(cast: state.layout.cast, glossaries: state.layout.glossaries),
          clearRefusal: true,
        ),
      ),
    );
    _persist();
  }

  Future<void> _onUndone(PipelineGraphUndone event, Emitter<PipelineGraphState> emit) async {
    if (_past.isEmpty) return;
    final memento = _past.removeLast();
    _future.add(_snapshot());
    await _restore(memento, emit);
  }

  Future<void> _onRedone(PipelineGraphRedone event, Emitter<PipelineGraphState> emit) async {
    if (_future.isEmpty) return;
    final memento = _future.removeLast();
    _past.add(_snapshot());
    await _restore(memento, emit);
  }

  /// Puts a remembered state back the way an edit makes one: the settings,
  /// the cast and the glossary are written through, and the canvas follows
  /// them.
  Future<void> _restore(_GraphMemento memento, Emitter<PipelineGraphState> emit) async {
    final wasSilent = state.layout.silent;
    // The packs first, so the nodes are drawn switched as they were.
    final switching = _keepPacks(_glossary.glossary.switchedTo(memento.activePacks));
    emit(_redrawn(state.copyWith(layout: memento.layout, clearRefusal: true)));
    _persist();
    if (!_sameCards(wasSilent, memento.layout.silent)) {
      await _readAsHeard(memento.layout.silent);
    }
    if (!_routeLocked && _routed != memento.routed) {
      await _settings.save(_withRoute(memento.routed));
    }
    for (final entry in memento.readers.entries) {
      final now = _cast.firstWhere(
        (character) => character.id == entry.key,
        orElse: () => const Character(id: '', name: '', vector: []),
      );
      if (now.id.isEmpty || now.voicedBy == entry.value) continue;
      await _voiceCharacterAs(entry.key, entry.value);
    }
    await switching;
    if (isClosed) return;
    emit(_redrawn(state.copyWith(canUndo: _past.isNotEmpty, canRedo: _future.isNotEmpty)));
  }

  /// Puts one card's voice in the mix or takes it out. The arrangement
  /// holds it for the next session, and a session already running is told,
  /// so the card falls silent — or stands in again — from the next line
  /// rather than the next start.
  Future<void> _voiceCard(
    String characterId,
    bool routed,
    PipelineLayout from,
    Emitter<PipelineGraphState> emit,
  ) async {
    final layout = from.withVoiced(characterId, routed);
    emit(_redrawn(state.copyWith(layout: layout, clearRefusal: true)));
    _persist();
    await _readAsHeard(layout.silent);
  }

  /// Draws the canvas on [layout] and keeps it, telling a running session
  /// when the cards it hears have changed.
  Future<void> _relayout(PipelineLayout layout, Emitter<PipelineGraphState> emit) async {
    final was = state.layout.silent;
    emit(_redrawn(state.copyWith(layout: layout, clearRefusal: true)));
    _persist();
    if (!_sameCards(was, layout.silent)) await _readAsHeard(layout.silent);
  }

  /// Whether two sets name the same cards. The worker is told only when
  /// they differ: a scheme put up over the same cut changes nothing.
  static bool _sameCards(Set<String> first, Set<String> second) =>
      first.length == second.length && first.every(second.contains);

  _GraphMemento _snapshot() => _GraphMemento(
    layout: state.layout,
    routed: _routed,
    readers: {for (final character in _cast) character.id: character.voicedBy},
    activePacks: _activePacks,
  );

  /// Keeps where things stood before an edit. Called by the edit rather than
  /// by every emit, so a drag of a node is one step back, not a hundred.
  void _remember() {
    _past.add(_snapshot());
    if (_past.length > historyDepth) _past.removeAt(0);
    _future.clear();
  }

  /// The state with the graph rebuilt from the settings, the cast, the
  /// glossary and the arrangement it now carries.
  PipelineGraphState _redrawn(PipelineGraphState value) {
    final graph = buildPipelineGraph(
      settings: _settings.settings,
      characters: _cast,
      packs: _glossary.glossary.packs,
      layout: value.layout,
      scheme: _scheme,
    );
    _followReach(value.layout);
    // A card taken off the canvas leaves the choice with it, so a drag does
    // not carry a node that is no longer drawn.
    final chosen = {
      for (final id in value.chosen)
        if (graph.node(id) != null) id,
    };
    return value.copyWith(
      graph: graph,
      chosen: chosen.length == value.chosen.length ? null : chosen,
      canUndo: _past.isNotEmpty,
      canRedo: _future.isNotEmpty,
    );
  }

  /// Tells the glossary what the packs drawn on [layout] may apply, when
  /// that is not what it was last told, so a session already running reads
  /// with the drawing as it changes rather than from the next start.
  ///
  /// Asked on every redraw rather than by the edits that move a pack: the
  /// language decides it as much as the drawing does -- with nothing to
  /// translate, what whisper heard is where a word is met -- and a redraw
  /// is what follows either.
  void _followReach(PipelineLayout layout) {
    final reach = layout.glossaryReach(translates: _translates);
    final told = _toldReach;
    if (told != null && sameGlossaryReach(told, reach)) return;
    _toldReach = reach;
    unawaited(_narrow(reach));
  }

  PipelineGraphState _withView(GraphView view) =>
      state.copyWith(layout: state.layout.copyWith(view: view));

  /// Writes the arrangement, without holding the event queue while the disk
  /// answers: the canvas has already moved, and where the nodes sit is a
  /// courtesy rather than part of the edit. A folder that cannot be written
  /// to therefore costs a message and not the next gesture.
  void _persist() {
    unawaited(_write());
  }

  Future<void> _write() async {
    try {
      await _schemes.saveLayout(state.layout, scheme: _scheme);
    } catch (exception) {
      _errors.report(exception);
    }
  }

  @override
  Future<void> close() async {
    await _settingsChanges.cancel();
    await _characterChanges.cancel();
    await _glossaryChanges.cancel();
    return super.close();
  }
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/app_repository.dart';
import '../../../domain/character.dart';
import '../../../domain/pipeline_graph.dart';
import '../../../domain/saved_pipeline.dart';
import 'characters_cubit.dart';
import 'pipeline_cubit.dart';
import 'settings_cubit.dart';
import 'shell_cubit.dart';

/// What the canvas was asked to do.
///
/// This part of the dashboard is a Bloc rather than a Cubit because the
/// canvas is worked by a sequence of gestures, not by calls: a grab, a
/// hundred moves and a drop are one action, and an event each is what lets
/// them be replayed, undone and tested as a script.
sealed class PipelineGraphEvent {
  const PipelineGraphEvent();
}

/// The screen was opened: read the arrangement and draw what the settings
/// and the cast describe.
final class PipelineGraphOpened extends PipelineGraphEvent {
  const PipelineGraphOpened();
}

/// The settings or the cast changed under the canvas, from here or from
/// another screen.
final class PipelineGraphRefreshed extends PipelineGraphEvent {
  const PipelineGraphRefreshed();
}

/// A node was taken hold of; where it was is remembered so the drag can be
/// undone as one move rather than a hundred.
final class PipelineNodeGrabbed extends PipelineGraphEvent {
  const PipelineNodeGrabbed(this.nodeId);

  final String nodeId;
}

/// A node was dragged by [dx], [dy] on the canvas, zoom already taken out.
final class PipelineNodeMoved extends PipelineGraphEvent {
  const PipelineNodeMoved(this.nodeId, this.dx, this.dy);

  final String nodeId;
  final double dx;
  final double dy;
}

/// A gesture ended — a node let go, the canvas let go of — and the
/// arrangement is written to disk.
final class PipelineArrangementSettled extends PipelineGraphEvent {
  const PipelineArrangementSettled();
}

final class PipelineNodeSelected extends PipelineGraphEvent {
  const PipelineNodeSelected(this.nodeId, {this.add = false});

  /// Null closes the inspector and clears the choice.
  final String? nodeId;

  /// Set by a click with shift held: the node joins what is already chosen,
  /// or leaves it if it was there. Without it the choice collapses to this
  /// one node, which is what a plain click has always done.
  final bool add;
}

/// Everything the band covered, as the canvas worked it out. The canvas owns
/// the geometry — where a card sits and how big it is — so it says which
/// nodes were caught and the bloc keeps the choice.
final class PipelineSelectionSet extends PipelineGraphEvent {
  const PipelineSelectionSet(this.nodeIds);

  final Set<String> nodeIds;
}

/// A link is being pulled out of [port].
final class PipelineLinkStarted extends PipelineGraphEvent {
  const PipelineLinkStarted(this.port, this.at);

  final PipelinePort port;
  final GraphPoint at;
}

final class PipelineLinkDragged extends PipelineGraphEvent {
  const PipelineLinkDragged(this.at);

  final GraphPoint at;
}

/// The link was let go, over [target] or over nothing.
final class PipelineLinkReleased extends PipelineGraphEvent {
  const PipelineLinkReleased(this.target);

  final PipelinePort? target;
}

/// A substitution was cut, so the character is read by the pipeline again.
final class PipelineLinkCut extends PipelineGraphEvent {
  const PipelineLinkCut(this.link);

  final PipelineLink link;
}

/// A card was drawn on the canvas. A card already there is drawn again
/// rather than refused: a copy beside the character whose part it takes
/// over keeps the line between them short.
final class PipelineCharacterPlaced extends PipelineGraphEvent {
  const PipelineCharacterPlaced(this.characterId);

  final String characterId;
}

/// One drawing of a card was taken off the canvas. The card keeps whatever
/// voice reads it, and its other drawings stay: only this node goes.
final class PipelineCharacterRemoved extends PipelineGraphEvent {
  const PipelineCharacterRemoved(this.nodeId);

  final String nodeId;
}

final class PipelineViewPanned extends PipelineGraphEvent {
  const PipelineViewPanned(this.dx, this.dy);

  final double dx;
  final double dy;
}

final class PipelineViewZoomed extends PipelineGraphEvent {
  const PipelineViewZoomed(this.zoom, this.focus);

  final double zoom;

  /// Where the pointer is on the screen, so what is under it stays there.
  final GraphPoint focus;
}

/// The canvas put where it should be seen from: what the canvas works out
/// for itself when the scheme has never been fitted into the window.
final class PipelineViewSet extends PipelineGraphEvent {
  const PipelineViewSet(this.view);

  final GraphView view;
}

/// Everything back where it started: the standard arrangement, seen whole.
final class PipelineLayoutReset extends PipelineGraphEvent {
  const PipelineLayoutReset();
}

/// The scheme as it stands is kept on the shelf under [name].
final class PipelineSchemeSaved extends PipelineGraphEvent {
  const PipelineSchemeSaved(this.name);

  final String name;
}

/// A kept scheme is drawn again and becomes the one that runs.
final class PipelineSchemeChosen extends PipelineGraphEvent {
  const PipelineSchemeChosen(this.id);

  final String id;
}

final class PipelineSchemeRenamed extends PipelineGraphEvent {
  const PipelineSchemeRenamed(this.id, this.name);

  final String id;
  final String name;
}

final class PipelineSchemeRemoved extends PipelineGraphEvent {
  const PipelineSchemeRemoved(this.id);

  final String id;
}

/// One scheme written to a file of the player's choosing.
final class PipelineSchemeExported extends PipelineGraphEvent {
  const PipelineSchemeExported(this.id, this.destination);

  final String id;
  final String destination;
}

/// Schemes read from files, added to the shelf by id.
final class PipelineSchemeImported extends PipelineGraphEvent {
  const PipelineSchemeImported(this.sources);

  final List<String> sources;
}

final class PipelineGraphUndone extends PipelineGraphEvent {
  const PipelineGraphUndone();
}

final class PipelineGraphRedone extends PipelineGraphEvent {
  const PipelineGraphRedone();
}

/// A state staged by a widget test, so a screen can be drawn without a disk
/// or a session behind it.
@visibleForTesting
final class PipelineGraphSeeded extends PipelineGraphEvent {
  const PipelineGraphSeeded(this.state);

  final PipelineGraphState state;
}

/// A link being pulled, from the socket it left to wherever the pointer is.
class PipelineLinkDrag {
  const PipelineLinkDrag({required this.from, required this.at});

  final PipelinePort from;
  final GraphPoint at;
}

class PipelineGraphState {
  const PipelineGraphState({
    this.loading = true,
    this.graph = const PipelineGraph(),
    this.layout = PipelineLayout.standard,
    this.selected,
    this.chosen = const {},
    this.schemes = const [],
    this.drag,
    this.refusal,
    this.canUndo = false,
    this.canRedo = false,
  });

  final bool loading;
  final PipelineGraph graph;
  final PipelineLayout layout;

  /// The node the inspector is showing, if any. Null while several are
  /// chosen: one node's settings over a choice of five would be a trap.
  final String? selected;

  /// Every node chosen, which is what a drag moves and what the canvas
  /// draws with an edge. One node clicked is a choice of one.
  final Set<String> chosen;

  /// The schemes kept on the shelf, newest last, each drawn as a card with
  /// a picture of itself.
  final List<SavedPipeline> schemes;

  /// The link the pointer is carrying, while it carries one.
  final PipelineLinkDrag? drag;

  /// Why the last attempt at a link came to nothing. Cleared as soon as the
  /// next one starts, so the hint belongs to what just happened.
  final ConnectionRefusal? refusal;

  final bool canUndo;
  final bool canRedo;

  PipelineNode? get selectedNode => selected == null ? null : graph.node(selected!);

  PipelineGraphState copyWith({
    bool? loading,
    PipelineGraph? graph,
    PipelineLayout? layout,
    String? selected,
    bool clearSelected = false,
    Set<String>? chosen,
    List<SavedPipeline>? schemes,
    PipelineLinkDrag? drag,
    bool clearDrag = false,
    ConnectionRefusal? refusal,
    bool clearRefusal = false,
    bool? canUndo,
    bool? canRedo,
  }) => PipelineGraphState(
    loading: loading ?? this.loading,
    graph: graph ?? this.graph,
    layout: layout ?? this.layout,
    selected: clearSelected ? null : selected ?? this.selected,
    chosen: chosen ?? this.chosen,
    schemes: schemes ?? this.schemes,
    drag: clearDrag ? null : drag ?? this.drag,
    refusal: clearRefusal ? null : refusal ?? this.refusal,
    canUndo: canUndo ?? this.canUndo,
    canRedo: canRedo ?? this.canRedo,
  );
}

/// What one step back restores: where the nodes were, whether the way in
/// was drawn, and whose voice read whom.
///
/// The canvas owns none of those — they are the settings and the cast — so
/// undo puts them back through the same calls an edit makes, and the screen
/// that shows them is right without being told.
class _GraphMemento {
  const _GraphMemento({
    required this.layout,
    required this.routed,
    required this.readers,
  });

  final PipelineLayout layout;

  /// Whether the way into the pipeline was drawn, so a step back over a cut
  /// route puts the link there again.
  final bool routed;

  final Map<String, String?> readers;
}

class PipelineGraphBloc extends Bloc<PipelineGraphEvent, PipelineGraphState> {
  PipelineGraphBloc(
    this._appRepository,
    this._settings,
    this._characters,
    this._pipeline,
    this._errors,
  ) : super(const PipelineGraphState()) {
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
    on<PipelineCharacterRemoved>(_onCharacterRemoved);
    on<PipelineViewPanned>(
      (event, emit) => emit(_withView(state.layout.view.panned(event.dx, event.dy))),
    );
    on<PipelineViewZoomed>(
      (event, emit) => emit(_withView(state.layout.view.zoomedAt(event.zoom, event.focus))),
    );
    on<PipelineViewSet>((event, emit) => emit(_withView(event.view)));
    on<PipelineLayoutReset>(_onReset);
    on<PipelineGraphSeeded>((event, emit) => emit(_redrawn(event.state)));
    on<PipelineSchemeSaved>(_onSchemeSaved);
    on<PipelineSchemeChosen>(_onSchemeChosen);
    on<PipelineSchemeRenamed>(_onSchemeRenamed);
    on<PipelineSchemeRemoved>(_onSchemeRemoved);
    on<PipelineSchemeExported>(_onSchemeExported);
    on<PipelineSchemeImported>(_onSchemeImported);
    on<PipelineGraphUndone>(_onUndone);
    on<PipelineGraphRedone>(_onRedone);

    // The canvas is a second window onto the settings and the cast: a
    // language picked here or on another screen is the same change, so it
    // is redrawn from them rather than kept twice.
    _settingsChanges = _settings.stream.listen((_) => add(const PipelineGraphRefreshed()));
    _characterChanges = _characters.stream.listen((_) => add(const PipelineGraphRefreshed()));
  }

  final AppRepository _appRepository;
  final SettingsCubit _settings;
  final CharactersCubit _characters;
  final PipelineCubit _pipeline;
  final FailureSink _errors;

  late final StreamSubscription<SettingsState> _settingsChanges;
  late final StreamSubscription<CharactersState> _characterChanges;

  /// How far back the canvas remembers. Long enough to undo an evening's
  /// rewiring, short enough that the list is never a concern.
  static const historyDepth = 40;

  final List<_GraphMemento> _past = [];
  final List<_GraphMemento> _future = [];

  List<Character> get _cast => _characters.state.characters;

  /// Whether the route may be changed at all. A running session holds the
  /// models it started with, so the way in is settled until it stops; whose
  /// voice reads whom is not, and the worker is told of it as it runs.
  bool get routeLocked => _pipeline.state.running;

  Future<void> _onOpened(PipelineGraphOpened event, Emitter<PipelineGraphState> emit) async {
    if (!state.loading) return;
    // What the canvas stood on when the disk was asked. A bloc serves each
    // kind of event on a stream of its own, so a card placed while this was
    // waiting has already landed — and the arrangement read here must not
    // undo it.
    final before = state.layout;
    var layout = PipelineLayout.standard;
    var schemes = const <SavedPipeline>[];
    try {
      layout = await _appRepository.loadGraphLayout();
    } catch (exception) {
      debugPrint('pipeline layout not read: $exception');
    }
    try {
      schemes = (await _appRepository.loadPipelines()).pipelines;
    } catch (exception) {
      debugPrint('saved schemes not read: $exception');
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

  /// The scheme as it stands: the route, the arrangement, and whose voice
  /// reads whom among the cards drawn on it. The models and the languages
  /// are left out — they belong to the machine, not to the drawing.
  SavedPipeline _asScheme(String id, String name) {
    final drawn = {for (final placement in state.layout.cast) placement.characterId};
    return SavedPipeline(
      id: id,
      name: name,
      captureRouted: _settings.settings.captureRouted,
      layout: state.layout,
      readers: {
        for (final character in _cast)
          if (drawn.contains(character.id)) character.id: character.voicedBy,
      },
    );
  }

  Future<void> _onSchemeSaved(
    PipelineSchemeSaved event,
    Emitter<PipelineGraphState> emit,
  ) async {
    final name = event.name.trim();
    if (name.isEmpty) return;
    final scheme = _asScheme(DateTime.now().microsecondsSinceEpoch.toRadixString(36), name);
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
    if (routeLocked && scheme.captureRouted != _settings.settings.captureRouted) {
      emit(state.copyWith(refusal: ConnectionRefusal.locked));
      return;
    }
    final wasSilent = state.layout.silent;
    _remember();
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
    await _settings.update(_settings.settings.copyWith(captureRouted: scheme.captureRouted));
    // Which cards the scheme cuts out of the mix travels with its
    // arrangement, so a session already running is told the moment it is put
    // up rather than at the next start.
    if (!_sameCards(wasSilent, scheme.layout.silent)) {
      await _characters.readAsHeard(scheme.layout.silent);
    }
    // The scheme is the whole picture of who reads whom, so it is put back
    // over the whole cast rather than over the cards it happens to name: a
    // card this scheme does not draw is read by nobody. Kept the other way,
    // an empty scheme changed nothing at all and the arrangement it replaced
    // went on sounding under a canvas that said nothing about it.
    for (final character in _cast) {
      final reader = scheme.readers[character.id];
      if (character.voicedBy == reader) continue;
      await _characters.voiceAs(character.id, reader);
    }
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
      await _appRepository.exportPipelines(event.destination, [scheme]);
    } catch (exception) {
      _errors.report(exception);
    }
  }

  /// Schemes read from files. One that carries an id already on the shelf
  /// lands on the scheme it came from, the way an imported card does.
  Future<void> _onSchemeImported(
    PipelineSchemeImported event,
    Emitter<PipelineGraphState> emit,
  ) async {
    List<SavedPipeline> incoming;
    try {
      incoming = await _appRepository.importPipelines(event.sources);
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
      await _appRepository.savePipelines(PipelineLibrary(pipelines: schemes));
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
        if (routeLocked) {
          emit(state.copyWith(refusal: ConnectionRefusal.locked));
          return;
        }
        _remember();
        emit(state.copyWith(clearRefusal: true));
        await _settings.update(_settings.settings.copyWith(captureRouted: routed));
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
        await _characters.voiceAs(characterId, readerId);
      // A note on the card, kept with the arrangement: nothing of the
      // pipeline changes with it, so nothing is written through.
      case HeardConnection(:final nodeId, :final heard):
        _remember();
        await _relayout(_joined(state.layout, joining).withHeard(nodeId, heard), emit);
    }
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

  Future<void> _onCharacterRemoved(
    PipelineCharacterRemoved event,
    Emitter<PipelineGraphState> emit,
  ) async {
    _remember();
    emit(
      _redrawn(
        state.copyWith(
          layout: state.layout.withoutNode(event.nodeId),
          clearSelected: state.selected == event.nodeId,
        ),
      ),
    );
    _persist();
  }

  Future<void> _onReset(PipelineLayoutReset event, Emitter<PipelineGraphState> emit) async {
    _remember();
    emit(
      _redrawn(
        state.copyWith(
          layout: PipelineLayout(cast: state.layout.cast),
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

  /// Puts a remembered state back the way an edit makes one: the settings
  /// and the cast are written through, and the canvas follows them.
  Future<void> _restore(_GraphMemento memento, Emitter<PipelineGraphState> emit) async {
    final wasSilent = state.layout.silent;
    emit(_redrawn(state.copyWith(layout: memento.layout, clearRefusal: true)));
    _persist();
    if (!_sameCards(wasSilent, memento.layout.silent)) {
      await _characters.readAsHeard(memento.layout.silent);
    }
    if (!routeLocked && _settings.settings.captureRouted != memento.routed) {
      await _settings.update(_settings.settings.copyWith(captureRouted: memento.routed));
    }
    for (final entry in memento.readers.entries) {
      final now = _cast.firstWhere(
        (character) => character.id == entry.key,
        orElse: () => const Character(id: '', name: '', vector: []),
      );
      if (now.id.isEmpty || now.voicedBy == entry.value) continue;
      await _characters.voiceAs(entry.key, entry.value);
    }
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
    await _characters.readAsHeard(layout.silent);
  }

  /// Draws the canvas on [layout] and keeps it, telling a running session
  /// when the cards it hears have changed.
  Future<void> _relayout(PipelineLayout layout, Emitter<PipelineGraphState> emit) async {
    final was = state.layout.silent;
    emit(_redrawn(state.copyWith(layout: layout, clearRefusal: true)));
    _persist();
    if (!_sameCards(was, layout.silent)) await _characters.readAsHeard(layout.silent);
  }

  /// Whether two sets name the same cards. The worker is told only when
  /// they differ: a scheme put up over the same cut changes nothing.
  static bool _sameCards(Set<String> first, Set<String> second) =>
      first.length == second.length && first.every(second.contains);

  _GraphMemento _snapshot() => _GraphMemento(
    layout: state.layout,
    routed: _settings.settings.captureRouted,
    readers: {for (final character in _cast) character.id: character.voicedBy},
  );

  /// Keeps where things stood before an edit. Called by the edit rather than
  /// by every emit, so a drag of a node is one step back, not a hundred.
  void _remember() {
    _past.add(_snapshot());
    if (_past.length > historyDepth) _past.removeAt(0);
    _future.clear();
  }

  /// The state with the graph rebuilt from the settings, the cast and the
  /// arrangement it now carries.
  PipelineGraphState _redrawn(PipelineGraphState value) {
    final graph = buildPipelineGraph(
      settings: _settings.settings,
      characters: _cast,
      layout: value.layout,
    );
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
      await _appRepository.saveGraphLayout(state.layout);
    } catch (exception) {
      _errors.report(exception);
    }
  }

  /// Stages a state a widget test wants to render without touching disk.
  /// It goes through the event queue like everything else, so the screen has
  /// it after the next pump rather than at once.
  @visibleForTesting
  void seed(PipelineGraphState value) => add(PipelineGraphSeeded(value));

  @override
  Future<void> close() async {
    await _settingsChanges.cancel();
    await _characterChanges.cancel();
    return super.close();
  }
}

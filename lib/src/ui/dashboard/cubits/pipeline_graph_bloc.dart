// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/app_repository.dart';
import '../../../domain/app_settings.dart';
import '../../../domain/character.dart';
import '../../../domain/pipeline_graph.dart';
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
  const PipelineNodeSelected(this.nodeId);

  /// Null closes the inspector.
  final String? nodeId;
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

final class PipelineCharacterPlaced extends PipelineGraphEvent {
  const PipelineCharacterPlaced(this.characterId);

  final String characterId;
}

/// A card was taken off the canvas. It keeps whatever voice reads it; only
/// the node goes.
final class PipelineCharacterRemoved extends PipelineGraphEvent {
  const PipelineCharacterRemoved(this.characterId);

  final String characterId;
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

final class PipelinePresetChosen extends PipelineGraphEvent {
  const PipelinePresetChosen(this.preset);

  final PipelinePreset preset;
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
    this.drag,
    this.refusal,
    this.canUndo = false,
    this.canRedo = false,
  });

  final bool loading;
  final PipelineGraph graph;
  final PipelineLayout layout;

  /// The node the inspector is showing, if any.
  final String? selected;

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
    drag: clearDrag ? null : drag ?? this.drag,
    refusal: clearRefusal ? null : refusal ?? this.refusal,
    canUndo: canUndo ?? this.canUndo,
    canRedo: canRedo ?? this.canRedo,
  );
}

/// What one step back restores: where the nodes were, which route was
/// running, and whose voice read whom.
///
/// The canvas owns none of those — they are the settings and the cast — so
/// undo puts them back through the same calls an edit makes, and the screen
/// that shows them is right without being told.
class _GraphMemento {
  const _GraphMemento({
    required this.layout,
    required this.captureMode,
    required this.readers,
  });

  final PipelineLayout layout;
  final CaptureMode captureMode;
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
    on<PipelineNodeSelected>(
      (event, emit) => emit(
        event.nodeId == null
            ? state.copyWith(clearSelected: true)
            : state.copyWith(selected: event.nodeId),
      ),
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
    on<PipelinePresetChosen>(_onPreset);
    on<PipelineGraphSeeded>((event, emit) => emit(_redrawn(event.state)));
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
    var layout = PipelineLayout.standard;
    try {
      layout = await _appRepository.loadGraphLayout();
    } catch (exception) {
      debugPrint('pipeline layout not read: $exception');
    }
    if (isClosed) return;
    emit(_redrawn(state.copyWith(loading: false, layout: layout)));
  }

  void _onGrabbed(PipelineNodeGrabbed event, Emitter<PipelineGraphState> emit) {
    _remember();
    emit(state.copyWith(selected: event.nodeId, clearRefusal: true));
  }

  void _onMoved(PipelineNodeMoved event, Emitter<PipelineGraphState> emit) {
    final node = state.graph.node(event.nodeId);
    if (node == null) return;
    emit(
      _redrawn(
        state.copyWith(
          layout: state.layout.withPosition(
            event.nodeId,
            node.position.translate(event.dx, event.dy),
          ),
        ),
      ),
    );
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
    );
  }

  Future<void> _onCut(PipelineLinkCut event, Emitter<PipelineGraphState> emit) =>
      _apply(proposeDisconnect(event.link), emit);

  /// Carries out what the canvas proposed, or says why it could not.
  Future<void> _apply(GraphConnection connection, Emitter<PipelineGraphState> emit) async {
    switch (connection) {
      case UnchangedConnection():
        return;
      case RefusedConnection(:final reason):
        emit(state.copyWith(refusal: reason));
      case RouteConnection(:final mode):
        if (routeLocked) {
          emit(state.copyWith(refusal: ConnectionRefusal.locked));
          return;
        }
        _remember();
        emit(state.copyWith(clearRefusal: true));
        await _settings.update(_settings.settings.copyWith(captureMode: mode));
      case ReaderConnection(:final characterId, :final readerId):
        _remember();
        emit(state.copyWith(clearRefusal: true));
        await _characters.voiceAs(characterId, readerId);
    }
  }

  Future<void> _onCharacterPlaced(
    PipelineCharacterPlaced event,
    Emitter<PipelineGraphState> emit,
  ) async {
    if (state.layout.characters.contains(event.characterId)) return;
    _remember();
    emit(
      _redrawn(
        state.copyWith(
          layout: state.layout.withCharacter(event.characterId),
          selected: PipelineNodeIds.character(event.characterId),
        ),
      ),
    );
    _persist();
  }

  Future<void> _onCharacterRemoved(
    PipelineCharacterRemoved event,
    Emitter<PipelineGraphState> emit,
  ) async {
    _remember();
    final node = PipelineNodeIds.character(event.characterId);
    emit(
      _redrawn(
        state.copyWith(
          layout: state.layout.withoutCharacter(event.characterId),
          clearSelected: state.selected == node,
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
          layout: PipelineLayout(characters: state.layout.characters),
          clearRefusal: true,
        ),
      ),
    );
    _persist();
  }

  Future<void> _onPreset(PipelinePresetChosen event, Emitter<PipelineGraphState> emit) async {
    if (routeLocked) {
      emit(state.copyWith(refusal: ConnectionRefusal.locked));
      return;
    }
    _remember();
    emit(
      _redrawn(
        state.copyWith(
          layout: PipelineLayout(characters: state.layout.characters),
          clearRefusal: true,
        ),
      ),
    );
    _persist();
    await _settings.update(_settings.settings.copyWith(captureMode: event.preset.captureMode));
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
    emit(_redrawn(state.copyWith(layout: memento.layout, clearRefusal: true)));
    _persist();
    if (!routeLocked && _settings.settings.captureMode != memento.captureMode) {
      await _settings.update(_settings.settings.copyWith(captureMode: memento.captureMode));
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

  _GraphMemento _snapshot() => _GraphMemento(
    layout: state.layout,
    captureMode: _settings.settings.captureMode,
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
  PipelineGraphState _redrawn(PipelineGraphState value) => value.copyWith(
    graph: buildPipelineGraph(
      settings: _settings.settings,
      characters: _cast,
      layout: value.layout,
    ),
    canUndo: _past.isNotEmpty,
    canRedo: _future.isNotEmpty,
  );

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

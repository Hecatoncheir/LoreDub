// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import '../../domain/capture_sources.dart';
import '../../domain/game_process.dart';
import 'app_repository.dart';

/// The game the player named, what else is running, and where the monitors
/// stand -- and who to tell when any of it changes.
///
/// The game was a field of `SessionBloc`, and three other screens reached
/// into that cubit to read it and to change it: the characters' recording
/// listens to the same game, the node panel names it on the source node,
/// and the Screen page reads its window. A choice several screens share is
/// a repository's, by the same rule as the settings and the cast.
///
/// It publishes synchronously and does not replay, as the others do, for
/// the reasons `SettingsRepository` gives.
class SourcesRepository {
  SourcesRepository(this._app);

  final AppRepository _app;
  final _changes = StreamController<CaptureSources>.broadcast(sync: true);
  CaptureSources _sources = const CaptureSources();

  CaptureSources get sources => _sources;
  Stream<CaptureSources> get changes => _changes.stream;

  /// Lists the processes and the monitors again, keeping the game named if
  /// it still runs. What the player does after starting a game -- or
  /// plugging a monitor in -- with the application already open.
  Future<void> load() async {
    final processes = await _app.listProcesses();
    final monitors = await _app.monitorLayout();
    // Read after the waits: the player may have named a game meanwhile.
    _publish(_sources.relisted(processes, monitors));
  }

  void select(GameProcess? process) =>
      _publish(_sources.copyWith(selected: process, clearSelected: process == null));

  /// Publishes [value] as though it had been listed, for a test arranging
  /// what a screen is drawn from.
  void seed(CaptureSources value) => _publish(value);

  void _publish(CaptureSources value) {
    if (value == _sources) return;
    _sources = value;
    if (!_changes.isClosed) _changes.add(value);
  }

  Future<void> dispose() => _changes.close();
}

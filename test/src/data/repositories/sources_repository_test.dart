// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/repositories/app_repository.dart';
import 'package:lore_dub/src/data/repositories/settings_repository.dart';
import 'package:lore_dub/src/data/repositories/sources_repository.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/domain/game_process.dart';
import 'package:lore_dub/src/domain/monitor_layout.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/shell_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/sources_bloc.dart';

void main() {
  const game = GameProcess(pid: 42, name: 'game.exe', path: 'C:/game.exe');
  const other = GameProcess(pid: 7, name: 'other.exe', path: 'C:/other.exe');

  late _Machine machine;
  late SourcesRepository sources;

  setUp(() {
    machine = _Machine();
    sources = SourcesRepository(machine);
  });

  tearDown(() => sources.dispose());

  test('lists the processes and the monitors together', () async {
    machine.processes = [game, other];

    await sources.load();

    expect(sources.sources.processes, [game, other]);
    expect(sources.sources.monitors?.monitors.single.area.width, 1920);
    expect(sources.sources.selected, isNull, reason: 'nothing is named for the player');
  });

  test('a game named is kept through a new list while it still runs', () async {
    machine.processes = [game, other];
    await sources.load();
    sources.select(game);

    machine.processes = [other, game];
    await sources.load();
    expect(sources.sources.selected, same(game));

    machine.processes = [other];
    await sources.load();
    expect(sources.sources.selected, isNull, reason: 'an ended game is nothing to listen to');
  });

  test('a listener hears a pick before the call returns', () {
    // One screen names the game and another is drawn from it: the choice
    // has to arrive in the order it was made, like every repository's.
    final heard = <GameProcess?>[];
    final listening = sources.changes.listen((value) => heard.add(value.selected));
    addTearDown(listening.cancel);

    sources
      ..select(game)
      ..select(game)
      ..select(null);

    expect(heard, [game, null], reason: 'the same pick twice is told once');
  });

  test('the bloc takes a pick through the repository and back', () async {
    final shell = _Sink();
    final bloc = SourcesBloc(sources, shell);
    addTearDown(bloc.close);

    bloc.add(const SourcePicked(game));
    await pumpEventQueue();

    expect(sources.sources.selected, same(game), reason: 'written where every screen reads it');
    expect(bloc.state.selected, same(game), reason: 'and heard back from there');

    // Named on another screen, straight through the repository.
    sources.select(other);
    await pumpEventQueue();
    expect(bloc.state.selected, same(other));
  });

  test('a list that could not be read is reported rather than thrown', () async {
    final shell = _Sink();
    final bloc = SourcesBloc(sources, shell);
    addTearDown(bloc.close);
    machine.fails = true;

    bloc.add(const SourcesRefreshed());
    await pumpEventQueue();

    expect(shell.reported, isA<StateError>());
  });
}

/// The processes and monitors of a machine, without the native library.
class _Machine extends AppRepository {
  _Machine() : super(NativeEngineService(), SettingsRepository(SettingsService()));

  List<GameProcess> processes = const [];
  bool fails = false;

  @override
  Future<List<GameProcess>> listProcesses() async {
    if (fails) throw StateError('no list');
    return processes;
  }

  @override
  Future<MonitorLayout> monitorLayout() async =>
      const MonitorLayout([Monitor(math.Rectangle(0, 0, 1920, 1080), primary: true)]);
}

class _Sink implements FailureSink {
  Object? reported;

  @override
  void report(Object? failure) => reported = failure;
}

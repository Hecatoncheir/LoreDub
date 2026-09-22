// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/repositories/sources_repository.dart';
import 'package:lore_dub/src/domain/game_process.dart';
import 'package:lore_dub/src/ui/shell/bloc/failure_cubit.dart';
import 'package:lore_dub/src/ui/common/bloc/sources_bloc.dart';

import '../../../support/fakes/fake_system_repository.dart';

void main() {
  const game = GameProcess(pid: 42, name: 'game.exe', path: 'C:/game.exe');
  const other = GameProcess(pid: 7, name: 'other.exe', path: 'C:/other.exe');

  late FakeSystemRepository machine;
  late SourcesRepository sources;

  setUp(() {
    machine = FakeSystemRepository();
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
    machine.listingFails = true;

    bloc.add(const SourcesRefreshed());
    await pumpEventQueue();

    expect(shell.reported, isA<StateError>());
  });
}

class _Sink implements FailureSink {
  Object? reported;

  @override
  void report(Object? failure) => reported = failure;
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/game_process.dart';

void main() {
  GameProcess process(String name, {DateTime? startedAt}) =>
      GameProcess(pid: name.hashCode, name: name, path: 'C:\\$name', startedAt: startedAt);

  test('reads the start time the listing carries', () {
    final parsed = GameProcess.fromJson({
      'pid': 42,
      'name': 'game.exe',
      'path': 'C:\\game.exe',
      'startedAt': DateTime(2026, 9, 12, 10, 30).millisecondsSinceEpoch,
    });

    expect(parsed.startedAt, DateTime(2026, 9, 12, 10, 30));
    expect(
      GameProcess.fromJson({'pid': 42, 'name': 'game.exe', 'path': 'C:\\game.exe'}).startedAt,
      isNull,
      reason: 'an older listing carries no time',
    );
  });

  test('puts the most recently started process first', () {
    final processes = [
      process('alpha.exe', startedAt: DateTime(2026, 9, 12, 9)),
      process('game.exe', startedAt: DateTime(2026, 9, 12, 12)),
      process('beta.exe', startedAt: DateTime(2026, 9, 12, 11)),
    ]..sort(compareGameProcesses);

    expect([for (final one in processes) one.name], ['game.exe', 'beta.exe', 'alpha.exe']);
  });

  test('leaves processes without a start time last, in name order', () {
    final processes = [
      process('Zeta.exe'),
      process('alpha.exe'),
      process('game.exe', startedAt: DateTime(2026, 9, 12, 12)),
    ]..sort(compareGameProcesses);

    expect([for (final one in processes) one.name], ['game.exe', 'alpha.exe', 'Zeta.exe']);
  });

  test('orders processes started at the same moment by name', () {
    final moment = DateTime(2026, 9, 12, 12);
    final processes = [
      process('beta.exe', startedAt: moment),
      process('alpha.exe', startedAt: moment),
    ]..sort(compareGameProcesses);

    expect([for (final one in processes) one.name], ['alpha.exe', 'beta.exe']);
  });
}

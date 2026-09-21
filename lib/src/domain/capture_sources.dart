// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'game_process.dart';
import 'monitor_layout.dart';

/// What on this machine a session can take its sound and its text from:
/// the processes running, the one the player named, and where the monitors
/// stand.
///
/// The game is one choice for every screen -- Live, the Screen page, the
/// characters' recording and the node panel all ask it and all answer it
/// -- so it is kept once rather than by whichever screen asked first.
class CaptureSources {
  const CaptureSources({this.processes = const [], this.selected, this.monitors});

  /// In the order the engine listed them, which is newest first.
  final List<GameProcess> processes;

  /// The game the player named, if any.
  final GameProcess? selected;

  /// Where the monitors stand, once asked: a frame read over the whole
  /// screen is a share of all of them together, and is drawn that way.
  final MonitorLayout? monitors;

  CaptureSources copyWith({
    List<GameProcess>? processes,
    GameProcess? selected,
    bool clearSelected = false,
    MonitorLayout? monitors,
  }) => CaptureSources(
    processes: processes ?? this.processes,
    selected: clearSelected ? null : selected ?? this.selected,
    monitors: monitors ?? this.monitors,
  );

  /// A fresh list, with the game named before kept if it still runs. A
  /// process that ended is no longer anything to listen to.
  CaptureSources relisted(List<GameProcess> processes, MonitorLayout monitors) {
    final still = processes.where((process) => process.pid == selected?.pid).firstOrNull;
    return CaptureSources(processes: processes, selected: still, monitors: monitors);
  }

  @override
  bool operator ==(Object other) =>
      other is CaptureSources &&
      other.selected == selected &&
      other.monitors == monitors &&
      other.processes.length == processes.length &&
      Iterable<int>.generate(processes.length).every((i) => other.processes[i] == processes[i]);

  @override
  int get hashCode => Object.hash(selected, monitors, Object.hashAll(processes));
}

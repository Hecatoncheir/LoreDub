// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

class GameProcess {
  const GameProcess({required this.pid, required this.name, required this.path, this.startedAt});

  factory GameProcess.fromJson(Map<String, Object?> json) => GameProcess(
    pid: json['pid']! as int,
    name: json['name']! as String,
    path: json['path']! as String,
    startedAt: _time(json['startedAt']),
  );

  final int pid;
  final String name;
  final String path;

  /// When Windows started the process, or null when it would not say — a
  /// process of another user, or one that ended between the listing and the
  /// question.
  final DateTime? startedAt;

  static DateTime? _time(Object? milliseconds) => milliseconds is int && milliseconds > 0
      ? DateTime.fromMillisecondsSinceEpoch(milliseconds)
      : null;
}

/// Orders the picker: the most recently started process first.
///
/// A machine runs dozens of processes and the game is almost always the last
/// one started, so it sits at the top instead of somewhere in an alphabet of
/// background services. Processes Windows gave no start time for come last,
/// by name, and so do ties.
int compareGameProcesses(GameProcess left, GameProcess right) {
  final start = left.startedAt;
  final other = right.startedAt;
  if (start != null && other != null && start != other) return other.compareTo(start);
  if ((start == null) != (other == null)) return start == null ? 1 : -1;
  return left.name.toLowerCase().compareTo(right.name.toLowerCase());
}

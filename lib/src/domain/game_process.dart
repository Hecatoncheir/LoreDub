// Copyright (c) 2026 GameLingo contributors.
// SPDX-License-Identifier: MIT

class GameProcess {
  const GameProcess({required this.pid, required this.name, required this.path});

  factory GameProcess.fromJson(Map<String, Object?> json) => GameProcess(
    pid: json['pid']! as int,
    name: json['name']! as String,
    path: json['path']! as String,
  );

  final int pid;
  final String name;
  final String path;
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

/// How many characters may be heard at once when lines are allowed to
/// overlap. Two keeps a quick exchange from falling behind the game; a third
/// voice on top turns the dubbing into a crowd nobody can follow.
const overlappingVoices = 2;

/// Decides when each voiced line is played.
///
/// Lines of one speaker are played in order and never over each other: a
/// character does not interrupt themselves. A line of a different speaker
/// may start while another is still sounding, up to [maxVoices] at once. A
/// line whose speaker is unknown plays alone, and nothing queued after it
/// overtakes it, since it may belong to anyone.
class PlaybackScheduler {
  PlaybackScheduler({required this.play, this.maxVoices = 1});

  /// Plays one file to the end. Expected not to throw: a failure is the
  /// caller's to report, and must not stall the lines behind it.
  final Future<void> Function(String wavePath) play;

  /// One keeps the dubbing strictly sequential.
  int maxVoices;

  final _waiting = <_Line>[];
  final _playing = <_Line>[];

  int get playing => _playing.length;
  int get waiting => _waiting.length;

  void add(String wavePath, {String? speaker}) {
    _waiting.add(_Line(wavePath, speaker));
    _pump();
  }

  /// Drops the lines that have not started and returns their files, so the
  /// caller can delete them. What is already sounding plays to its end.
  List<String> clear() {
    final dropped = [for (final line in _waiting) line.wavePath];
    _waiting.clear();
    return dropped;
  }

  void _pump() {
    // Speakers with a line still waiting earlier in the queue: their later
    // lines must not jump ahead of it.
    final blocked = <String?>{};
    var barrier = false;
    for (final line in [..._waiting]) {
      if (_playing.length >= maxVoices) return;
      if (!barrier && !blocked.contains(line.speaker) && _canStart(line)) {
        _waiting.remove(line);
        _start(line);
        continue;
      }
      if (line.speaker == null) barrier = true;
      blocked.add(line.speaker);
    }
  }

  bool _canStart(_Line line) {
    if (line.speaker == null) return _playing.isEmpty;
    return _playing.every((other) => other.speaker != null && other.speaker != line.speaker);
  }

  void _start(_Line line) {
    _playing.add(line);
    unawaited(
      Future.sync(() => play(line.wavePath)).catchError((Object _) {}).whenComplete(() {
        _playing.remove(line);
        _pump();
      }),
    );
  }
}

class _Line {
  _Line(this.wavePath, this.speaker);

  final String wavePath;
  final String? speaker;
}

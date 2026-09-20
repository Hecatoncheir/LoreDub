// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// One engine holds one session, and the two screens that can start one do
/// not settle it between themselves.
///
/// The rule is asymmetric on purpose. A dubbing session takes the worker
/// over from the cast screen, whose worker has no whisper in it and
/// nothing in flight to lose. The other way round is refused rather than
/// granted: a recording, a sample or a card measured from files started
/// over a running dubbing pulled whisper out from under a capture that
/// went on cutting phrases, and every one of them failed for want of it.
///
/// Each screen registers its own half here, so neither has to know the
/// other and nothing above them has to hold the rule together.
class SessionCoordinator {
  bool Function() _dubbingRuns = _never;
  Future<void> Function() _endCastSession = _nothing;

  /// The dubbing screens say how to tell whether one of their sessions is
  /// running. The cast screen asks it before starting anything.
  set dubbing(bool Function() running) => _dubbingRuns = running;

  /// The cast screen says how its session ends, for when the worker is
  /// taken from it.
  set cast(Future<void> Function() end) => _endCastSession = end;

  /// Whether a dubbing session holds the worker.
  bool get dubbingRuns => _dubbingRuns();

  /// Ends whatever the cast screen holds, so that a dubbing session can
  /// start on a worker of its own.
  Future<void> makeRoomForDubbing() => _endCastSession();

  static bool _never() => false;

  static Future<void> _nothing() async {}
}

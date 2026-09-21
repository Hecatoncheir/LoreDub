// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'compute_device.dart';
import 'engine_activity.dart';
import 'pipeline_state.dart';

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
///
/// It is also where what the engine is doing is published ([activity]),
/// each screen reporting its own half as its state moves. That is a
/// value several screens draw, so it is told the way a repository tells
/// one: synchronously, and without replaying it to a late listener.
class SessionCoordinator {
  bool Function() _castHolds = _never;
  Future<void> Function() _endCastSession = _nothing;
  final _changes = StreamController<EngineActivity>.broadcast(sync: true);
  EngineActivity _activity = const EngineActivity();

  /// What the engine is doing now, and every change of it from now on.
  EngineActivity get activity => _activity;
  Stream<EngineActivity> get changes => _changes.stream;

  /// The dubbing screens say where their session stands. The cast screen
  /// asks it before starting anything.
  void reportPipeline({
    required PipelineStatus status,
    required PipelineSession session,
    required Map<ComputeStage, ComputeBackend> backends,
  }) => _publish(_activity.copyWith(status: status, session: session, backends: backends));

  /// The cast screen says whether its session is up.
  void reportCast({required bool running}) => _publish(_activity.copyWith(recordingVoice: running));

  /// The cast screen says how its session ends, for when the worker is
  /// taken from it, and whether it is holding one at all -- a recording,
  /// or a worker still loaded from a sample.
  set cast(Future<void> Function() end) => _endCastSession = end;
  set castHolds(bool Function() holding) => _castHolds = holding;

  /// Whether any screen is holding the engine. Asked before the
  /// application closes for an update: the game must not be left turned
  /// down, and no worker may still hold the files the setup replaces.
  bool get anyRuns => dubbingRuns || _castHolds();

  /// Whether a dubbing session holds the worker.
  bool get dubbingRuns => _activity.pipelineRuns;

  /// Ends whatever the cast screen holds, so that a dubbing session can
  /// start on a worker of its own.
  Future<void> makeRoomForDubbing() => _endCastSession();

  void _publish(EngineActivity value) {
    if (value == _activity) return;
    _activity = value;
    if (!_changes.isClosed) _changes.add(value);
  }

  Future<void> dispose() => _changes.close();

  static bool _never() => false;

  static Future<void> _nothing() async {}
}

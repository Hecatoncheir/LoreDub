// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'compute_device.dart';
import 'pipeline_state.dart';

/// What the one engine is doing, as the screens that run it say.
///
/// The node canvas draws every stage as locked or free, and on the device
/// it really runs on, so it has to know -- and it used to know by reading
/// the dubbing screen's cubit and the cast screen's, which is one screen's
/// state being part of another's workings. The screens report it to
/// `SessionCoordinator` instead, each its own half, and whoever draws it
/// listens there. The transcript does too: it is emptied when a session of
/// its kind begins, and keeps as many lines as that kind of session shows.
class EngineActivity {
  const EngineActivity({
    this.status = PipelineStatus.idle,
    this.session = PipelineSession.live,
    this.backends = const {},
    this.recordingVoice = false,
  });

  /// Where the dubbing screens' session stands.
  final PipelineStatus status;

  /// Which of their sessions [status] is about. Meaningless while idle.
  final PipelineSession session;

  /// What that session reported it settled on, stage by stage.
  final Map<ComputeStage, ComputeBackend> backends;

  /// The cast screen's session is up, recording through the game it
  /// started with.
  final bool recordingVoice;

  /// A session of the dubbing screens is starting, up or resting.
  bool get pipelineRuns =>
      status == PipelineStatus.starting ||
      status == PipelineStatus.listening ||
      status == PipelineStatus.paused;

  /// That session is resting.
  bool get paused => status == PipelineStatus.paused;

  EngineActivity copyWith({
    PipelineStatus? status,
    PipelineSession? session,
    Map<ComputeStage, ComputeBackend>? backends,
    bool? recordingVoice,
  }) => EngineActivity(
    status: status ?? this.status,
    session: session ?? this.session,
    backends: backends ?? this.backends,
    recordingVoice: recordingVoice ?? this.recordingVoice,
  );

  @override
  bool operator ==(Object other) =>
      other is EngineActivity &&
      other.status == status &&
      other.session == session &&
      other.recordingVoice == recordingVoice &&
      other.backends.length == backends.length &&
      backends.entries.every((entry) => other.backends[entry.key] == entry.value);

  @override
  int get hashCode => Object.hash(
    status,
    session,
    recordingVoice,
    Object.hashAllUnordered(backends.entries.map((entry) => Object.hash(entry.key, entry.value))),
  );
}

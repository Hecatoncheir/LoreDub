// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'compute_device.dart';

/// What the one engine is doing, as the screens that run it say.
///
/// The node canvas draws every stage as locked or free, and on the device
/// it really runs on, so it has to know -- and it used to know by reading
/// the dubbing screen's cubit and the cast screen's, which is one screen's
/// state being part of another's workings. The screens report it to
/// `SessionCoordinator` instead, each its own half, and whoever draws it
/// listens there.
class EngineActivity {
  const EngineActivity({
    this.pipelineRuns = false,
    this.paused = false,
    this.backends = const {},
    this.recordingVoice = false,
  });

  /// A session of the dubbing screens is starting, up or resting.
  final bool pipelineRuns;

  /// That session is resting.
  final bool paused;

  /// What that session reported it settled on, stage by stage.
  final Map<ComputeStage, ComputeBackend> backends;

  /// The cast screen's session is up, recording through the game it
  /// started with.
  final bool recordingVoice;

  EngineActivity copyWith({
    bool? pipelineRuns,
    bool? paused,
    Map<ComputeStage, ComputeBackend>? backends,
    bool? recordingVoice,
  }) => EngineActivity(
    pipelineRuns: pipelineRuns ?? this.pipelineRuns,
    paused: paused ?? this.paused,
    backends: backends ?? this.backends,
    recordingVoice: recordingVoice ?? this.recordingVoice,
  );

  @override
  bool operator ==(Object other) =>
      other is EngineActivity &&
      other.pipelineRuns == pipelineRuns &&
      other.paused == paused &&
      other.recordingVoice == recordingVoice &&
      other.backends.length == backends.length &&
      backends.entries.every((entry) => other.backends[entry.key] == entry.value);

  @override
  int get hashCode => Object.hash(
    pipelineRuns,
    paused,
    recordingVoice,
    Object.hashAllUnordered(backends.entries.map((entry) => Object.hash(entry.key, entry.value))),
  );
}

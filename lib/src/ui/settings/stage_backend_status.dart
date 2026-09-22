// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/compute_device.dart';
import '../../domain/runtime_package.dart';
import '../models/bloc/downloads_bloc.dart';

/// Where one stage stands on one backend: what a cell of the stage-by-device
/// table says, decided once here rather than in the cell.
sealed class StageBackendStatus {
  const StageBackendStatus();
}

/// The stage has no build for this backend at all.
final class StageBackendUnsupported extends StageBackendStatus {
  const StageBackendUnsupported();
}

/// No card or driver for this backend on this machine.
final class StageBackendNoHardware extends StageBackendStatus {
  const StageBackendNoHardware();
}

/// The card is there, the package for it is not: a press fetches [runtime].
final class StageBackendNeedsRuntime extends StageBackendStatus {
  const StageBackendNeedsRuntime(this.runtime);

  final RuntimeInstallState runtime;
}

/// The package is on its way, [progress] of it arrived.
final class StageBackendDownloading extends StageBackendStatus {
  const StageBackendDownloading(this.runtime, this.progress);

  final RuntimeInstallState runtime;
  final double progress;
}

/// A runtime that is missing and not in the catalogue either -- the Vulkan
/// build a copy was made without. The cell used to read as ready, and the
/// press it invited stored a pin the resolver then refused, so nothing moved
/// and nothing said why.
final class StageBackendNotShipped extends StageBackendStatus {
  const StageBackendNotShipped();
}

/// It could run here, at a press.
final class StageBackendReady extends StageBackendStatus {
  const StageBackendReady();
}

/// The stage runs here.
final class StageBackendSelected extends StageBackendStatus {
  const StageBackendSelected();
}

/// What [downloads] say of [stage] on [backend], where [selected] is the
/// backend the stage settled on -- while dubbing runs, the one it really did.
StageBackendStatus stageBackendStatus(
  DownloadsState downloads,
  ComputeStage stage,
  ComputeBackend backend, {
  required ComputeBackend selected,
}) {
  if (!stageBackends(stage).contains(backend)) return const StageBackendUnsupported();
  if (!downloads.availability.supportsHardware(backend)) return const StageBackendNoHardware();
  if (downloads.missingRuntimeFor(stage, backend) case final missing?) {
    return switch (missing.progress) {
      final progress? => StageBackendDownloading(missing, progress),
      null => StageBackendNeedsRuntime(missing),
    };
  }
  if (downloads.lacksBuiltInRuntime(stage, backend)) return const StageBackendNotShipped();
  return backend == selected ? const StageBackendSelected() : const StageBackendReady();
}

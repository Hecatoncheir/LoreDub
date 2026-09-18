// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/runtime_catalog.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:lore_dub/src/domain/runtime_package.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/downloads_cubit.dart';
import 'package:lore_dub/src/ui/settings/stage_backend_status.dart';

void main() {
  const nvidia = ComputeAvailability(
    adapters: [GraphicsAdapter(name: 'RTX', vendor: GraphicsVendor.nvidia)],
    cudaDriver: true,
  );
  final cudaWhisper = runtimeCatalog.firstWhere((runtime) => runtime.id == 'whisper-cuda');

  DownloadsState downloads({
    ComputeAvailability availability = nvidia,
    List<RuntimeInstallState>? runtimes,
  }) => DownloadsState(
    availability: availability,
    runtimes: runtimes ?? [RuntimeInstallState(package: cudaWhisper)],
  );

  StageBackendStatus status(
    DownloadsState state,
    ComputeBackend backend, {
    ComputeBackend selected = ComputeBackend.cpu,
  }) => stageBackendStatus(state, ComputeStage.recognition, backend, selected: selected);

  test('says where the stage runs and where it could at a press', () {
    expect(status(downloads(), ComputeBackend.cpu), isA<StageBackendSelected>());
    final installed = downloads(
      availability: const ComputeAvailability(
        adapters: [GraphicsAdapter(name: 'RTX', vendor: GraphicsVendor.nvidia)],
        cudaDriver: true,
        installedRuntimes: {'whisper-cuda'},
      ),
    );
    expect(status(installed, ComputeBackend.cuda), isA<StageBackendReady>());
  });

  test('offers the package a card is waiting for, and how far it has come', () {
    expect(
      status(downloads(), ComputeBackend.cuda),
      isA<StageBackendNeedsRuntime>().having((s) => s.runtime.package, 'package', cudaWhisper),
    );
    final arriving = downloads(
      runtimes: [RuntimeInstallState(package: cudaWhisper, progress: 0.4)],
    );
    expect(
      status(arriving, ComputeBackend.cuda),
      isA<StageBackendDownloading>().having((s) => s.progress, 'progress', 0.4),
    );
  });

  test('rules out a backend the machine has no card or driver for', () {
    expect(
      status(downloads(availability: const ComputeAvailability()), ComputeBackend.cuda),
      isA<StageBackendNoHardware>(),
    );
  });

  test('tells a runtime this copy can never fetch from one it can', () {
    expect(
      status(downloads(runtimes: const []), ComputeBackend.cuda),
      isA<StageBackendNotShipped>(),
    );
  });

  test('rules out a backend the stage has no build for', () {
    for (final stage in ComputeStage.values) {
      for (final backend in ComputeBackend.values) {
        if (stageBackends(stage).contains(backend)) continue;
        expect(
          stageBackendStatus(downloads(), stage, backend, selected: ComputeBackend.cpu),
          isA<StageBackendUnsupported>(),
          reason: '${stage.name} on ${backend.name}',
        );
      }
    }
  });
}

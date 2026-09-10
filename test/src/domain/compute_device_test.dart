// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/compute_device.dart';

void main() {
  const nvidia = GraphicsAdapter(
    name: 'NVIDIA GeForce RTX 3080 Ti',
    vendor: GraphicsVendor.nvidia,
    dedicatedMemoryBytes: 12673089536,
  );
  const radeon = GraphicsAdapter(name: 'AMD Radeon RX 7800 XT', vendor: GraphicsVendor.amd);

  ComputeAvailability nvidiaMachine({Set<String> runtimes = const {}}) => ComputeAvailability(
    adapters: const [nvidia],
    cudaDriver: true,
    vulkanLoader: true,
    installedRuntimes: runtimes,
  );

  ComputeAvailability amdMachine({Set<String> runtimes = const {}}) => ComputeAvailability(
    adapters: const [radeon],
    vulkanLoader: true,
    installedRuntimes: runtimes,
  );

  ComputeBackend resolve(
    ComputeStage stage,
    ComputeDevice device,
    ComputeAvailability availability, {
    ComputeBackend? override,
  }) => resolveComputeBackend(
    stage: stage,
    device: device,
    availability: availability,
    override: override,
  );

  test('reads the adapters the native probe reported', () {
    final availability = ComputeAvailability.fromProbeJson(const {
      'adapters': [
        {'name': 'NVIDIA GeForce RTX 3080 Ti', 'vendorId': 0x10DE, 'dedicatedMemory': 12673089536},
      ],
      'cudaDriver': true,
      'vulkanLoader': true,
    });

    expect(availability.adapters.single.vendor, GraphicsVendor.nvidia);
    expect(availability.adapters.single.name, contains('3080'));
    expect(availability.cudaDriver, isTrue);
  });

  test('survives a probe that found nothing', () {
    final availability = ComputeAvailability.fromProbeJson(const {});

    expect(availability.adapters, isEmpty);
    expect(availability.supportsHardware(ComputeBackend.cuda), isFalse);
    expect(availability.supportsHardware(ComputeBackend.cpu), isTrue);
  });

  test('stays on the CPU until the GPU runtime is downloaded', () {
    final waiting = nvidiaMachine();

    expect(waiting.supportsHardware(ComputeBackend.cuda), isTrue, reason: 'the card is there');
    expect(waiting.isReady(ComputeStage.recognition, ComputeBackend.cuda), isFalse);
    expect(
      resolve(ComputeStage.recognition, ComputeDevice.auto, waiting),
      ComputeBackend.cpu,
    );
  });

  test('moves recognition onto CUDA once its runtime is there', () {
    final ready = nvidiaMachine(runtimes: {'whisper-cuda'});

    expect(
      resolve(ComputeStage.recognition, ComputeDevice.auto, ready),
      ComputeBackend.cuda,
    );
    // Translation has its own runtime and has not got it yet.
    expect(
      resolve(ComputeStage.translation, ComputeDevice.auto, ready),
      ComputeBackend.cpu,
    );
  });

  test('prefers CUDA over Vulkan on a card that speaks both', () {
    final both = nvidiaMachine(runtimes: {'whisper-cuda', 'whisper-vulkan'});

    expect(
      resolve(ComputeStage.recognition, ComputeDevice.auto, both),
      ComputeBackend.cuda,
    );
  });

  test('gives an AMD card Vulkan and never CUDA', () {
    final amd = amdMachine(runtimes: {'whisper-vulkan', 'whisper-cuda'});

    expect(amd.supportsHardware(ComputeBackend.cuda), isFalse);
    expect(
      resolve(ComputeStage.recognition, ComputeDevice.auto, amd),
      ComputeBackend.vulkan,
    );
    // torch has no Vulkan backend, so translation stays where it is.
    expect(
      resolve(ComputeStage.translation, ComputeDevice.gpu, amd),
      ComputeBackend.cpu,
    );
  });

  test('keeps speech on the CPU whatever is asked for', () {
    final ready = nvidiaMachine(runtimes: {'whisper-cuda', 'torch-cuda'});

    expect(stageBackends(ComputeStage.speech), [ComputeBackend.cpu]);
    expect(
      resolve(ComputeStage.speech, ComputeDevice.gpu, ready, override: ComputeBackend.cuda),
      ComputeBackend.cpu,
    );
  });

  test('honours the CPU preset even with everything installed', () {
    final ready = nvidiaMachine(runtimes: {'whisper-cuda', 'torch-cuda'});

    for (final stage in ComputeStage.values) {
      expect(resolve(stage, ComputeDevice.cpu, ready), ComputeBackend.cpu, reason: stage.name);
    }
  });

  test('lets one stage be pinned against the preset', () {
    final ready = nvidiaMachine(runtimes: {'whisper-cuda'});

    expect(
      resolve(
        ComputeStage.recognition,
        ComputeDevice.cpu,
        ready,
        override: ComputeBackend.cuda,
      ),
      ComputeBackend.cuda,
    );
  });

  test('drops a pin the machine can no longer honour', () {
    // The card was removed, or the runtime deleted, since the pin was saved.
    const gone = ComputeAvailability();

    expect(
      resolve(
        ComputeStage.recognition,
        ComputeDevice.gpu,
        gone,
        override: ComputeBackend.cuda,
      ),
      ComputeBackend.cpu,
      reason: 'a stale pin must not start a run that cannot work',
    );
  });

  test('names the runtime each backend waits on', () {
    expect(requiredRuntimeId(ComputeStage.recognition, ComputeBackend.cuda), 'whisper-cuda');
    expect(requiredRuntimeId(ComputeStage.recognition, ComputeBackend.vulkan), 'whisper-vulkan');
    expect(requiredRuntimeId(ComputeStage.translation, ComputeBackend.cuda), 'torch-cuda');
    expect(requiredRuntimeId(ComputeStage.speech, ComputeBackend.cpu), isNull);
    expect(requiredRuntimeId(ComputeStage.recognition, ComputeBackend.cpu), isNull);
  });

  group('settings', () {
    test('follows the preset until a stage is pinned', () {
      const settings = AppSettings();
      final ready = nvidiaMachine(runtimes: {'whisper-cuda'});

      expect(settings.computeDevice, ComputeDevice.auto, reason: 'the default');
      expect(settings.backendFor(ComputeStage.recognition, ready), ComputeBackend.cuda);

      final pinned = settings.withBackend(ComputeStage.recognition, ComputeBackend.cpu);
      expect(pinned.backendFor(ComputeStage.recognition, ready), ComputeBackend.cpu);
    });

    test('forgets every pin when a preset is pressed again', () {
      final ready = nvidiaMachine(runtimes: {'whisper-cuda'});
      final pinned = const AppSettings()
          .withBackend(ComputeStage.recognition, ComputeBackend.cpu)
          .withBackend(ComputeStage.translation, ComputeBackend.cpu);

      final reset = pinned.withComputeDevice(ComputeDevice.auto);

      expect(reset.recognitionBackend, isNull);
      expect(reset.translationBackend, isNull);
      expect(reset.backendFor(ComputeStage.recognition, ready), ComputeBackend.cuda);
    });

    test('keeps the other pins when one stage changes', () {
      final settings = const AppSettings()
          .withBackend(ComputeStage.recognition, ComputeBackend.cuda)
          .withBackend(ComputeStage.translation, ComputeBackend.cpu);

      expect(settings.recognitionBackend, ComputeBackend.cuda);
      expect(settings.translationBackend, ComputeBackend.cpu);
      expect(settings.speechBackend, isNull);
    });
  });
}

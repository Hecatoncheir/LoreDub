// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'runtime_package.dart';

/// What the user asked the pipeline to run on.
///
/// This is a preset rather than the truth: [auto] and the two forced values
/// only decide what a stage falls back to when it carries no override of its
/// own. What each stage actually runs on is [ComputeBackend], resolved by
/// [resolveComputeBackend] against the hardware that is really present.
enum ComputeDevice { auto, gpu, cpu }

/// What a single stage actually runs on.
enum ComputeBackend { cuda, vulkan, cpu }

/// The stages that can be moved between the CPU and the GPU independently.
///
/// They differ because they are different runtimes: whisper.cpp has both a
/// CUDA and a Vulkan build, while torch on Windows has only CUDA. The
/// OpenVoice converter shares the worker's torch with translation but is
/// placed on its own: on the CPU it adds about a second to every line, on a
/// GPU next to nothing, while translation is quick on either.
///
/// Speech is the Vosk voice on onnxruntime, and the card is worth the most
/// there of the worker's three: measured on an RTX 3080 Ti, 280 to 330 ms a
/// line against 850 to 920 on twelve processor threads, near constant with
/// the line's length. It pays for it at the start -- 17 s to load against 8.
///
/// The language model is a translator of its own kind: llama.cpp rather
/// than the worker's torch, with a CUDA and a Vulkan build like whisper's,
/// so it is placed apart from Marian's translation stage. Which of the two
/// a session uses is the translator package installed.
enum ComputeStage { recognition, translation, speech, voiceConversion, languageModel }

/// The backends a stage could use on ideal hardware, best first.
///
/// Ordering is the preference [ComputeDevice.auto] follows, so CUDA is tried
/// before Vulkan: on NVIDIA it is consistently the faster of the two.
List<ComputeBackend> stageBackends(ComputeStage stage) => switch (stage) {
  ComputeStage.recognition || ComputeStage.languageModel => const [
    ComputeBackend.cuda,
    ComputeBackend.vulkan,
    ComputeBackend.cpu,
  ],
  // torch and onnxruntime ship no Vulkan backend here, and ROCm is not built
  // for Windows, so the three stages in the worker are offered CUDA or
  // nothing.
  ComputeStage.translation ||
  ComputeStage.speech ||
  ComputeStage.voiceConversion => const [ComputeBackend.cuda, ComputeBackend.cpu],
};

/// The extra runtime a stage needs before it can use a backend, if any.
///
/// These are the ids in the runtime catalogue. Nothing is returned for the
/// CPU: that runtime ships with the application.
String? requiredRuntimeId(ComputeStage stage, ComputeBackend backend) => switch ((stage, backend)) {
  (ComputeStage.recognition, ComputeBackend.cuda) => whisperCudaRuntimeId,
  (ComputeStage.recognition, ComputeBackend.vulkan) => 'whisper-vulkan',
  // The translator and the converter run in the worker's own torch, and the
  // voice in the onnxruntime-gpu installed beside it on that torch's CUDA
  // libraries, so one runtime serves the three.
  (ComputeStage.translation, ComputeBackend.cuda) ||
  (ComputeStage.speech, ComputeBackend.cuda) ||
  (ComputeStage.voiceConversion, ComputeBackend.cuda) => torchCudaRuntimeId,
  // llama.cpp's builds ship the way whisper's do: the CPU and Vulkan ones
  // with the application, the CUDA one downloaded.
  (ComputeStage.languageModel, ComputeBackend.cuda) => llamaCudaRuntimeId,
  (ComputeStage.languageModel, ComputeBackend.vulkan) => llamaVulkanRuntimeId,
  _ => null,
};

/// A graphics adapter the probe found, named as the driver reports it.
class GraphicsAdapter {
  const GraphicsAdapter({
    required this.name,
    required this.vendor,
    this.dedicatedMemoryBytes = 0,
  });

  factory GraphicsAdapter.fromJson(Map<String, Object?> json) => GraphicsAdapter(
    name: json['name'] as String? ?? '',
    vendor: graphicsVendorFromId(json['vendorId'] as int? ?? 0),
    dedicatedMemoryBytes: json['dedicatedMemory'] as int? ?? 0,
  );

  final String name;
  final GraphicsVendor vendor;
  final int dedicatedMemoryBytes;
}

enum GraphicsVendor { nvidia, amd, intel, other }

/// PCI vendor ids, as DXGI reports them.
GraphicsVendor graphicsVendorFromId(int vendorId) => switch (vendorId) {
  0x10DE => GraphicsVendor.nvidia,
  0x1002 || 0x1022 => GraphicsVendor.amd,
  0x8086 => GraphicsVendor.intel,
  _ => GraphicsVendor.other,
};

/// What this machine can offer, independent of what the user chose.
class ComputeAvailability {
  const ComputeAvailability({
    this.adapters = const [],
    this.cudaDriver = false,
    this.vulkanLoader = false,
    this.installedRuntimes = const {},
  });

  /// Reads what the native probe reported. Which runtimes are downloaded is
  /// not the native side's business, so it is filled in separately.
  factory ComputeAvailability.fromProbeJson(Map<String, Object?> json) => ComputeAvailability(
    adapters: [
      for (final adapter in json['adapters'] as List<Object?>? ?? const [])
        GraphicsAdapter.fromJson(adapter! as Map<String, Object?>),
    ],
    cudaDriver: json['cudaDriver'] as bool? ?? false,
    vulkanLoader: json['vulkanLoader'] as bool? ?? false,
  );

  /// Hardware adapters, software renderers already filtered out.
  final List<GraphicsAdapter> adapters;

  /// Whether the NVIDIA driver's CUDA library is installed.
  final bool cudaDriver;

  /// Whether the Vulkan loader is installed.
  final bool vulkanLoader;

  /// Ids of the runtime packages that are downloaded and unpacked.
  final Set<String> installedRuntimes;

  GraphicsAdapter? get cudaAdapter => _firstOf(GraphicsVendor.nvidia);

  /// The adapter Vulkan would run on. NVIDIA cards speak Vulkan too, but an
  /// AMD card is the reason the backend exists, so it is named first.
  GraphicsAdapter? get vulkanAdapter =>
      _firstOf(GraphicsVendor.amd) ?? _firstOf(GraphicsVendor.intel) ?? adapters.firstOrNull;

  GraphicsAdapter? _firstOf(GraphicsVendor vendor) =>
      adapters.where((adapter) => adapter.vendor == vendor).firstOrNull;

  /// Whether the machine could run this backend once its runtime is there.
  ///
  /// The runtime download is deliberately not part of this: a user with an
  /// NVIDIA card should see CUDA offered and be told to fetch it, not see the
  /// option greyed out with no explanation.
  bool supportsHardware(ComputeBackend backend) => switch (backend) {
    ComputeBackend.cpu => true,
    ComputeBackend.cuda => cudaDriver && cudaAdapter != null,
    ComputeBackend.vulkan => vulkanLoader && adapters.isNotEmpty,
  };

  /// Whether a stage can start on this backend right now.
  bool isReady(ComputeStage stage, ComputeBackend backend) {
    if (!stageBackends(stage).contains(backend)) return false;
    if (!supportsHardware(backend)) return false;
    final runtime = requiredRuntimeId(stage, backend);
    return runtime == null || installedRuntimes.contains(runtime);
  }

  ComputeAvailability copyWith({
    List<GraphicsAdapter>? adapters,
    bool? cudaDriver,
    bool? vulkanLoader,
    Set<String>? installedRuntimes,
  }) => ComputeAvailability(
    adapters: adapters ?? this.adapters,
    cudaDriver: cudaDriver ?? this.cudaDriver,
    vulkanLoader: vulkanLoader ?? this.vulkanLoader,
    installedRuntimes: installedRuntimes ?? this.installedRuntimes,
  );
}

/// Decides what a stage runs on, and never names something that cannot start.
///
/// [override] is what the user picked for this stage specifically; it wins
/// over [device] but is still checked against the machine, so a card that was
/// removed — or a runtime that was deleted — quietly falls back to the CPU
/// instead of failing at the moment the game is already muted.
ComputeBackend resolveComputeBackend({
  required ComputeStage stage,
  required ComputeDevice device,
  required ComputeAvailability availability,
  ComputeBackend? override,
}) {
  final candidates = stageBackends(stage);
  if (override != null && availability.isReady(stage, override)) return override;
  if (device == ComputeDevice.cpu) return ComputeBackend.cpu;
  for (final backend in candidates) {
    if (backend == ComputeBackend.cpu) continue;
    if (availability.isReady(stage, backend)) return backend;
  }
  return ComputeBackend.cpu;
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

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
/// They differ because they are three different runtimes: whisper.cpp has both
/// a CUDA and a Vulkan build, torch on Windows has only CUDA, and Silero is
/// small enough that the transfer costs more than the work.
enum ComputeStage { recognition, translation, speech }

/// The backends a stage could use on ideal hardware, best first.
///
/// Ordering is the preference [ComputeDevice.auto] follows, so CUDA is tried
/// before Vulkan: on NVIDIA it is consistently the faster of the two.
List<ComputeBackend> stageBackends(ComputeStage stage) => switch (stage) {
  ComputeStage.recognition => const [
    ComputeBackend.cuda,
    ComputeBackend.vulkan,
    ComputeBackend.cpu,
  ],
  // torch ships no Vulkan backend, and ROCm is not built for Windows.
  ComputeStage.translation => const [ComputeBackend.cuda, ComputeBackend.cpu],
  ComputeStage.speech => const [ComputeBackend.cpu],
};

/// The extra runtime a stage needs before it can use a backend, if any.
///
/// These are the ids in the runtime catalogue. Nothing is returned for the
/// CPU: that runtime ships with the application.
String? requiredRuntimeId(ComputeStage stage, ComputeBackend backend) => switch ((stage, backend)) {
  (ComputeStage.recognition, ComputeBackend.cuda) => 'whisper-cuda',
  (ComputeStage.recognition, ComputeBackend.vulkan) => 'whisper-vulkan',
  (ComputeStage.translation, ComputeBackend.cuda) => 'torch-cuda',
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

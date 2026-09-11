// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../l10n/app_localizations.dart';
import '../data/services/runtime_catalog.dart';
import '../domain/compute_device.dart';
import '../domain/model_package.dart';

/// The pipeline stages, named as the player thinks of them rather than as the
/// code does: "Whisper" is the recognizer everyone recognizes by name.
String computeStageName(AppLocalizations l10n, ComputeStage stage) => switch (stage) {
  ComputeStage.recognition => l10n.computeStageRecognition,
  ComputeStage.translation => l10n.computeStageTranslation,
  ComputeStage.speech => l10n.computeStageSpeech,
  ComputeStage.voiceConversion => l10n.computeStageVoiceConversion,
};

/// Backend names are trademarks and stay untranslated, but they still come
/// from the ARB files so a locale can letter-case them its own way.
String computeBackendName(AppLocalizations l10n, ComputeBackend backend) => switch (backend) {
  ComputeBackend.cuda => l10n.computeBackendCuda,
  ComputeBackend.vulkan => l10n.computeBackendVulkan,
  ComputeBackend.cpu => l10n.computeBackendCpu,
};

/// A GPU runtime by what it is for, as its tile is titled.
String runtimeName(AppLocalizations l10n, String id) => switch (id) {
  whisperCudaRuntimeId => l10n.runtimeWhisperCuda,
  torchCudaRuntimeId => l10n.runtimeTorchCuda,
  _ => id,
};

/// The stages a GPU runtime serves, in the line under its title.
String runtimeServes(AppLocalizations l10n, String id) => switch (id) {
  whisperCudaRuntimeId => l10n.runtimeServesWhisper,
  torchCudaRuntimeId => l10n.runtimeServesTorch,
  _ => id,
};

String computeDeviceName(AppLocalizations l10n, ComputeDevice device) => switch (device) {
  ComputeDevice.auto => l10n.computeDeviceAuto,
  ComputeDevice.gpu => l10n.computeDeviceGpu,
  ComputeDevice.cpu => l10n.computeDeviceCpu,
};

/// A voice, as "Aidar (мужской)". The identifiers come from Silero and are
/// not translated; the gender is, because it is the part being chosen.
String voiceLabel(AppLocalizations l10n, VoiceOption voice) {
  final name = voice.id.isEmpty
      ? voice.id
      : voice.id[0].toUpperCase() + voice.id.substring(1).replaceAll('_', ' ');
  return switch (voice.gender) {
    VoiceGender.male => '$name (${l10n.voiceGenderMale})',
    VoiceGender.female => '$name (${l10n.voiceGenderFemale})',
    VoiceGender.unknown => name,
  };
}

/// Rounded to whole gigabytes: the exact figure is noise next to the decision
/// the reader is making, which is whether to spend the download at all.
String formatPackageSize(int bytes) {
  const gigabyte = 1024 * 1024 * 1024;
  if (bytes >= gigabyte) return '${(bytes / gigabyte).toStringAsFixed(1)} GB';
  return '${(bytes / (1024 * 1024)).round()} MB';
}

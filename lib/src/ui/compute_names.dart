// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../l10n/app_localizations.dart';
import '../domain/compute_device.dart';

/// The pipeline stages, named as the player thinks of them rather than as the
/// code does: "Whisper" is the recognizer everyone recognizes by name.
String computeStageName(AppLocalizations l10n, ComputeStage stage) => switch (stage) {
  ComputeStage.recognition => l10n.computeStageRecognition,
  ComputeStage.translation => l10n.computeStageTranslation,
  ComputeStage.speech => l10n.computeStageSpeech,
};

/// Backend names are trademarks and stay untranslated, but they still come
/// from the ARB files so a locale can letter-case them its own way.
String computeBackendName(AppLocalizations l10n, ComputeBackend backend) => switch (backend) {
  ComputeBackend.cuda => l10n.computeBackendCuda,
  ComputeBackend.vulkan => l10n.computeBackendVulkan,
  ComputeBackend.cpu => l10n.computeBackendCpu,
};

String computeDeviceName(AppLocalizations l10n, ComputeDevice device) => switch (device) {
  ComputeDevice.auto => l10n.computeDeviceAuto,
  ComputeDevice.gpu => l10n.computeDeviceGpu,
  ComputeDevice.cpu => l10n.computeDeviceCpu,
};

/// Rounded to whole gigabytes: the exact figure is noise next to the decision
/// the reader is making, which is whether to spend the download at all.
String formatPackageSize(int bytes) {
  const gigabyte = 1024 * 1024 * 1024;
  if (bytes >= gigabyte) return '${(bytes / gigabyte).toStringAsFixed(1)} GB';
  return '${(bytes / (1024 * 1024)).round()} MB';
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../l10n/app_localizations.dart';
import '../data/services/local_inference_service.dart';
import '../data/services/python_discovery.dart';
import '../domain/failure.dart';

/// Turns what the services raised into a sentence in the interface language.
///
/// Anything that is not a [LoreDubFailure] is a bug rather than a condition
/// the app knows about, so it is shown as it came: unhelpful to translate,
/// useful to report.
String describeFailure(AppLocalizations l10n, Object error) {
  if (error is! LoreDubFailure) return '$error';
  final detail = error.detail ?? '';
  return switch (error.code) {
    FailureCode.whisperMissing => l10n.failureWhisperMissing(detail),
    FailureCode.whisperModelMissing => l10n.failureWhisperModelMissing(detail),
    FailureCode.whisperFailed => l10n.failureWhisperFailed(detail),
    FailureCode.pythonMissing => l10n.failurePythonMissing(detail),
    FailureCode.pythonStoreAlias => l10n.failurePythonStoreAlias,
    FailureCode.pythonSearchEmpty => l10n.failurePythonSearchEmpty,
    FailureCode.pythonSearchNoDependencies => l10n.failurePythonSearchNoDependencies(detail),
    FailureCode.pythonSearchFailed => l10n.failurePythonSearchFailed(detail),
    FailureCode.workerExited => _describeWorkerExit(l10n, detail),
    FailureCode.workerExitedSilently => l10n.failureWorkerExitedSilently(
      int.tryParse(detail) ?? 0,
    ),
    FailureCode.workerTimeout =>
      detail.isEmpty ? l10n.failureWorkerTimeoutSilent : l10n.failureWorkerTimeout(detail),
    FailureCode.workerNotRunning => l10n.failureWorkerNotRunning,
    FailureCode.workerFailed => l10n.failureWorkerFailed(detail),
    FailureCode.pipelineStopped => l10n.failurePipelineStopped,
    FailureCode.captureFailed => l10n.failureCaptureFailed(detail),
    FailureCode.windowsOnly => l10n.failureWindowsOnly,
    FailureCode.explorerUnsupported => l10n.failureExplorerUnsupported,
    FailureCode.downloadRejected => l10n.failureDownloadRejected(detail),
    FailureCode.verificationFailed => l10n.failureVerificationFailed(detail),
    FailureCode.socksLookupFailed => l10n.failureSocksLookupFailed,
    FailureCode.updateCheckFailed => l10n.failureUpdateCheckFailed(detail),
    FailureCode.runtimeIncomplete => l10n.failureRuntimeIncomplete(detail),
    FailureCode.runtimeInstallFailed => l10n.failureRuntimeInstallFailed(detail),
    FailureCode.proxyFormat => l10n.failureProxyFormat,
    FailureCode.proxyPort => l10n.failureProxyPort,
    FailureCode.initializationFailed => l10n.failureInitializationFailed(detail),
  };
}

String _describeWorkerExit(AppLocalizations l10n, String detail) {
  final parts = detail.split(exitDetailSeparator);
  final code = int.tryParse(parts.first) ?? 0;
  return parts.length < 2
      ? l10n.failureWorkerExitedSilently(code)
      : l10n.failureWorkerExited(code, parts[1]);
}

/// The interpreters a search turned down, written out for the reader.
String describeRejectedPython(AppLocalizations l10n, List<RejectedPython> rejected) => rejected
    .map(
      (candidate) => candidate.version == null
          ? l10n.pythonCandidateUnusable(candidate.path)
          : l10n.pythonCandidateWithoutDependencies(candidate.path, candidate.version!),
    )
    .join('; ');

/// Startup stages arrive as codes from the worker and from the engine.
String describeStartupStage(AppLocalizations l10n, String stage) => switch (stage) {
  'python' => l10n.stagePython,
  'torch' => l10n.stageTorch,
  'transformers' => l10n.stageTransformers,
  'translator' => l10n.stageTranslator,
  'speech' => l10n.stageSpeech,
  'capture' => l10n.stageCapture,
  _ => stage,
};

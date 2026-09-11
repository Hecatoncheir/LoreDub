// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// What went wrong, without saying it in any particular language.
///
/// Services run where there is no locale, so they raise a code and whatever
/// technical detail belongs with it — a path, an exit code, the output of a
/// process. The interface turns that into a sentence the reader understands.
enum FailureCode {
  /// whisper-cli.exe is not next to the application.
  whisperMissing,

  /// The Whisper weights have not been downloaded.
  whisperModelMissing,

  /// whisper.cpp ran and failed.
  whisperFailed,

  /// No interpreter at the configured path or in PATH.
  pythonMissing,

  /// Only the Microsoft Store execution alias was found.
  pythonStoreAlias,

  /// Nothing was found to inspect at all.
  pythonSearchEmpty,

  /// Interpreters were found, none with torch and transformers.
  pythonSearchNoDependencies,

  /// The search itself blew up.
  pythonSearchFailed,

  /// The worker exited; the detail carries its output.
  workerExited,

  /// The worker exited without saying anything.
  workerExitedSilently,

  /// The worker did not answer in time.
  workerTimeout,

  /// A phrase was handed over before the worker was started.
  workerNotRunning,

  /// The worker replied with an error of its own.
  workerFailed,

  /// The pipeline was stopped while a phrase was in flight.
  pipelineStopped,

  /// Native audio or subtitle capture gave up; the detail is its own message.
  captureFailed,

  /// The pipeline only runs on Windows.
  windowsOnly,

  /// Opening a folder is a Windows affair too.
  explorerUnsupported,

  /// A model host answered with something other than 200.
  downloadRejected,

  /// A download stopped receiving data and kept stopping after every
  /// reconnect; the detail is the file. What arrived is kept.
  downloadStalled,

  /// A downloaded file did not match its pinned size or digest.
  verificationFailed,

  /// The SOCKS5 proxy host could not be resolved.
  socksLookupFailed,
  runtimeIncomplete,
  runtimeInstallFailed,
  updateCheckFailed,

  /// The proxy setting is not a URL the app accepts.
  proxyFormat,

  /// The proxy port is outside 1..65535.
  proxyPort,

  /// Loading settings, processes or model states failed at startup.
  initializationFailed,

  /// The saved voice fingerprints could not be deleted; the detail is the
  /// file system's own message.
  voiceBankClearFailed,

  /// A downloaded model could not be deleted; the detail is the file
  /// system's own message.
  modelRemoveFailed,
}

class LoreDubFailure implements Exception {
  const LoreDubFailure(this.code, {this.detail});

  final FailureCode code;

  /// Technical text that stays as it came — a path, a process's own output.
  /// Never translated, because it was never a sentence.
  final String? detail;

  @override
  String toString() =>
      detail == null ? 'LoreDubFailure(${code.name})' : 'LoreDubFailure(${code.name}): $detail';
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// How a download ended.
enum DownloadOutcome {
  /// Every artifact arrived and verified.
  completed,

  /// Stopped on request, with what had arrived kept on disk. Asking again
  /// carries on from there.
  paused,

  /// Stopped on request and the part thrown away.
  cancelled,
}

/// The handle the interface holds on a running download.
///
/// Pausing and cancelling differ only in what happens to the bytes already
/// written: a pause keeps the `.part` so the next attempt resumes, a cancel
/// removes it. Both are checked between chunks, so a stop takes effect
/// within one chunk rather than at the end of the file.
class DownloadControl {
  DownloadOutcome? _stop;

  /// Set once a stop has been asked for, and never unset: a control belongs
  /// to one attempt, and resuming starts a new one.
  DownloadOutcome? get requestedStop => _stop;

  bool get isStopping => _stop != null;
  bool get isCancelled => _stop == DownloadOutcome.cancelled;

  void pause() => _stop ??= DownloadOutcome.paused;

  /// Cancelling wins over a pause asked for a moment earlier: the stronger
  /// request is the one the user last meant.
  void cancel() => _stop = DownloadOutcome.cancelled;
}

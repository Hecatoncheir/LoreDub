// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// A package on its way to disk, whichever kind it is.
///
/// A model and a GPU runtime arrive the same way: the same progress, the
/// same pause that keeps what came and the same cancel that throws it
/// away, the same three outcomes, the same failure written on the row.
/// The cubit that fetches them had all of that twice, once per kind, and
/// both copies addressed the row by an index taken before the first
/// `await` — which named whatever stood there by the time the download
/// ended.
///
/// So this is what the two have in common, written once: what a row is
/// while it arrives, the id it is addressed by, and the five states it
/// passes through. [T] is the type mixing this in, so each transition
/// answers with its own kind.
mixin PackageDownload<T> {
  double? get progress;
  bool get paused;
  bool get installed;

  /// Why it failed, as raised; written out by the interface.
  Object? get error;

  /// What the download is asked for and addressed by.
  String get packageId;

  /// On its way: coming in rather than stopped part way.
  bool get arriving => progress != null && !paused;

  /// Whether there is an attempt to pause or cancel.
  bool get stoppable => progress != null;

  /// Asked for. A row that was paused keeps the bar where it stopped, so
  /// asking again reads as carrying on rather than starting over.
  T started();

  /// [progress] of the way there.
  T reaching(double progress);

  /// On disk.
  T arrived();

  /// Stopped with what came kept, so asking again resumes.
  T held();

  /// Stopped with what came thrown away.
  T dropped();

  T failing(Object error);
}

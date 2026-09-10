// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// Decides when a download's progress is worth telling the interface about.
///
/// The downloader reports every chunk, which for a 300 MB file is thousands
/// of callbacks. The interface renders whole percent, so anything finer
/// redraws the screen without changing a pixel. Reporting only when the
/// rounded value moves — and always at the end — cuts that to a hundred.
class ProgressTicker {
  ProgressTicker({this.steps = 100});

  /// How many distinct values the reader can see. A percentage has a hundred.
  final int steps;

  int? _last;

  /// Whether [value] shows something the last reported one did not.
  bool shouldReport(double value) {
    final step = (value.clamp(0, 1) * steps).floor();
    // The end is always worth reporting: it is what closes the bar.
    if (step == _last && value < 1) return false;
    _last = step;
    return true;
  }
}

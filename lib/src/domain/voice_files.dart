// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// The files dropped onto a card, decoded to the rate and the loudness the
/// capture writes at and waiting for the converter to measure them.
///
/// Decoding and measuring are two steps rather than one because a worker may
/// change hands between them: the files take a while, and whoever asked for
/// them has to be able to ask whether the session they were meant for is
/// still up before anything is written into the worker.
class VoiceFiles {
  const VoiceFiles({this.decoded = const {}, this.unreadable = const []});

  /// Each decoded recording, and the dropped file it was decoded from.
  final Map<String, String> decoded;

  /// The dropped files Windows could not read at all.
  final List<String> unreadable;
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// How the glossary screen is laid out and where it changes its arrangement.
abstract final class GlossaryLayout {
  /// What the handle an entry is dragged by takes on the left of a row. The
  /// empty row at the foot of a list leaves the same width blank, so the
  /// arrows down a list stand in one line.
  static const dragHandleWidth = 24.0;

  /// And what the button that passes a line over takes on the right of one.
  /// Only a phrase carries it, so only the phrase list leaves room for it.
  static const silenceSlotWidth = 48.0;

  /// Beyond this the packs stand beside the lists rather than under them.
  /// Below it the entry rows -- a source, an arrow and a field -- would be
  /// left too narrow to read the pair in.
  static const packsBesideListsWidth = 1040.0;

  /// The column the packs get. The same width the scene voices take beside
  /// the transcript, for the same reason: it is a list of short names.
  static const packsWidth = 340.0;
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// One line of what a tile holds: "translation · 461 MB", ticked once it
/// is on disk.
class ModelTilePart {
  const ModelTilePart({required this.label, required this.bytes, required this.installed});

  final String label;
  final int bytes;
  final bool installed;
}

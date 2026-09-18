// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/glossary.dart';

/// An entry on its way to a pack, and the pack it was dragged out of.
///
/// The source pack matters because dropping an entry on another pack moves
/// it rather than copying it: an entry may be in several packs, but dragging
/// one across says where it should be instead.
class GlossaryDrag {
  const GlossaryDrag({required this.entry, this.fromPackId});

  final GlossaryEntry entry;
  final String? fromPackId;
}

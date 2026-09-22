// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// The line of text on the canvas and the switches of the glossary: a pack
/// put into the line is switched on, and one taken out of it switched off.
///
/// The other way round there is nothing to follow. A switch -- on the node,
/// or the glossary screen's own -- moves no drawing: switched off, a pack
/// stays where it stands in the line and the text passes through it.
library;

import 'glossary.dart';
import 'pipeline_layout.dart';

/// Whether any drawing of [packId] stands in the line on [layout].
bool _standsInLine(PipelineLayout layout, String packId) =>
    layout.glossaries.any((placement) => placement.packId == packId && placement.feed != null);

/// [glossary] with every pack an edit of the canvas put in the line or took
/// out of it -- from [before] to [edited] -- switched to follow.
///
/// Only those: a pack the edit did not move keeps its switch, whatever the
/// canvas draws of it, and one moved along the line stays switched as it
/// was. A drawing taken off the canvas takes its pack out of the line when it
/// was the last of it there, as a node deleted takes its work with it.
Glossary packsFollowingLine(Glossary glossary, PipelineLayout before, PipelineLayout edited) {
  var switched = glossary;
  for (final pack in glossary.packs) {
    final now = _standsInLine(edited, pack.id);
    if (_standsInLine(before, pack.id) == now || pack.active == now) continue;
    switched = switched.activating(pack.id, active: now);
  }
  return switched;
}

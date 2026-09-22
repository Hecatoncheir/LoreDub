// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// The packs of the glossary drawn on the canvas: where each drawing stands
/// in the line of text, and what that lets the pack apply.
library;

import 'glossary.dart';
import 'pipeline_graph_model.dart';

/// Which side of the translator a pack stands in the line of text, which
/// decides which of its entries can be met there at all.
///
/// The line runs from whisper, through the packs drawn before the
/// translator, the translator and the packs drawn after it, to the voice.
/// The worker puts each kind right at a moment of its own: a phrase answers
/// a whole line by what whisper heard, before the translator is asked; a
/// name is written in where the translator left Latin, and a word is matched
/// on the dubbing language, after it. So a pack before the translator
/// applies its phrases and one after it its names and words, and a pack
/// wanted at both moments is drawn twice. The scheme adds no moment of its
/// own: it shows where each part of a pack takes effect, and a pack drawn at
/// one of them applies no more than that part.
enum GlossaryFeed {
  /// Before the translator: what whisper heard.
  recognition,

  /// After the translator: what it wrote.
  translation;

  /// The kinds a pack standing here reaches.
  ///
  /// With nothing to translate -- dubbing into English, which whisper hands
  /// over already -- no phrase is answered and no name written in, and what
  /// whisper heard is itself the language the lines are said in: a pack
  /// before the translator applies its words, and one after it stands aside
  /// with the translator and applies nothing.
  Set<GlossaryKind> kinds({required bool translates}) => switch (this) {
    recognition => translates ? const {GlossaryKind.phrase} : const {GlossaryKind.word},
    translation => translates ? const {GlossaryKind.name, GlossaryKind.word} : const {},
  };
}

/// One drawing of a pack on the canvas.
///
/// The pack is the player's and lives in the glossary; what a drawing
/// carries of its own is which pack it reads and where it stands in the line
/// of text. Several may draw one pack -- once before the translator and once
/// after it is how the whole of a pack is put in the line -- and all of them
/// answer to the pack's one switch, which moves none of them.
class GlossaryPlacement {
  const GlossaryPlacement({required this.nodeId, required this.packId, this.feed});

  final String nodeId;
  final String packId;

  /// Which side of the translator it stands, or null while it stands out of
  /// the line: the text then runs past it, and it applies nothing.
  final GlossaryFeed? feed;

  GlossaryPlacement copyWith({String? packId, GlossaryFeed? feed, bool unfed = false}) =>
      GlossaryPlacement(
        nodeId: nodeId,
        packId: packId ?? this.packId,
        feed: unfed ? null : feed ?? this.feed,
      );

  Map<String, Object?> toJson() => {
    'node': nodeId,
    'pack': packId,
    if (feed case final feed?) 'feed': feed.name,
  };

  static GlossaryPlacement? fromJson(Object? json) => switch (json) {
    {'node': final String node, 'pack': final String pack} when PipelineNodeIds.isGlossary(node) =>
      GlossaryPlacement(
        nodeId: node,
        packId: pack,
        // By name, so a place a later version adds is read as none rather
        // than as one of these.
        feed: GlossaryFeed.values.where((feed) => feed.name == json['feed']).firstOrNull,
      ),
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is GlossaryPlacement &&
      other.nodeId == nodeId &&
      other.packId == packId &&
      other.feed == feed;

  @override
  int get hashCode => Object.hash(nodeId, packId, feed);

  @override
  String toString() => 'GlossaryPlacement($nodeId: $packId${feed == null ? '' : ' ${feed!.name}'})';
}

/// What the drawings in [placed] let each of their packs apply: every kind
/// a drawing of it standing in the line reaches, added together.
///
/// A pack drawn only out of the line applies nothing, which is what its node
/// says. A pack the canvas does not draw is not named, and applies whole:
/// the scheme speaks for the packs it draws and for no others.
GlossaryReach glossaryReachOf(List<GlossaryPlacement> placed, {required bool translates}) {
  final reach = <String, Set<GlossaryKind>>{};
  for (final placement in placed) {
    final kinds = reach.putIfAbsent(placement.packId, () => <GlossaryKind>{});
    if (placement.feed case final feed?) kinds.addAll(feed.kinds(translates: translates));
  }
  return reach;
}

/// One change to the line of text, made by a line drawn or cut on the
/// canvas.
sealed class LineEdit {
  const LineEdit();
}

/// The drawing at [nodeId] put in the line right after [anchor] -- or right
/// before it, with [after] false -- out of wherever it stood.
///
/// [anchor] is whisper, the translator, the voice or another drawing
/// standing in the line, and the side of the translator it stands on is the
/// one [nodeId] takes: right after whisper is before the translator, right
/// before the voice is after it while there is a translator to be after.
final class LineMove extends LineEdit {
  const LineMove(this.nodeId, {required this.anchor, required this.after});

  final String nodeId;
  final String anchor;
  final bool after;

  @override
  bool operator ==(Object other) =>
      other is LineMove && other.nodeId == nodeId && other.anchor == anchor && other.after == after;

  @override
  int get hashCode => Object.hash(nodeId, anchor, after);

  @override
  String toString() => 'LineMove($nodeId ${after ? 'after' : 'before'} $anchor)';
}

/// The drawings at [nodeIds] taken out of the line: the text runs past them,
/// from what stood before them to what stood after.
final class LineRemove extends LineEdit {
  const LineRemove(this.nodeIds);

  final Set<String> nodeIds;

  @override
  bool operator ==(Object other) =>
      other is LineRemove &&
      other.nodeIds.length == nodeIds.length &&
      other.nodeIds.containsAll(nodeIds);

  @override
  int get hashCode => Object.hashAllUnordered(nodeIds);

  @override
  String toString() => 'LineRemove($nodeIds)';
}

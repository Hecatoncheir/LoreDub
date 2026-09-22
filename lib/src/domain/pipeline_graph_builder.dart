// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// The graph the settings, the cast and the layout describe.
library;

import 'app_settings.dart';
import 'character.dart';
import 'pipeline_graph_model.dart';
import 'pipeline_layout.dart';

/// The graph [settings] and [characters] describe, arranged as [layout].
///
/// Worked out in the order each part needs the one before: where the cards
/// stand, where each card's part goes from there, which cards carry a line
/// at all -- and only then the nodes and the links, each made once.
PipelineGraph buildPipelineGraph({
  required AppSettings settings,
  required List<Character> characters,
  PipelineLayout layout = PipelineLayout.standard,
}) {
  final byId = {for (final character in characters) character.id: character};
  final placed = _placedCast(layout.cast, byId);
  final routed = settings.captureRouted;
  // Dubbing into English has nothing to translate -- whisper has handed
  // English over already -- so the stage stands out of the line with the
  // text going past it. The canvas reads that off the language rather than
  // off a setting of its own: there is one answer to where the dubbing is
  // going, and it is chosen on the models screen or here.
  final translates = settings.translates;
  final castAt = {
    for (final (index, placement) in placed.indexed)
      placement.nodeId: layout.positions[placement.nodeId] ?? PipelineLayout.castPlace(index),
  };
  // A card cut out of the mix takes no part in the arrangement: it is drawn
  // where it stands and nothing runs through it, so the lines are worked out
  // over the rest. A card it used to read then speaks for itself, which is
  // what falls out of looking for its reader among these.
  final voiced = [
    for (final placement in placed)
      if (!layout.silent.contains(placement.characterId)) placement,
  ];
  final sends = {
    for (final placement in voiced) placement.nodeId: _partOf(placement, byId, voiced, castAt),
  };
  final carrying = _carrying(voiced, byId, sends);
  return PipelineGraph(
    nodes: [
      ..._stageNodes(layout, routed: routed, translates: translates),
      for (final placement in placed)
        PipelineNode(
          id: placement.nodeId,
          kind: PipelineNodeKind.character,
          characterId: placement.characterId,
          position: castAt[placement.nodeId]!,
          unrouted: layout.silent.contains(placement.characterId),
          sendsToMix: _sendsToMix(placement, carrying, sends),
        ),
    ],
    links: [
      ..._stageLinks(routed: routed, translates: translates),
      ..._castLinks(voiced, carrying, sends),
    ],
    routed: routed,
    chained: _chained(placed, byId),
  );
}

/// A card whose line ends at the mix is heard as itself; one that hands its
/// part to another card is not, and the canvas draws the two apart.
bool _sendsToMix(
  CastPlacement placement,
  Set<String> carrying,
  Map<String, PipelinePort> sends,
) => carrying.contains(placement.nodeId) && sends[placement.nodeId]?.nodeId == PipelineNodeIds.mix;

/// The lines the cards drawn in the mix carry, into them and out of them.
List<PipelineLink> _castLinks(
  List<CastPlacement> voiced,
  Set<String> carrying,
  Map<String, PipelinePort> sends,
) => [
  // A note rather than a route: the dashed line says the game's own
  // dialogue may hold this character. A card drawn only to lend its
  // voice carries none, and the pipeline runs the same either way.
  for (final placement in voiced)
    if (placement.heard)
      PipelineLink(
        const PipelinePort(PipelineNodeIds.voice, PipelineSocket.voiceCast),
        PipelinePort(placement.nodeId, PipelineSocket.characterIn),
      ),
  // A card's lines leave it one way only: into the card that speaks for
  // it, which carries them on to the mix, or into the mix itself when it
  // speaks for itself.
  for (final placement in voiced)
    if (carrying.contains(placement.nodeId))
      PipelineLink(
        PipelinePort(placement.nodeId, PipelineSocket.characterVoice),
        sends[placement.nodeId]!,
      ),
];

/// The characters drawn whose reader is read by a third in turn: the
/// substitution is followed one hop only, and the canvas says so.
Set<String> _chained(List<CastPlacement> placed, Map<String, Character> byId) => {
  for (final placement in placed)
    if (byId[byId[placement.characterId]?.voicedBy]?.voicedBy != null) placement.characterId,
};

/// The six stages of the pipeline, where [layout] put them.
List<PipelineNode> _stageNodes(
  PipelineLayout layout, {
  required bool routed,
  required bool translates,
}) => [
  for (final id in PipelineNodeIds.stages)
    PipelineNode(
      id: id,
      kind: switch (id) {
        PipelineNodeIds.source => PipelineNodeKind.source,
        PipelineNodeIds.recognition => PipelineNodeKind.recognition,
        PipelineNodeIds.translation => PipelineNodeKind.translation,
        PipelineNodeIds.voice => PipelineNodeKind.voice,
        PipelineNodeIds.mix => PipelineNodeKind.mix,
        _ => PipelineNodeKind.output,
      },
      position: layout.positions[id] ?? PipelineLayout.standardPositions[id] ?? GraphPoint.zero,
      unrouted: !routed || (id == PipelineNodeIds.translation && !translates),
    ),
];

/// The lines between the stages: the pipeline itself.
List<PipelineLink> _stageLinks({required bool routed, required bool translates}) {
  const translation = PipelinePort(PipelineNodeIds.translation, PipelineSocket.translationIn);
  const speechText = PipelinePort(PipelineNodeIds.recognition, PipelineSocket.speechText);
  const voiceIn = PipelinePort(PipelineNodeIds.voice, PipelineSocket.voiceIn);
  return [
    // Nothing feeds the stages while the way in is taken apart. What runs
    // between them is the pipeline itself and stays drawn, faded with them.
    if (routed) ...[
      const PipelineLink(
        PipelinePort(PipelineNodeIds.source, PipelineSocket.gameAudio),
        PipelinePort(PipelineNodeIds.recognition, PipelineSocket.speechIn),
      ),
      // What whisper heard goes to the translator, or straight to the voice
      // when there is nothing to translate.
      if (translates)
        const PipelineLink(speechText, translation)
      else
        const PipelineLink(speechText, voiceIn),
    ],
    if (translates)
      const PipelineLink(
        PipelinePort(PipelineNodeIds.translation, PipelineSocket.translatedText),
        voiceIn,
      ),
    const PipelineLink(
      PipelinePort(PipelineNodeIds.voice, PipelineSocket.voiceAudio),
      PipelinePort(PipelineNodeIds.mix, PipelineSocket.mixIn),
    ),
    const PipelineLink(
      PipelinePort(PipelineNodeIds.mix, PipelineSocket.mixOut),
      PipelinePort(PipelineNodeIds.output, PipelineSocket.streamIn),
    ),
  ];
}

/// Where the part drawn at [from] goes: into the nearest drawing of the card
/// that speaks for it, or into the mix when it speaks for itself.
///
/// The nearest one, because a card is drawn twice precisely so the line has
/// somewhere short to run — the copy the player put beside this one is the
/// copy they meant. A card standing in for another that is nowhere on the
/// canvas sends its part to the mix, and says whose voice reads it on its
/// own face.
PipelinePort _partOf(
  CastPlacement from,
  Map<String, Character> byId,
  List<CastPlacement> placed,
  Map<String, GraphPoint> where,
) {
  const mix = PipelinePort(PipelineNodeIds.mix, PipelineSocket.mixCast);
  final reader = byId[from.characterId]?.voicedBy;
  if (reader == null || reader == from.characterId) return mix;
  CastPlacement? nearest;
  var best = double.infinity;
  final here = where[from.nodeId] ?? GraphPoint.zero;
  for (final placement in placed) {
    if (placement.characterId != reader) continue;
    final there = where[placement.nodeId] ?? GraphPoint.zero;
    final span = (there.x - here.x) * (there.x - here.x) + (there.y - here.y) * (there.y - here.y);
    if (span >= best) continue;
    best = span;
    nearest = placement;
  }
  return nearest == null ? mix : PipelinePort(nearest.nodeId, PipelineSocket.readBy);
}

/// The drawings that have a line to send on.
///
/// A card the game speaks has its own part; a card another's part arrives at
/// carries it on to wherever its own would go; and a card whose character is
/// read by somebody sends its part even when the game never speaks it, since
/// a substitution nobody can see is a trap.
Set<String> _carrying(
  List<CastPlacement> placed,
  Map<String, Character> byId,
  Map<String, PipelinePort> sends,
) {
  final carrying = {
    for (final placement in placed)
      if (placement.heard || byId[placement.characterId]?.voicedBy != null) placement.nodeId,
  };
  // What a card takes over it also passes on, and so may the card after it.
  for (var pass = 0; pass < placed.length; pass++) {
    if (!_passOn(carrying, placed, sends)) break;
  }
  return carrying;
}

/// Adds to [carrying] every card a carrying card hands its part to, and
/// answers whether that added any.
bool _passOn(Set<String> carrying, List<CastPlacement> placed, Map<String, PipelinePort> sends) {
  var grew = false;
  for (final placement in placed) {
    final to = sends[placement.nodeId];
    if (to == null || to.socket != PipelineSocket.readBy) continue;
    if (carrying.contains(placement.nodeId) && carrying.add(to.nodeId)) grew = true;
  }
  return grew;
}

/// The drawings the canvas keeps: the ones the player put there whose card
/// is still in the cast. A card is taken off the canvas when the player
/// asks, even while another card on it is read in their voice — that line
/// then comes to nothing until they are put back, which is what the empty
/// socket says.
List<CastPlacement> _placedCast(List<CastPlacement> placed, Map<String, Character> byId) {
  final drawn = [
    for (final placement in placed)
      if (byId.containsKey(placement.characterId)) placement,
  ];
  // The card that speaks for another is laid out after it, so a line
  // between two that were never moved runs the way every other one does:
  // out of the right edge of the part, into the left of whoever takes it
  // over.
  for (final placement in [...drawn]) {
    final reader = byId[placement.characterId]?.voicedBy;
    if (reader == null) continue;
    final at = drawn.indexWhere((other) => other.characterId == reader);
    if (at < 0 || at > drawn.indexOf(placement)) continue;
    final moved = drawn.removeAt(at);
    drawn.insert(drawn.indexOf(placement) + 1, moved);
  }
  return drawn;
}

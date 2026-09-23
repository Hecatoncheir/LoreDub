// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// The graph the settings, the cast, the glossary and the layout describe.
library;

import 'app_settings.dart';
import 'character.dart';
import 'glossary.dart';
import 'pipeline_glossary.dart';
import 'pipeline_graph_model.dart';
import 'pipeline_layout.dart';

/// What a scheme's routes are, read off the settings: whether the way in is
/// drawn, whether the translator stands in the line of text, and -- on the
/// Screen page's -- whether the voices behind the screen are told apart.
typedef _Routes = ({bool routed, bool translates, bool hears});

/// [scheme]'s routes under [settings].
///
/// On Эфир, dubbing into English has nothing to translate -- whisper has
/// handed English over already -- so the stage stands out of the line with
/// the text going past it. On the Screen page, text read in the dubbing
/// language itself has nothing to translate either. Either way the canvas
/// reads it off the languages rather than off a setting of its own: there is
/// one answer to where the dubbing is going, and it is chosen on the models
/// screen, on the Screen page or here. The screen is always read, so its
/// scheme is always routed; the game's sound is what may be left out.
_Routes _routesOf(AppSettings settings, PipelineScheme scheme) => switch (scheme) {
  PipelineScheme.live => (
    routed: settings.captureRouted,
    translates: settings.translates,
    hears: false,
  ),
  PipelineScheme.screen => (
    routed: true,
    translates: settings.screenTranslates,
    hears: settings.screenVoices,
  ),
};

/// The graph [settings], [characters] and the glossary's [packs] describe,
/// arranged as [layout], on [scheme].
///
/// Worked out in the order each part needs the one before: where the cards
/// stand, where each card's part goes from there, which cards carry a line
/// at all -- and only then the nodes and the links, each made once.
PipelineGraph buildPipelineGraph({
  required AppSettings settings,
  required List<Character> characters,
  List<GlossaryPack> packs = const [],
  PipelineLayout layout = PipelineLayout.standard,
  PipelineScheme scheme = PipelineScheme.live,
}) {
  final byId = {for (final character in characters) character.id: character};
  final placed = _placedCast(layout.cast, byId);
  final routes = _routesOf(settings, scheme);
  final (:routed, :translates, hears: _) = routes;
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
  final shelf = {for (final pack in packs) pack.id: pack.active};
  final glossaries = [
    for (final placement in layout.glossaries)
      if (shelf.containsKey(placement.packId)) placement,
  ];
  return PipelineGraph(
    nodes: [
      ..._stageNodes(layout, scheme, routes),
      for (final placement in placed)
        PipelineNode(
          id: placement.nodeId,
          kind: PipelineNodeKind.character,
          characterId: placement.characterId,
          position: castAt[placement.nodeId]!,
          unrouted: layout.silent.contains(placement.characterId),
          sendsToMix: _sendsToMix(placement, carrying, sends),
          scheme: scheme,
        ),
      ..._glossaryNodes(glossaries, layout, shelf, scheme, routes),
    ],
    links: [
      ..._soundLinks(scheme, routes),
      ..._lineLinks(glossaries, head: _headOf(scheme), routed: routed, translates: translates),
      ..._castLinks(voiced, carrying, sends),
    ],
    routed: routed,
    translates: translates,
    chained: _chained(placed, byId),
    scheme: scheme,
  );
}

/// The packs of the glossary drawn on the canvas, where the player left
/// them or in a row over the line.
///
/// A drawing the text does not run through -- one out of the line, any
/// while the way in is taken apart, one after a translator standing aside --
/// applies nothing, and is drawn faded as a stage with nothing reaching it
/// is. One whose pack is switched off, by [active] (by pack), stays where it
/// stands, the text passing through it.
List<PipelineNode> _glossaryNodes(
  List<GlossaryPlacement> placed,
  PipelineLayout layout,
  Map<String, bool> active,
  PipelineScheme scheme,
  _Routes routes,
) => [
  for (final (index, placement) in placed.indexed)
    PipelineNode(
      id: placement.nodeId,
      kind: PipelineNodeKind.glossary,
      packId: placement.packId,
      feed: placement.feed,
      active: active[placement.packId] ?? false,
      position:
          layout.positions[placement.nodeId] ?? PipelineLayout.glossaryPlace(index, scheme: scheme),
      unrouted:
          !routes.routed || (placement.feed?.kinds(translates: routes.translates).isEmpty ?? true),
      scheme: scheme,
    ),
];

/// Where the line of text leaves the stage it starts at.
PipelinePort _headOf(PipelineScheme scheme) => switch (scheme) {
  PipelineScheme.live => const PipelinePort(
    PipelineNodeIds.recognition,
    PipelineSocket.speechText,
  ),
  PipelineScheme.screen => const PipelinePort(PipelineNodeIds.screen, PipelineSocket.screenText),
};

/// One stop on the line of text: the socket the text arrives by, and the
/// one it leaves by. Whisper has no text arriving, the voice none leaving.
typedef _Stop = ({PipelinePort? into, PipelinePort? out});

_Stop _packStop(String nodeId) => (
  into: PipelinePort(nodeId, PipelineSocket.glossaryIn),
  out: PipelinePort(nodeId, PipelineSocket.glossaryOut),
);

/// The line of text, whisper -- or the screen, at [head] -- to the voice:
/// the packs standing before the translator, the translator where it
/// translates, the packs after it -- each handing the text on to the next.
///
/// Nothing reaches whisper while the way in is taken apart, and the line out
/// of it goes with that; what runs past it is the pipeline itself and stays
/// drawn, faded with the stages. A translator stepped over stands aside with
/// the packs drawn after it, joined to nothing, and the text runs through
/// the packs before it straight into the voice.
List<PipelineLink> _lineLinks(
  List<GlossaryPlacement> placed, {
  required PipelinePort head,
  required bool routed,
  required bool translates,
}) {
  final List<_Stop> line = [
    (into: null, out: head),
    for (final placement in placed)
      if (placement.feed == GlossaryFeed.recognition) _packStop(placement.nodeId),
    if (translates) ...[
      (
        into: const PipelinePort(PipelineNodeIds.translation, PipelineSocket.translationIn),
        out: const PipelinePort(PipelineNodeIds.translation, PipelineSocket.translatedText),
      ),
      for (final placement in placed)
        if (placement.feed == GlossaryFeed.translation) _packStop(placement.nodeId),
    ],
    (into: const PipelinePort(PipelineNodeIds.voice, PipelineSocket.voiceIn), out: null),
  ];
  return [
    for (var at = routed ? 1 : 2; at < line.length; at++)
      PipelineLink(line[at - 1].out!, line[at].into!),
  ];
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

/// [scheme]'s stages, where [layout] put them.
List<PipelineNode> _stageNodes(PipelineLayout layout, PipelineScheme scheme, _Routes routes) => [
  for (final id in scheme.stages)
    PipelineNode(
      id: id,
      kind: _kindOf(id),
      position: layout.positions[id] ?? PipelineLayout.positionsOf(scheme)[id] ?? GraphPoint.zero,
      unrouted: _unrouted(id, scheme, routes),
      // The detection is switched on and off as its route is drawn and cut,
      // the two being one fact: whether the voices behind the screen are
      // told apart.
      active: id != PipelineNodeIds.detection || routes.hears,
      scheme: scheme,
    ),
];

PipelineNodeKind _kindOf(String stage) => switch (stage) {
  PipelineNodeIds.source => PipelineNodeKind.source,
  PipelineNodeIds.recognition => PipelineNodeKind.recognition,
  PipelineNodeIds.translation => PipelineNodeKind.translation,
  PipelineNodeIds.voice => PipelineNodeKind.voice,
  PipelineNodeIds.mix => PipelineNodeKind.mix,
  PipelineNodeIds.screen => PipelineNodeKind.screen,
  PipelineNodeIds.detection => PipelineNodeKind.detection,
  _ => PipelineNodeKind.output,
};

/// Whether nothing reaches [stage]: every stage while the way in is taken
/// apart, the translator while it is stepped over, and on the Screen page
/// the game's sound and its detection while the voices are not listened
/// for. On Эфир the game's sound feeds everything, and goes only with it.
bool _unrouted(String stage, PipelineScheme scheme, _Routes routes) => switch (stage) {
  _ when !routes.routed => true,
  PipelineNodeIds.translation => !routes.translates,
  PipelineNodeIds.source ||
  PipelineNodeIds.detection => scheme == PipelineScheme.screen && !routes.hears,
  _ => false,
};

/// The lines of sound. On Эфир: the game's into whisper -- while the way in
/// is drawn -- the voice's into the mix, the mix's out. On the Screen page
/// the game's sound goes into the detection instead, and who it says is
/// speaking into the voice, both only while the voices are listened for.
List<PipelineLink> _soundLinks(PipelineScheme scheme, _Routes routes) => [
  if (scheme == PipelineScheme.live && routes.routed)
    const PipelineLink(
      PipelinePort(PipelineNodeIds.source, PipelineSocket.gameAudio),
      PipelinePort(PipelineNodeIds.recognition, PipelineSocket.speechIn),
    ),
  if (scheme == PipelineScheme.screen && routes.hears) ...const [
    PipelineLink(
      PipelinePort(PipelineNodeIds.source, PipelineSocket.gameAudio),
      PipelinePort(PipelineNodeIds.detection, PipelineSocket.detectionIn),
    ),
    PipelineLink(
      PipelinePort(PipelineNodeIds.detection, PipelineSocket.detectedSpeaker),
      PipelinePort(PipelineNodeIds.voice, PipelineSocket.voiceSpeaker),
    ),
  ],
  const PipelineLink(
    PipelinePort(PipelineNodeIds.voice, PipelineSocket.voiceAudio),
    PipelinePort(PipelineNodeIds.mix, PipelineSocket.mixIn),
  ),
  const PipelineLink(
    PipelinePort(PipelineNodeIds.mix, PipelineSocket.mixOut),
    PipelinePort(PipelineNodeIds.output, PipelineSocket.streamIn),
  ),
];

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

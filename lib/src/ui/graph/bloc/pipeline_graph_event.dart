// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

part of 'pipeline_graph_bloc.dart';

/// What the canvas was asked to do.
///
/// This part of the dashboard is a Bloc rather than a Cubit because the
/// canvas is worked by a sequence of gestures, not by calls: a grab, a
/// hundred moves and a drop are one action, and an event each is what lets
/// them be replayed, undone and tested as a script.
sealed class PipelineGraphEvent extends Equatable {
  const PipelineGraphEvent();

  @override
  List<Object?> get props => const [];
}

/// The screen was opened: read the arrangement and draw what the settings
/// and the cast describe.
final class PipelineGraphOpened extends PipelineGraphEvent {
  const PipelineGraphOpened();
}

/// The settings, the cast or the glossary changed under the canvas, from
/// here or from another screen.
final class PipelineGraphRefreshed extends PipelineGraphEvent {
  const PipelineGraphRefreshed();
}

/// A node was taken hold of; where it was is remembered so the drag can be
/// undone as one move rather than a hundred.
final class PipelineNodeGrabbed extends PipelineGraphEvent {
  const PipelineNodeGrabbed(this.nodeId);

  final String nodeId;

  @override
  List<Object?> get props => [nodeId];
}

/// A node was dragged by [dx], [dy] on the canvas, zoom already taken out.
final class PipelineNodeMoved extends PipelineGraphEvent {
  const PipelineNodeMoved(this.nodeId, this.dx, this.dy);

  final String nodeId;
  final double dx;
  final double dy;

  @override
  List<Object?> get props => [nodeId, dx, dy];
}

/// A gesture ended — a node let go, the canvas let go of — and the
/// arrangement is written to disk.
final class PipelineArrangementSettled extends PipelineGraphEvent {
  const PipelineArrangementSettled();
}

final class PipelineNodeSelected extends PipelineGraphEvent {
  const PipelineNodeSelected(this.nodeId, {this.add = false});

  /// Null closes the inspector and clears the choice.
  final String? nodeId;

  /// Set by a click with shift held: the node joins what is already chosen,
  /// or leaves it if it was there. Without it the choice collapses to this
  /// one node, which is what a plain click has always done.
  final bool add;

  @override
  List<Object?> get props => [nodeId, add];
}

/// Everything the band covered, as the canvas worked it out. The canvas owns
/// the geometry — where a card sits and how big it is — so it says which
/// nodes were caught and the bloc keeps the choice.
final class PipelineSelectionSet extends PipelineGraphEvent {
  const PipelineSelectionSet(this.nodeIds);

  final Set<String> nodeIds;

  @override
  List<Object?> get props => [nodeIds];
}

/// A link is being pulled out of [port].
final class PipelineLinkStarted extends PipelineGraphEvent {
  const PipelineLinkStarted(this.port, this.at);

  final PipelinePort port;
  final GraphPoint at;

  @override
  List<Object?> get props => [port, at];
}

final class PipelineLinkDragged extends PipelineGraphEvent {
  const PipelineLinkDragged(this.at);

  final GraphPoint at;

  @override
  List<Object?> get props => [at];
}

/// The link was let go, over [target] or over nothing.
final class PipelineLinkReleased extends PipelineGraphEvent {
  const PipelineLinkReleased(this.target);

  final PipelinePort? target;

  @override
  List<Object?> get props => [target];
}

/// A substitution was cut, so the character is read by the pipeline again.
final class PipelineLinkCut extends PipelineGraphEvent {
  const PipelineLinkCut(this.link);

  final PipelineLink link;

  @override
  List<Object?> get props => [link];
}

/// A card was drawn on the canvas. A card already there is drawn again
/// rather than refused: a copy beside the character whose part it takes
/// over keeps the line between them short.
final class PipelineCharacterPlaced extends PipelineGraphEvent {
  const PipelineCharacterPlaced(this.characterId);

  final String characterId;

  @override
  List<Object?> get props => [characterId];
}

/// One drawing of a card or of a pack was taken off the canvas. The card
/// keeps whatever voice reads it and its other drawings stay: only this
/// node goes. A pack goes out of the line of text with the node, and is
/// switched off when no other drawing of it stands there.
final class PipelineNodeRemoved extends PipelineGraphEvent {
  const PipelineNodeRemoved(this.nodeId);

  final String nodeId;

  @override
  List<Object?> get props => [nodeId];
}

/// A pack of the glossary was drawn on the canvas, out of the line of text
/// until a line is drawn into it or out of it. A pack already there is drawn
/// again rather than refused: once before the translator and once after it
/// is how the whole of a pack is put in the line.
final class PipelineGlossaryPlaced extends PipelineGraphEvent {
  const PipelineGlossaryPlaced(this.packId);

  final String packId;

  @override
  List<Object?> get props => [packId];
}

/// The pack a glossary node reads, chosen in its panel. The node keeps its
/// place and its lines: it is the same node with another pack in it.
final class PipelineGlossaryPackChosen extends PipelineGraphEvent {
  const PipelineGlossaryPackChosen(this.nodeId, this.packId);

  final String nodeId;
  final String packId;

  @override
  List<Object?> get props => [nodeId, packId];
}

/// The switch on a glossary node, or in its panel: the pack it draws on or
/// off, the node staying where it stands. Switched off, the text passes
/// through it as it came.
final class PipelineGlossarySwitched extends PipelineGraphEvent {
  const PipelineGlossarySwitched(this.nodeId, {required this.active});

  final String nodeId;
  final bool active;

  @override
  List<Object?> get props => [nodeId, active];
}

final class PipelineViewPanned extends PipelineGraphEvent {
  const PipelineViewPanned(this.dx, this.dy);

  final double dx;
  final double dy;

  @override
  List<Object?> get props => [dx, dy];
}

final class PipelineViewZoomed extends PipelineGraphEvent {
  const PipelineViewZoomed(this.zoom, this.focus);

  final double zoom;

  /// Where the pointer is on the screen, so what is under it stays there.
  final GraphPoint focus;

  @override
  List<Object?> get props => [zoom, focus];
}

/// The canvas put where it should be seen from: what the canvas works out
/// for itself when the scheme has never been fitted into the window.
final class PipelineViewSet extends PipelineGraphEvent {
  const PipelineViewSet(this.view);

  final GraphView view;

  @override
  List<Object?> get props => [view];
}

/// Everything back where it started: the standard arrangement, seen whole.
final class PipelineLayoutReset extends PipelineGraphEvent {
  const PipelineLayoutReset();
}

/// The scheme as it stands is kept on the shelf under [name].
final class PipelineSchemeSaved extends PipelineGraphEvent {
  const PipelineSchemeSaved(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

/// A kept scheme is drawn again and becomes the one that runs.
final class PipelineSchemeChosen extends PipelineGraphEvent {
  const PipelineSchemeChosen(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Writes what is on the canvas over a scheme already kept, under the name
/// it already carries. A scheme is worked on rather than written once: the
/// alternative was keeping it again under the same name and throwing the
/// old one away by hand.
final class PipelineSchemeReplaced extends PipelineGraphEvent {
  const PipelineSchemeReplaced(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

final class PipelineSchemeRenamed extends PipelineGraphEvent {
  const PipelineSchemeRenamed(this.id, this.name);

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

final class PipelineSchemeRemoved extends PipelineGraphEvent {
  const PipelineSchemeRemoved(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// One scheme written to a file of the player's choosing.
final class PipelineSchemeExported extends PipelineGraphEvent {
  const PipelineSchemeExported(this.id, this.destination);

  final String id;
  final String destination;

  @override
  List<Object?> get props => [id, destination];
}

/// Schemes read from files, added to the shelf by id.
final class PipelineSchemeImported extends PipelineGraphEvent {
  const PipelineSchemeImported(this.sources);

  final List<String> sources;

  @override
  List<Object?> get props => [sources];
}

final class PipelineGraphUndone extends PipelineGraphEvent {
  const PipelineGraphUndone();
}

final class PipelineGraphRedone extends PipelineGraphEvent {
  const PipelineGraphRedone();
}

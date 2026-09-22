// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

part of 'pipeline_graph_bloc.dart';

/// A link being pulled, from the socket it left to wherever the pointer is.
class PipelineLinkDrag {
  const PipelineLinkDrag({required this.from, required this.at});

  final PipelinePort from;
  final GraphPoint at;
}

class PipelineGraphState extends Equatable {
  const PipelineGraphState({
    this.loading = true,
    this.graph = const PipelineGraph(),
    this.layout = PipelineLayout.standard,
    this.selected,
    this.chosen = const {},
    this.schemes = const [],
    this.drag,
    this.refusal,
    this.canUndo = false,
    this.canRedo = false,
  });

  final bool loading;
  final PipelineGraph graph;
  final PipelineLayout layout;

  /// The node the inspector is showing, if any. Null while several are
  /// chosen: one node's settings over a choice of five would be a trap.
  final String? selected;

  /// Every node chosen, which is what a drag moves and what the canvas
  /// draws with an edge. One node clicked is a choice of one.
  final Set<String> chosen;

  /// The schemes kept on the shelf, newest last, each drawn as a card with
  /// a picture of itself.
  final List<SavedPipeline> schemes;

  /// The link the pointer is carrying, while it carries one.
  final PipelineLinkDrag? drag;

  /// Why the last attempt at a link came to nothing. Cleared as soon as the
  /// next one starts, so the hint belongs to what just happened.
  final ConnectionRefusal? refusal;

  final bool canUndo;
  final bool canRedo;

  PipelineNode? get selectedNode => selected == null ? null : graph.node(selected!);

  PipelineGraphState copyWith({
    bool? loading,
    PipelineGraph? graph,
    PipelineLayout? layout,
    String? selected,
    bool clearSelected = false,
    Set<String>? chosen,
    List<SavedPipeline>? schemes,
    PipelineLinkDrag? drag,
    bool clearDrag = false,
    ConnectionRefusal? refusal,
    bool clearRefusal = false,
    bool? canUndo,
    bool? canRedo,
  }) => PipelineGraphState(
    loading: loading ?? this.loading,
    graph: graph ?? this.graph,
    layout: layout ?? this.layout,
    selected: clearSelected ? null : selected ?? this.selected,
    chosen: chosen ?? this.chosen,
    schemes: schemes ?? this.schemes,
    drag: clearDrag ? null : drag ?? this.drag,
    refusal: clearRefusal ? null : refusal ?? this.refusal,
    canUndo: canUndo ?? this.canUndo,
    canRedo: canRedo ?? this.canRedo,
  );

  @override
  List<Object?> get props => [
    loading,
    graph,
    layout,
    selected,
    chosen,
    schemes,
    drag,
    refusal,
    canUndo,
    canRedo,
  ];
}

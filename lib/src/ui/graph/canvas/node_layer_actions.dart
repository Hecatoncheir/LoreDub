// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/widgets.dart';

import '../../../domain/pipeline_graph.dart';

/// What a node's layer tells the canvas. Made once by the canvas and handed
/// to every layer, so a layer kept from the frame before is still the same
/// widget -- a closure made afresh would not be.
@immutable
class NodeLayerActions {
  const NodeLayerActions({
    required this.onTap,
    required this.onGrab,
    required this.onDrag,
    required this.onDrop,
    required this.onRemove,
    required this.onSwitch,
    required this.onLinkStart,
    required this.onLinkToggle,
    required this.onLinkDrag,
    required this.onLinkEnd,
  });

  final void Function(String nodeId) onTap;
  final void Function(String nodeId, Offset global) onGrab;
  final void Function(String nodeId, Offset global) onDrag;
  final VoidCallback onDrop;
  final void Function(String nodeId) onRemove;

  /// The switch on a glossary node: the pack it draws on or off.
  final void Function(String nodeId, bool active) onSwitch;
  final void Function(PipelinePort port, Offset global) onLinkStart;

  /// The same line drawn without a pointer: the first socket takes it up,
  /// the second puts it down, and the one it started from lets it go.
  final void Function(PipelinePort port) onLinkToggle;
  final void Function(Offset global) onLinkDrag;
  final VoidCallback onLinkEnd;
}

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
    required this.onLinkStart,
    required this.onLinkDrag,
    required this.onLinkEnd,
  });

  final void Function(String nodeId) onTap;
  final void Function(String nodeId, Offset global) onGrab;
  final void Function(String nodeId, Offset global) onDrag;
  final VoidCallback onDrop;
  final void Function(String nodeId) onRemove;
  final void Function(PipelinePort port, Offset global) onLinkStart;
  final void Function(Offset global) onLinkDrag;
  final VoidCallback onLinkEnd;
}

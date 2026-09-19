// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../../domain/compute_device.dart';
import '../../../domain/pipeline_graph.dart';
import 'pipeline_facts.dart';

/// Everything one node's layer is drawn from, other than the canvas under
/// it. Compared field by field, so every one of them has to be a value: the
/// sockets a line reaches are a number rather than a set, and so are the
/// ones that would take the line being pulled -- worked out by the canvas,
/// since whether a socket takes a line is a question of the whole graph and
/// the cast, which a layer is not drawn from.
typedef NodeInputs = ({
  PipelineNode node,
  bool selected,
  double zoom,
  PipelineFacts facts,
  ComputeAvailability availability,
  int filled,
  int offered,
  PipelinePort? over,
});

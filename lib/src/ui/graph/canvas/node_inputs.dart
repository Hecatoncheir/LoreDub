// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../../domain/compute_device.dart';
import '../../../domain/pipeline_graph.dart';
import 'pipeline_facts.dart';

/// Everything one node's layer is drawn from, other than the canvas under
/// it. Compared field by field, so every one of them has to be a value: the
/// sockets a line reaches are a number rather than a set, and what a drag
/// carries is the socket it left rather than where the pointer has got to.
typedef NodeInputs = ({
  PipelineNode node,
  bool selected,
  double zoom,
  PipelineFacts facts,
  ComputeAvailability availability,
  int filled,
  PipelinePort? pulling,
  PipelinePort? over,
});

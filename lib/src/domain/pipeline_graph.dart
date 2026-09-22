// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

/// The pipeline drawn as nodes, and the rules for rewiring it.
///
/// The graph is not a second copy of the configuration: it is built from
/// [AppSettings] and the player's cast every time either changes, and every
/// edit is turned back into a change to one of them. What the engine can
/// actually run is therefore what can be drawn — a link the pipeline has no
/// answer for is refused with a reason rather than saved and ignored.
library;

export 'pipeline_connections.dart';
export 'pipeline_graph_builder.dart';
export 'pipeline_graph_model.dart';
export 'pipeline_layout.dart';

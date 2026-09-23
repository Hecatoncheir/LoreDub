// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../../domain/pipeline_graph.dart';
import 'pipeline_graph_bloc.dart';

/// The Screen page's canvas: the same machine as Эфир's, over the screen's
/// stages -- the text read off it, the character detection listening to the
/// game behind it -- and the arrangement and shelf kept for it.
///
/// A type of its own only so that the two can be provided side by side:
/// the Screen page hands this one down as a [PipelineGraphBloc], and the
/// canvas, its toolbar and its panel read it as they read Эфир's.
class ScreenSchemeBloc extends PipelineGraphBloc {
  ScreenSchemeBloc(
    super.schemes,
    super.settings,
    super.characters,
    super.glossary,
    super.installed,
    super.sessions,
    super.errors, {
    super.clock,
  }) : super(scheme: PipelineScheme.screen);
}

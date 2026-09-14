// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'model_selection.dart';

/// One thing that has to be done before live dubbing can start.
///
/// The order is the order they are met in: what is downloaded once, then the
/// route that is drawn once, then the game chosen every session.
enum StartStep {
  /// The packages the chosen mode and language need are not all on disk.
  models,

  /// The way into the pipeline has been taken apart on the graph.
  route,

  /// The mode listens to one process, and none has been picked.
  game,
}

/// What still stands between the player and the first press of Start, in the
/// order the interface offers them.
///
/// It is the reasons `LivePipelineState.canStart` refuses for, named: a
/// button that is simply dead tells a player nothing about which of the
/// three it is waiting on, and the first of them is met on a machine that
/// has only just installed the application.
List<StartStep> stepsBeforeStart(ModelSelection selection, {required bool gameChosen}) => [
  if (!selection.requiredModelsInstalled) StartStep.models,
  if (!selection.settings.captureRouted) StartStep.route,
  if (selection.requiresProcess && !gameChosen) StartStep.game,
];

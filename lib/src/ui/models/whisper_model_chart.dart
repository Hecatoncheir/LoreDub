// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../domain/model_package.dart';
import 'model_failure_row.dart';
import 'whisper_chart_layout.dart';
import 'whisper_chart_legend.dart';
import 'whisper_chart_plot.dart';

/// The Whisper builds drawn as a chart: each model is a bar whose height is
/// its download to scale and whose place along the bottom is how well it
/// hears speech, so the trade being made — disk and time for accuracy — is
/// the picture itself.
///
/// A bar also carries the model's state: light while it is not downloaded,
/// light with a tick once it is, dark with an orange edge when it is the one
/// in use, and filling up from the bottom while it downloads. Its buttons are
/// always there — download, pause or resume and cancel, or delete — so what
/// can be done with a model never waits for a hover to be found.
class WhisperModelChart extends StatelessWidget {
  const WhisperModelChart({
    super.key,
    required this.models,
    required this.selectedId,
    required this.running,
    required this.isStopping,
    required this.onInstall,
    required this.onPause,
    required this.onCancel,
    required this.onRemove,
    required this.onSelect,
  });

  /// Below this the bars cannot hold their names; the screen lists the
  /// models as cards instead.
  static const minimumWidth = 660.0;

  final List<ModelInstallState> models;
  final String? selectedId;

  /// Dubbing is on: the model in use can be neither swapped nor deleted.
  final bool running;

  /// A stop has been asked for and the download has not noticed yet.
  final bool Function(String id) isStopping;

  /// Starts a download, or resumes a paused one.
  final void Function(ModelInstallState state) onInstall;
  final void Function(ModelInstallState state) onPause;
  final void Function(ModelInstallState state) onCancel;

  /// Deletes a downloaded model; asked only once the reader has confirmed.
  final void Function(ModelInstallState state) onRemove;

  /// Null while dubbing runs.
  final void Function(ModelInstallState state)? onSelect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, constraints) => WhisperChartPlot(
          chart: this,
          layout: WhisperChartLayout.of(
            [for (final state in models) state.model.downloadBytes],
            constraints.maxWidth,
          ),
        ),
      ),
      const SizedBox(height: 14),
      const WhisperChartLegend(),
      for (final state in models)
        if (state.error != null) ...[
          const SizedBox(height: 10),
          ModelFailureRow(state: state),
        ],
    ],
  );
}

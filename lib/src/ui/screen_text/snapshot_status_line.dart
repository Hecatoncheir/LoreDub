// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../dashboard/cubits/pipeline_cubit.dart';
import '../theme.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/capture_sources.dart';
import '../dashboard/cubits/sources_bloc.dart';

/// What became of the last selection, or that live dubbing holds the key --
/// nothing at all when there is nothing to say.
class SnapshotStatusLine extends StatelessWidget {
  const SnapshotStatusLine({super.key, required this.pipeline, required this.settings});

  final LivePipelineState pipeline;
  final AppSettings settings;

  (IconData, String, Color)? _said(
    AppLocalizations l10n,
    LoreDubColors colors, {
    required bool gameChosen,
  }) => switch (pipeline) {
    _ when pipeline.snapshotReading => (
      Icons.hourglass_top_rounded,
      l10n.snapshotReading,
      colors.warning,
    ),
    _ when pipeline.snapshotMissed => (
      Icons.search_off_rounded,
      l10n.snapshotMissed,
      colors.warning,
    ),
    _ when pipeline.liveRunning => (
      Icons.info_outline_rounded,
      l10n.snapshotInLive,
      colors.mutedInk,
    ),
    _ when pipeline.frameMissed => (
      Icons.crop_free_rounded,
      l10n.frameMissed,
      colors.warning,
    ),
    // Reading the whole screen waits for no window, so there is no game to
    // ask for -- the picker above this line is shut for the same reason.
    _ when !gameChosen && !settings.readsWholeScreen => (
      Icons.videogame_asset_off_rounded,
      l10n.screenPickGame,
      colors.warning,
    ),
    _ => null,
  };

  @override
  Widget build(BuildContext context) => BlocSelector<SourcesBloc, CaptureSources, bool>(
    selector: (sources) => sources.selected != null,
    builder: (context, gameChosen) => _build(context, gameChosen: gameChosen),
  );

  Widget _build(BuildContext context, {required bool gameChosen}) {
    final said = _said(AppLocalizations.of(context), context.colors, gameChosen: gameChosen);
    if (said == null) return const SizedBox.shrink();
    final (icon, text, color) = said;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

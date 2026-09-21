// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/app_settings.dart';
import '../../domain/compute_device.dart';
import '../../domain/runtime_package.dart';
import '../compute_names.dart';
import '../dashboard/cubits/downloads_bloc.dart';
import '../dashboard/cubits/session_bloc.dart';
import '../failure_messages.dart';
import '../theme.dart';
import '../common/tile_grid.dart';
import 'runtime_tile.dart';

/// The GPU packages as tiles: the ones this machine could use, and any
/// already on disk -- a card that was taken out must not strand gigabytes
/// nobody can give back. Nothing is drawn when there is none.
class ComputeRuntimesSection extends StatelessWidget {
  const ComputeRuntimesSection({
    super.key,
    required this.stages,
    required this.downloads,
    required this.settings,
    required this.pipeline,
  });

  final List<ComputeStage> stages;
  final DownloadsState downloads;
  final AppSettings settings;
  final SessionState pipeline;

  /// Whether any stage could put runtime [id] to use on this machine.
  static bool _servesHardware(String id, ComputeAvailability availability) =>
      ComputeStage.values.any(
        (stage) => stageBackends(stage).any(
          (backend) =>
              requiredRuntimeId(stage, backend) == id && availability.supportsHardware(backend),
        ),
      );

  /// Whether a stage on the card runs on runtime [id] right now.
  bool _inUse(String id) => stages.any(
    (stage) =>
        requiredRuntimeId(stage, pipeline.backendFor(stage, settings, downloads.availability)) ==
        id,
  );

  List<RuntimeInstallState> get _shown => [
    for (final runtime in downloads.runtimes)
      if (runtime.installed ||
          runtime.stoppable ||
          _servesHardware(runtime.package.id, downloads.availability))
        runtime,
  ];

  @override
  Widget build(BuildContext context) {
    final runtimes = _shown;
    if (runtimes.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DownloadsBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(
          l10n.computeRuntimesTitle,
          style: TextStyle(
            fontFamily: LoreDubFonts.mono,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: context.colors.mutedInk,
          ),
        ),
        const SizedBox(height: 10),
        TileGrid(
          children: [
            for (final runtime in runtimes)
              RuntimeTile(
                key: ValueKey('runtimeTile-${runtime.package.id}'),
                state: runtime,
                inUse: _inUse(runtime.package.id),
                running: pipeline.running,
                stopping: downloads.isStopping(runtime.package.id),
                onInstall: () => cubit.add(RuntimeInstallAsked(runtime)),
                onPause: () => cubit.add(DownloadPaused(runtime.package.id)),
                onCancel: () => cubit.add(DownloadCancelled(runtime.package.id)),
                onRemove: () => cubit.add(RuntimeRemoved(runtime)),
              ),
          ],
        ),
        // A failed install puts the tile back as it was, so without the
        // reason spelled out the press looked like it had done nothing.
        for (final runtime in runtimes)
          if (runtime.error case final error?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SelectableText(
                '${runtimeName(l10n, runtime.package.id)}: ${describeFailure(l10n, error)}',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ),
      ],
    );
  }
}

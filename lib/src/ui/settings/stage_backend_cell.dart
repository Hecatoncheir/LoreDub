// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/compute_device.dart';
import '../compute_names.dart';
import 'backend_cell.dart';
import '../models/bloc/downloads_bloc.dart';
import 'bloc/settings_bloc.dart';
import 'stage_backend_status.dart';
import 'backend_cell_look.dart';

/// One cell of the stage-by-device table: [status] drawn as a
/// [BackendCell], with the press it allows.
class StageBackendCell extends StatelessWidget {
  const StageBackendCell({
    super.key,
    required this.stage,
    required this.backend,
    required this.status,
    required this.running,
  });

  final ComputeStage stage;
  final ComputeBackend backend;
  final StageBackendStatus status;

  /// A session runs: nothing is fetched or moved under it.
  final bool running;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final key = ValueKey('backendCell-${stage.name}-${backend.name}');
    final label = computeBackendName(l10n, backend);
    return switch (status) {
      StageBackendUnsupported() => BackendCell(
        key: key,
        label: label,
        state: BackendCellState.unsupported,
        tooltip: l10n.computeBackendUnsupported,
      ),
      StageBackendNoHardware() => BackendCell(
        key: key,
        label: label,
        state: BackendCellState.noHardware,
        tooltip: l10n.computeBackendNoHardware,
      ),
      StageBackendDownloading(:final runtime, :final progress) => BackendCell(
        key: key,
        label: label,
        state: BackendCellState.downloading,
        progress: progress,
        detail: runtime.paused ? l10n.downloadPaused : '${(progress * 100).round()}%',
        tooltip: l10n.computeRuntimeDownloading(
          formatPackageSize(l10n, runtime.package.approximateBytes),
        ),
      ),
      StageBackendNeedsRuntime(:final runtime) => BackendCell(
        key: key,
        label: label,
        state: BackendCellState.needsRuntime,
        detail: formatPackageSize(l10n, runtime.package.approximateBytes),
        tooltip:
            '${l10n.computeRuntimeMissing(formatPackageSize(l10n, runtime.package.approximateBytes))}'
            '\n${l10n.computeCellHintDownload}',
        onTap: running
            ? null
            : () => context.read<DownloadsBloc>().add(RuntimeInstallAsked(runtime)),
      ),
      StageBackendNotShipped() => BackendCell(
        key: key,
        label: label,
        state: BackendCellState.unsupported,
        tooltip: l10n.computeBackendNotShipped,
      ),
      StageBackendSelected() => BackendCell(
        key: key,
        label: label,
        state: BackendCellState.selected,
        tooltip: l10n.computeCellSelected,
      ),
      StageBackendReady() => BackendCell(
        key: key,
        label: label,
        state: BackendCellState.ready,
        tooltip: running ? l10n.computeCellLocked : l10n.computeCellSelect,
        onTap: running
            ? null
            : () => context.read<SettingsBloc>().add(StageBackendPinned(stage, backend)),
      ),
    };
  }
}

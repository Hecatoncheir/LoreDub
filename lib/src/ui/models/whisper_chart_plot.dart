// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/model_package.dart';
import '../compute_names.dart';
import '../model_names.dart';
import '../theme.dart';
import 'model_action.dart';
import 'model_removal.dart';
import 'whisper_axes_painter.dart';
import 'whisper_chart_layout.dart';
import 'whisper_model_bar.dart';
import 'whisper_model_chart.dart';

/// The chart itself: the axes, the size beside each bar and the quality under
/// it, and the bars where [layout] put them.
class WhisperChartPlot extends StatelessWidget {
  const WhisperChartPlot({super.key, required this.chart, required this.layout});

  final WhisperModelChart chart;
  final WhisperChartLayout layout;

  static const _axisTitle = TextStyle(
    fontFamily: LoreDubFonts.mono,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: LoreDubPalette.orangeDark,
  );
  static const _marking = TextStyle(
    fontFamily: LoreDubFonts.mono,
    fontSize: 12,
    color: LoreDubPalette.ink,
  );

  /// A press on a bar fetches a model that is not there and picks one that
  /// is; nothing while it downloads, is already chosen, or dubbing runs.
  VoidCallback? _tapFor(ModelInstallState state) {
    if (state.progress != null) return null;
    if (!state.installed) return () => chart.onInstall(state);
    final select = chart.onSelect;
    if (state.model.id == chart.selectedId || select == null) return null;
    return () => select(state);
  }

  List<ModelAction> _actionsFor(
    BuildContext context,
    AppLocalizations l10n,
    ModelInstallState state,
  ) => modelActions(
    l10n: l10n,
    parts: [state],
    isStopping: chart.isStopping,
    // The model a live session reads from cannot vanish under it.
    locked: chart.running && state.model.id == chart.selectedId,
    onInstall: chart.onInstall,
    onPause: chart.onPause,
    onCancel: chart.onCancel,
    onRemove: () => _remove(context, l10n, state),
  );

  Future<void> _remove(BuildContext context, AppLocalizations l10n, ModelInstallState state) async {
    final confirmed = await confirmModelRemoval(
      context,
      title: l10n.modelRemoveTitle,
      message: l10n.modelRemoveMessage(
        modelTitle(l10n, state.model),
        formatPackageSize(l10n, state.model.downloadBytes),
      ),
    );
    if (confirmed) chart.onRemove(state);
  }

  /// The last line of a bar's tooltip: how far a download has got, or what
  /// a press does.
  String _hint(AppLocalizations l10n, ModelInstallState state) {
    final model = state.model;
    if (state.progress case final progress?) {
      return l10n.whisperDownloadProgress(
        (progress * 100).round(),
        formatPackageSize(l10n, (model.downloadBytes * progress).round()),
        formatPackageSize(l10n, model.downloadBytes),
      );
    }
    if (!state.installed) {
      return l10n.whisperHintDownload(formatPackageSize(l10n, model.downloadBytes));
    }
    if (model.id == chart.selectedId) return l10n.whisperHintSelected;
    return chart.onSelect == null ? l10n.whisperHintLocked : l10n.whisperHintSelect;
  }

  String _tooltip(AppLocalizations l10n, ModelInstallState state) => [
    modelTitle(l10n, state.model),
    modelDescription(l10n, state.model),
    _hint(l10n, state),
  ].join('\n');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const left = WhisperChartLayout.labelGutter;
    const baseline = WhisperChartLayout.baseline;
    final models = chart.models;
    return SizedBox(
      height: WhisperChartLayout.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: WhisperAxesPainter(
                left: left,
                top: WhisperChartLayout.titleBand - 12,
                baseline: baseline,
                right: layout.width - 8,
                bars: layout.bars,
              ),
            ),
          ),
          Positioned(
            left: 0,
            width: left - 10,
            top: 0,
            child: Text(l10n.whisperAxisSize, textAlign: TextAlign.right, style: _axisTitle),
          ),
          const Positioned(
            left: 0,
            width: left - 10,
            top: baseline + 4,
            child: Text('0', textAlign: TextAlign.right, style: _marking),
          ),
          Positioned(
            right: 0,
            width: WhisperChartLayout.axisTitleWidth - 8,
            top: baseline + 10,
            child: Text(l10n.whisperAxisQuality, textAlign: TextAlign.right, style: _axisTitle),
          ),
          for (final (index, state) in models.indexed) ...[
            Positioned(
              left: 0,
              width: left - 10,
              top: layout.labelCentres[index] - 8,
              child: Text(
                formatPackageSize(l10n, state.model.downloadBytes),
                textAlign: TextAlign.right,
                style: _marking,
              ),
            ),
            Positioned(
              left: layout.bars[index].left,
              width: layout.bars[index].width,
              top: baseline + 10,
              child: Text(
                recognitionQualityName(l10n, state.model.quality) ?? '',
                textAlign: TextAlign.center,
                style: _marking,
              ),
            ),
            Positioned.fromRect(
              rect: layout.bars[index],
              child: WhisperModelBar(
                key: ValueKey('whisperBar-${state.model.id}'),
                state: state,
                selected: state.model.id == chart.selectedId,
                tooltip: _tooltip(l10n, state),
                onTap: _tapFor(state),
                actions: _actionsFor(context, l10n, state),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

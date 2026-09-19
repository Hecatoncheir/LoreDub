// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../theme.dart';
import 'whisper_chart_layout.dart';
import 'whisper_legend_item.dart';
import 'whisper_legend_swatch.dart';

/// What the four looks of a bar mean. Light, ticked, dark and filling are not
/// self-evident, and a player should not have to learn them by trying.
class WhisperChartLegend extends StatelessWidget {
  const WhisperChartLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: WhisperChartLayout.labelGutter),
      child: Wrap(
        spacing: 20,
        runSpacing: 8,
        children: [
          WhisperLegendItem(
            label: l10n.whisperLegendMissing,
            mark: const WhisperLegendSwatch(
              fill: LoreDubPalette.orange,
              edge: LoreDubPalette.outline,
              icon: Icons.cloud_download_outlined,
            ),
          ),
          WhisperLegendItem(
            label: l10n.whisperLegendInstalled,
            mark: const WhisperLegendSwatch(
              fill: LoreDubPalette.ink,
              edge: LoreDubPalette.outline,
              icon: Icons.cloud_done_outlined,
            ),
          ),
          WhisperLegendItem(
            label: l10n.whisperLegendSelected,
            mark: const WhisperLegendSwatch(
              fill: LoreDubPalette.graphite,
              edge: LoreDubPalette.orange,
            ),
          ),
          WhisperLegendItem(
            label: l10n.whisperLegendDownloading,
            mark: const WhisperLegendSwatch(
              fill: LoreDubPalette.graphite,
              edge: LoreDubPalette.orange,
              filled: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

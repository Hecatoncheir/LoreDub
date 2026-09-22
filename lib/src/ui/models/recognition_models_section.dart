// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/model_package.dart';
import '../../domain/model_selection.dart';
import '../common/module_label.dart';
import '../common/section_note.dart';
import 'bloc/downloads_bloc.dart';
import '../settings/bloc/settings_bloc.dart';
import 'whisper_model_chart.dart';
import 'recognition_model_cards.dart';

/// The Whisper builds. Size against quality is the whole choice, so it is
/// drawn as a chart; a window too narrow for the bars gets plain cards.
class RecognitionModelsSection extends StatelessWidget {
  const RecognitionModelsSection({
    super.key,
    required this.selection,
    required this.downloads,
    required this.running,
  });

  final ModelSelection selection;
  final DownloadsState downloads;

  /// A session runs, and the build it recognizes with cannot be swapped.
  final bool running;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DownloadsBloc>();
    final settings = context.read<SettingsBloc>();
    final onSelect = running
        ? null
        : (ModelInstallState state) => settings.add(RecognitionModelChosen(state.model.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModuleLabel(number: '01', label: l10n.sectionRecognition),
        const SizedBox(height: 4),
        SectionNote(l10n.sectionRecognitionNote),
        if (selection.recognitionNeedsEnglish) ...[
          const SizedBox(height: 8),
          SectionNote(l10n.recognitionNeedsEnglish),
        ],
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < WhisperModelChart.minimumWidth
              ? RecognitionModelCards(selection: selection, downloads: downloads, running: running)
              : Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: WhisperModelChart(
                    models: selection.recognitionModels,
                    selectedId: selection.recognition?.model.id,
                    running: running,
                    isStopping: downloads.isStopping,
                    onInstall: (state) => cubit.add(ModelInstallAsked(state)),
                    onPause: (state) => cubit.add(DownloadPaused(state.model.id)),
                    onCancel: (state) => cubit.add(DownloadCancelled(state.model.id)),
                    onRemove: (state) => cubit.add(ModelRemoved(state)),
                    onSelect: onSelect,
                  ),
                ),
        ),
      ],
    );
  }
}

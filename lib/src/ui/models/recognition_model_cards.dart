// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/model_selection.dart';
import '../dashboard/cubits/downloads_bloc.dart';
import '../dashboard/cubits/settings_bloc.dart';
import 'model_card.dart';

/// The Whisper builds one card under another, for a window too narrow for
/// their chart; the card of the build in use is marked.
class RecognitionModelCards extends StatelessWidget {
  const RecognitionModelCards({
    super.key,
    required this.selection,
    required this.downloads,
    required this.running,
  });

  final ModelSelection selection;
  final DownloadsState downloads;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DownloadsBloc>();
    final settings = context.read<SettingsBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final state in selection.recognitionModels) ...[
          const SizedBox(height: 12),
          ModelCard(
            state: state,
            onInstall: () => cubit.add(ModelInstallAsked(state)),
            onPause: () => cubit.add(DownloadPaused(state.model.id)),
            onCancel: () => cubit.add(DownloadCancelled(state.model.id)),
            stopping: downloads.isStopping(state.model.id),
            choosable: true,
            selected: state.model.id == selection.recognition?.model.id,
            onSelect: running ? null : () => settings.add(RecognitionModelChosen(state.model.id)),
          ),
        ],
      ],
    );
  }
}

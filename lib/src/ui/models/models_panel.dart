// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../dashboard/cubits/downloads_cubit.dart';
import '../dashboard/cubits/pipeline_cubit.dart';
import '../dashboard/cubits/settings_cubit.dart';
import '../dashboard/dashboard_context.dart';
import 'language_pairs_section.dart';
import 'recognition_models_section.dart';
import 'voice_converters_section.dart';

/// The Модели screen: the recognition builds, the languages a line can be
/// dubbed into, and the converter that carries a voice over.
///
/// It listens to the downloads whole -- a progress bar is what it draws --
/// and to the settings, which say what is chosen. Nothing can be swapped
/// while a session runs, so it listens to whether one does.
class ModelsPanel extends StatelessWidget {
  const ModelsPanel({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<DownloadsCubit, DownloadsState>(
    builder: (context, downloads) => BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, _) => BlocSelector<PipelineCubit, LivePipelineState, bool>(
        selector: (pipeline) => pipeline.running,
        builder: (context, running) => ListView(
          key: const ValueKey('modelsList'),
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
          children: [
            RecognitionModelsSection(
              selection: context.selection,
              downloads: downloads,
              running: running,
            ),
            const SizedBox(height: 26),
            LanguagePairsSection(
              selection: context.selection,
              downloads: downloads,
              running: running,
            ),
            const SizedBox(height: 26),
            VoiceConvertersSection(
              selection: context.selection,
              downloads: downloads,
              running: running,
            ),
          ],
        ),
      ),
    ),
  );
}

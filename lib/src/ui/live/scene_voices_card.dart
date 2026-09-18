// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../dashboard/cubits/pipeline_cubit.dart';
import '../dashboard/dashboard_context.dart';
import '../common/module_label.dart';
import 'scene_listen_button.dart';
import 'scene_voices_empty.dart';
import 'scene_voices_list.dart';

/// Who the session has heard, and whose voice reads them.
///
/// A voice of the game and a card recognized in it are both here. The area
/// shows and does not set: who reads whom is drawn on the graph.
class SceneVoicesCard extends StatelessWidget {
  const SceneVoicesCard({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<PipelineCubit, LivePipelineState>(
    buildWhen: whenChanged((pipeline) => (pipeline.speakers, pipeline.sceneRunning)),
    builder: (context, pipeline) => Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 9, 12, 8),
            child: ModuleLabel(
              number: '03',
              label: AppLocalizations.of(context).areaSceneVoices,
            ),
          ),
          const Divider(height: 1),
          // On its own line rather than beside the label: this column is
          // narrow, and the two would not fit across it.
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(alignment: Alignment.centerLeft, child: SceneListenButton()),
          ),
          Expanded(
            child: pipeline.speakers.isEmpty
                ? SceneVoicesEmpty(listening: pipeline.sceneRunning)
                : SceneVoicesList(speakers: pipeline.speakers),
          ),
        ],
      ),
    ),
  );
}

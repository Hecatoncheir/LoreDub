// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/model_selection.dart';
import '../common/module_label.dart';
import '../common/section_note.dart';
import '../dashboard/cubits/downloads_cubit.dart';
import '../dashboard/model_tiles.dart';
import '../dashboard/model_visuals.dart';

/// The converter that carries the timbre of the game's voice over to the
/// dubbing, marked in use while the original voice is kept.
class VoiceConvertersSection extends StatelessWidget {
  const VoiceConvertersSection({
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
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DownloadsCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModuleLabel(number: '03', label: l10n.sectionVoiceConversion),
        const SizedBox(height: 4),
        SectionNote(l10n.sectionVoiceConversionNote),
        const SizedBox(height: 12),
        ModelTileGrid(
          children: [
            for (final state in selection.voiceConverters)
              ConverterTile(
                key: ValueKey('converterTile-${state.model.id}'),
                state: state,
                inUse: selection.clonesVoice,
                running: running,
                isStopping: downloads.isStopping,
                onInstall: cubit.installModel,
                onPause: (state) => cubit.pauseDownload(state.model.id),
                onCancel: (state) => cubit.cancelDownload(state.model.id),
                onRemove: cubit.removeModel,
              ),
          ],
        ),
        for (final state in selection.voiceConverters)
          if (state.error != null) ...[
            const SizedBox(height: 10),
            ModelFailureRow(state: state),
          ],
      ],
    );
  }
}

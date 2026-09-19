// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/model_package.dart';
import '../common/hover_grow.dart';
import '../model_names.dart';
import '../theme.dart';
import 'model_action.dart';
import 'download_fill.dart';
import 'model_action_band.dart';
import 'model_tile_look.dart';
import 'whisper_bar_content.dart';

/// One model of the chart, in the tiles' vocabulary. It grows a little under
/// the pointer, from the axis up, so the bar about to be clicked stands out
/// without the chart shifting around it.
class WhisperModelBar extends StatelessWidget {
  const WhisperModelBar({
    super.key,
    required this.state,
    required this.selected,
    required this.tooltip,
    required this.onTap,
    required this.actions,
  });

  final ModelInstallState state;
  final bool selected;
  final String tooltip;
  final VoidCallback? onTap;
  final List<ModelAction> actions;

  static const _actionBand = 40.0;

  bool get _inUse => selected && state.installed && state.progress == null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return HoverGrow(
      builder: (context, hovered) {
        final look = ModelTileLook.of(
          downloading: state.progress != null,
          inUse: _inUse,
          marked: selected,
          hovered: hovered,
        );
        return Semantics(
          button: onTap != null,
          selected: selected,
          label: modelTitle(l10n, state.model),
          child: Material(
            color: look.face,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              side: BorderSide(color: look.edge, width: look.edgeWidth),
            ),
            child: InkWell(
              onTap: onTap,
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  fit: StackFit.expand,
                  children: [
                    if (state.progress case final progress?) DownloadFill(progress: progress),
                    Column(
                      children: [
                        // Turbo only suits an English original, and that
                        // should not wait for a tooltip to be found.
                        if (!state.model.translatesSpeech)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                            child: Text(
                              l10n.whisperNoTranslation,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: LoreDubFonts.mono,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _inUse ? LoreDubPalette.orange : LoreDubPalette.orangeDark,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Tooltip(
                            message: tooltip,
                            waitDuration: const Duration(milliseconds: 400),
                            child: SizedBox.expand(
                              child: Center(
                                child: WhisperBarContent(state: state, inUse: _inUse),
                              ),
                            ),
                          ),
                        ),
                        ModelActionBand(
                          actions: actions,
                          height: _actionBand,
                          onDark: ModelActionBand.darkAt(
                            inUse: _inUse,
                            progress: state.progress,
                            height: constraints.maxHeight,
                            band: _actionBand,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

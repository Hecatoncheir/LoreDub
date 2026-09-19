// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../common/ease.dart';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/model_package.dart';
import '../common/hover_grow.dart';
import '../model_names.dart';
import '../theme.dart';
import 'model_action.dart';
import 'model_action_button.dart';
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

  /// The buttons sit at the foot of the bar, where the fill of a download
  /// arrives first; they switch to light once it is dark.
  bool _darkFoot(double height) {
    final progress = state.progress;
    return _inUse || (progress != null && progress * height >= _actionBand);
  }

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
                    if (state.progress case final progress?)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: AnimatedFractionallySizedBox(
                          duration: ease(context, 300),
                          heightFactor: progress.clamp(0.0, 1.0),
                          widthFactor: 1,
                          child: const ColoredBox(color: LoreDubPalette.graphite),
                        ),
                      ),
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
                        SizedBox(
                          height: _actionBand,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final action in actions)
                                ModelActionButton(
                                  action: action,
                                  onDark: _darkFoot(constraints.maxHeight),
                                ),
                            ],
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

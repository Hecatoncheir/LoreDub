// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/model_package.dart';
import '../model_names.dart';
import '../theme.dart';
import 'model_progress_dial.dart';
import 'whisper_bar_mark.dart';

/// What a Whisper bar shows in its middle: the cloud and the build's name,
/// or the dial of its download over the name.
///
/// A narrow bar has room for the ring or for words, not both: the ring and
/// its figure win, the pause shows as a dimmed arc and the play button, and
/// the name returns once the download is done.
class WhisperBarContent extends StatelessWidget {
  const WhisperBarContent({super.key, required this.state, required this.inUse});

  final ModelInstallState state;
  final bool inUse;

  /// Narrower than this the bar holds the dial alone.
  static const _roomyWidth = 150.0;

  Color _nameInk(LoreDubColors colors) {
    if (state.progress != null) return colors.accent;
    return inUse ? colors.raised : colors.ink;
  }

  static double _dialSize(BoxConstraints room, {required double heightShare}) =>
      math.min(116.0, math.min(room.maxWidth * 0.62, room.maxHeight * heightShare));

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, room) {
      final roomy = room.maxWidth >= _roomyWidth;
      final progress = state.progress;
      if (progress != null && !roomy) {
        return Center(
          child: ModelProgressDial(
            key: ValueKey('whisperDial-${state.model.id}'),
            progress: progress,
            paused: state.paused,
            size: _dialSize(room, heightShare: 0.92),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              WhisperBarMark(
                state: state,
                inUse: inUse,
                roomy: roomy,
                dialSize: _dialSize(room, heightShare: 0.62),
              ),
              const SizedBox(height: 8),
              Text(
                whisperShortName(state.model),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: LoreDubFonts.mono,
                  fontSize: roomy ? 20 : 15,
                  fontWeight: FontWeight.w500,
                  color: _nameInk(context.colors),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

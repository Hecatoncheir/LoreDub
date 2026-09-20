// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../theme.dart';
import 'model_action.dart';

/// A model's button: small enough for the narrowest Whisper bar, and light
/// once the dark fill of a download or of the model in use is behind it.
class ModelActionButton extends StatelessWidget {
  const ModelActionButton({super.key, required this.action, required this.onDark});

  final ModelAction action;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final colour = onDark ? context.colors.raised : context.colors.ink;
    return IconButton(
      tooltip: action.tooltip,
      onPressed: action.onPressed,
      icon: Icon(action.icon, size: 19),
      style: IconButton.styleFrom(
        foregroundColor: colour,
        disabledForegroundColor: colour.withValues(alpha: 0.35),
        hoverColor: context.colors.accent.withValues(alpha: 0.18),
        minimumSize: const Size.square(LoreDubTargets.dense),
        fixedSize: const Size.square(LoreDubTargets.dense),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

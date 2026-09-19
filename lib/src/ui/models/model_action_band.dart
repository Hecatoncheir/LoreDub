// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import 'model_action.dart';
import 'model_action_button.dart';

/// The buttons along the foot of a model tile or bar, which the fill of a
/// download reaches first: they are drawn light once it has risen past
/// them, or once the model is in use.
class ModelActionBand extends StatelessWidget {
  const ModelActionBand({
    super.key,
    required this.actions,
    required this.height,
    required this.onDark,
  });

  final List<ModelAction> actions;
  final double height;
  final bool onDark;

  /// Whether a band of [band] pixels at the foot of something [height]
  /// tall stands on the dark: in use, or with the fill risen past it.
  static bool darkAt({
    required bool inUse,
    required double? progress,
    required double height,
    required double band,
  }) => inUse || (progress != null && progress * height >= band);

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final action in actions) ModelActionButton(action: action, onDark: onDark),
      ],
    ),
  );
}

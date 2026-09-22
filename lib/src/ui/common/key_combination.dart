// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import 'key_cap.dart';

/// Keys held together -- Ctrl + Alt + S -- each drawn as a key, with the plus
/// between them said in the text around them. Never broken over two lines:
/// half a combination at the end of one line is not a combination.
class KeyCombination extends StatelessWidget {
  const KeyCombination({super.key, required this.keys, this.style});

  final List<String> keys;

  /// The text the combination stands in, which the plus is said in and the
  /// keys are sized by. The one around it when not given.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final around = DefaultTextStyle.of(context).style.merge(style);
    final size = around.fontSize ?? 14;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, key) in keys.indexed) ...[
          if (index > 0)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.2),
              child: Text('+', style: around),
            ),
          KeyCap(key, fontSize: size),
        ],
      ],
    );
  }
}

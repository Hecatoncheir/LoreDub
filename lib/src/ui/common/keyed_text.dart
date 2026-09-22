// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import 'key_combination.dart';
import 'key_marks.dart';

/// An interface string with the keys in it drawn as keys: whatever it marks
/// `<kbd>...</kbd>` stands out of the sentence as the key it names, so a
/// combination is found in a note at a glance rather than read out of it.
///
/// Every string that names a key the player presses is drawn through this,
/// or the marks would be read out as they are written.
class KeyedText extends StatelessWidget {
  const KeyedText(this.text, {super.key, this.style, this.maxLines, this.overflow});

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final around = DefaultTextStyle.of(context).style.merge(style);
    return Text.rich(
      TextSpan(
        children: [
          for (final run in keyedRuns(text))
            if (run.keys.isEmpty)
              TextSpan(text: run.words)
            else
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  // A hair off the words on either side, which the frame
                  // would otherwise touch.
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: KeyCombination(keys: run.keys, style: around),
                ),
              ),
        ],
      ),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

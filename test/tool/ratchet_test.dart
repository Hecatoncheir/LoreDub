// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/ratchet.dart';

void main() {
  test('counts linter issues per rule', () {
    final report = jsonEncode({
      'records': [
        {
          'issues': [
            {'ruleId': 'avoid-returning-widgets'},
            {'ruleId': 'prefer-single-widget-per-file'},
          ],
        },
        {
          'issues': [
            {'ruleId': 'avoid-returning-widgets'},
          ],
        },
        <String, Object?>{},
      ],
    });

    expect(countRuleIssues(report), {
      'avoid-returning-widgets': 2,
      'prefer-single-widget-per-file': 1,
    });
  });

  test('counts hand-written styles outside the theme and generated code', () {
    final counts = countHandWrittenStyles({
      'lib/src/ui/live/panel.dart':
          'Text(style: TextStyle(color: LoreDubPalette.ink, backgroundColor: Color(0x22171717)))',
      r'lib\src\ui\theme.dart': 'LoreDubPalette.ink; TextStyle(); Color(0xFF000000)',
      'lib/src/ui/theme/tokens/colors.dart': 'Color(0xFF000000)',
      'lib/src/native/bindings.g.dart': 'TextStyle(',
    });

    expect(counts, {'LoreDubPalette.': 1, 'Color(0x': 1, 'TextStyle(': 1});
  });

  test('fails only on a count above the baseline', () {
    final verdicts = compareToBaseline({'a': 3, 'b': 1, 'c': 5, 'd': 7}, {'a': 3, 'b': 2, 'c': 4});

    expect([for (final verdict in verdicts) verdict.grew], [false, false, true, false]);
    expect([for (final verdict in verdicts) verdict.shrank], [false, true, false, false]);
    expect(verdicts.last.describe(), contains('(new)'));
  });
}

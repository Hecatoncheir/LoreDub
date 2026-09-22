// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';

import '../../tool/coverage.dart';

void main() {
  const lcov = '''
SF:lib/src/data/services/a.dart
DA:1,3
DA:2,0
DA:3,1
end_of_record
SF:C:\\work\\lib\\src\\data\\repositories\\b.dart
DA:1,0
DA:2,2
end_of_record
SF:lib/src/native/lore_dub_native.g.dart
DA:1,0
DA:2,0
end_of_record
SF:lib/l10n/app_localizations.dart
DA:1,0
end_of_record
SF:lib/src/ui/c.dart
DA:1,1
end_of_record
''';

  test('counts the lines each area ran, of all it has', () {
    final shares = coverageByArea(lcov, [
      'lib/src/data/services/',
      'lib/src/data/repositories/',
      'lib/src/data/',
      'lib/',
    ]);

    expect(shares['lib/src/data/services/']!.hit, 2);
    expect(shares['lib/src/data/services/']!.lines, 3);
    expect(shares['lib/src/data/repositories/']!.lines, 2, reason: 'an absolute Windows path');
    expect(shares['lib/src/data/']!.lines, 5, reason: 'an area holds the ones inside it');
    expect(shares['lib/']!.lines, 6, reason: 'the bindings and the wording are passed over');
  });

  test('rounds a share to one decimal, as the baseline holds it', () {
    expect(const AreaCoverage(2, 3).percent, 66.7);
    expect(const AreaCoverage(0, 0).percent, 0);
  });

  test('fails an area that fell and lets one through that rose', () {
    const fell = CoverageVerdict('lib/src/data/', AreaCoverage(70, 100), 71.0);
    const rose = CoverageVerdict('lib/src/data/', AreaCoverage(72, 100), 71.0);
    const reported = CoverageVerdict('lib/', AreaCoverage(10, 100), null);

    expect(fell.fell, isTrue);
    expect(rose.fell, isFalse);
    expect(rose.rose, isTrue);
    expect(reported.fell, isFalse, reason: 'an area only reported holds nothing back');
  });
}

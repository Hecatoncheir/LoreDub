// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';

import '../../tool/prepare_release.dart';

void main() {
  test('extracts only the requested changelog section', () {
    const changelog = '''
# Changelog

## [0.2.0] - 2026-09-10

- New release.

## [0.1.0] - 2026-09-09

- Initial release.
''';

    expect(extractReleaseNotes(changelog, '0.2.0'), '- New release.');
  });

  test('rejects a missing changelog version', () {
    expect(
      () => extractReleaseNotes('# Changelog', '0.2.0'),
      throwsA(isA<FormatException>()),
    );
  });
}

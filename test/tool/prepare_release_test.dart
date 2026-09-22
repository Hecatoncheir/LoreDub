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

  test('closes the notes with the setup and its SHA-256', () {
    expect(
      withInstallerDigest('- New release.', 'LoreDub-0.2.0-windows-x64-setup.exe', 'ab12'),
      '- New release.\n\n---\n\nSHA-256 `LoreDub-0.2.0-windows-x64-setup.exe`: `ab12`',
    );
  });

  test('rejects a missing changelog version', () {
    expect(
      () => extractReleaseNotes('# Changelog', '0.2.0'),
      throwsA(isA<FormatException>()),
    );
  });
}

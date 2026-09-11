// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lore_dub/src/data/services/update_service.dart';
import 'package:lore_dub/src/domain/failure.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  UpdateService serviceReturning(http.Response response, {String version = '0.2.1'}) =>
      UpdateService(
        client: MockClient((_) async => response),
        packageInfo: Future.value(
          PackageInfo(
            appName: 'LoreDub',
            packageName: 'lore_dub',
            version: version,
            buildNumber: '3',
          ),
        ),
      );

  http.Response releaseBody(String tag) => http.Response(
    jsonEncode({
      'tag_name': tag,
      'html_url': 'https://github.com/Hecatoncheir/LoreDub/releases/tag/$tag',
    }),
    200,
  );

  group('reading a tag as a version', () {
    test('accepts the v the tags are written with', () {
      expect(parseReleaseVersion('v0.3.0')?.toString(), '0.3.0');
      expect(parseReleaseVersion('0.3.0')?.toString(), '0.3.0');
      expect(parseReleaseVersion('  v1.2.3 ')?.toString(), '1.2.3');
    });

    test('says nothing about a tag it cannot read', () {
      // A tag someone typed by hand is a reason to stay quiet, not to fail.
      expect(parseReleaseVersion('nightly'), isNull);
      expect(parseReleaseVersion(''), isNull);
    });
  });

  group('deciding whether a release is newer', () {
    test('compares the three numbers', () {
      expect(isNewerRelease('v0.3.0', '0.2.1'), isTrue);
      expect(isNewerRelease('v0.2.2', '0.2.1'), isTrue);
      expect(isNewerRelease('v1.0.0', '0.9.9'), isTrue);
      expect(isNewerRelease('v0.2.1', '0.2.1'), isFalse);
      expect(isNewerRelease('v0.2.0', '0.2.1'), isFalse);
    });

    test('ignores the build number after the plus', () {
      // 0.2.1+3 and 0.2.1+4 are the same release to anyone reading a
      // changelog, so a rebuild must not look like an update.
      expect(isNewerRelease('v0.2.1', '0.2.1+3'), isFalse);
      expect(isNewerRelease('v0.2.1+9', '0.2.1+3'), isFalse);
    });

    test('stays quiet when either side is unreadable', () {
      expect(isNewerRelease('nightly', '0.2.1'), isFalse);
      expect(isNewerRelease('v0.3.0', 'unknown'), isFalse);
    });
  });

  test('reads the newest release the repository names', () async {
    final release = await serviceReturning(releaseBody('v0.4.0')).latestRelease();

    expect(release?.version, '0.4.0');
    expect(release?.page.toString(), endsWith('/releases/tag/v0.4.0'));
  });

  test('treats a repository with no releases as nothing to report', () async {
    final release = await serviceReturning(http.Response('Not Found', 404)).latestRelease();

    expect(release, isNull);
  });

  test('reports a refusal rather than claiming the build is current', () async {
    // A rate limit is not the same answer as "you are up to date".
    await expectLater(
      serviceReturning(http.Response('rate limited', 403)).latestRelease(),
      throwsA(
        isA<LoreDubFailure>()
            .having((error) => error.code, 'code', FailureCode.updateCheckFailed)
            .having((error) => error.detail, 'detail', '403'),
      ),
    );
  });

  test('ignores a release tagged with something that is not a version', () async {
    final release = await serviceReturning(releaseBody('nightly')).latestRelease();

    expect(release, isNull);
  });

  test('falls back to the releases page when the entry names none', () async {
    final service = serviceReturning(
      http.Response(jsonEncode({'tag_name': 'v0.5.0'}), 200),
    );

    expect((await service.latestRelease())?.page.toString(), endsWith('/releases'));
  });

  test('finds the setup among the files of a release', () async {
    final service = serviceReturning(
      http.Response(
        jsonEncode({
          'tag_name': 'v0.9.0',
          'assets': [
            {'name': 'notes.txt', 'browser_download_url': 'https://example.com/notes', 'size': 4},
            {
              'name': 'LoreDub-0.9.0-windows-x64-setup.exe',
              'browser_download_url':
                  'https://github.com/Hecatoncheir/LoreDub/releases/download/v0.9.0/'
                  'LoreDub-0.9.0-windows-x64-setup.exe',
              'size': 181234513,
              'digest': 'sha256:0123abcd',
            },
          ],
        }),
        200,
      ),
    );

    final installer = (await service.latestRelease())?.installer;

    expect(installer?.name, 'LoreDub-0.9.0-windows-x64-setup.exe');
    expect(installer?.size, 181234513);
    expect(installer?.sha256, '0123abcd');
    expect(installer?.url.path, endsWith('/v0.9.0/LoreDub-0.9.0-windows-x64-setup.exe'));
  });

  test('leaves a release without a setup to its page', () async {
    final release = await serviceReturning(releaseBody('v0.9.0')).latestRelease();

    expect(release?.installer, isNull);
  });

  test('reports the version this build carries', () async {
    expect(
      await serviceReturning(releaseBody('v0.4.0'), version: '0.2.1').currentVersion(),
      '0.2.1',
    );
  });
}

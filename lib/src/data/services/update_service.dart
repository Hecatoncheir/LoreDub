// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';

import '../../domain/app_release.dart';
import '../../domain/failure.dart';
import 'artifact_downloader.dart';

/// Where releases are published. The check is read-only and unauthenticated.
final releasesEndpoint = Uri.parse(
  'https://api.github.com/repos/Hecatoncheir/LoreDub/releases/latest',
);

/// Reads a release tag as a version, tolerating the `v` the tags carry.
///
/// Returns null rather than throwing: a tag someone typed by hand is a reason
/// to say nothing about updates, not to fail the application.
Version? parseReleaseVersion(String tag) {
  final trimmed = tag.trim();
  final withoutPrefix = trimmed.startsWith('v') ? trimmed.substring(1) : trimmed;
  try {
    return Version.parse(withoutPrefix);
  } on FormatException {
    return null;
  }
}

/// Whether [candidate] is worth telling the user about.
///
/// The build number after `+` is ignored: `0.2.1+3` and `0.2.1+4` are the
/// same release as far as anyone reading a changelog is concerned.
bool isNewerRelease(String candidate, String current) {
  final released = parseReleaseVersion(candidate);
  final running = parseReleaseVersion(current);
  if (released == null || running == null) return false;
  return Version(released.major, released.minor, released.patch) >
      Version(running.major, running.minor, running.patch);
}

/// Asks the repository whether a newer version has been published.
class UpdateService {
  UpdateService({this._client, Future<PackageInfo>? packageInfo})
    :
      _packageInfo = packageInfo ?? PackageInfo.fromPlatform();

  final http.Client? _client;
  final Future<PackageInfo> _packageInfo;

  /// The version this build reports for itself.
  Future<String> currentVersion() async => (await _packageInfo).version;

  /// The newest published release, or null when the repository has none.
  Future<AppRelease?> latestRelease({String proxyUrl = ''}) async {
    final client = _client ?? await createDownloadClient(proxyUrl);
    try {
      final response = await client
          .get(
            releasesEndpoint,
            headers: const {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
            },
          )
          .timeout(const Duration(seconds: 15));
      // A repository with no releases answers 404, which is an answer rather
      // than a failure: there is simply nothing newer to point at.
      if (response.statusCode == HttpStatus.notFound) return null;
      if (response.statusCode != HttpStatus.ok) {
        throw LoreDubFailure(
          FailureCode.updateCheckFailed,
          detail: '${response.statusCode}',
        );
      }
      final body = jsonDecode(response.body) as Map<String, Object?>;
      final tag = body['tag_name'] as String?;
      if (tag == null || parseReleaseVersion(tag) == null) return null;
      final page = body['html_url'] as String?;
      return AppRelease(
        version: tag.startsWith('v') ? tag.substring(1) : tag,
        page: Uri.parse(page ?? 'https://github.com/Hecatoncheir/LoreDub/releases'),
      );
    } finally {
      if (_client == null) client.close();
    }
  }
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../domain/app_release.dart';
import '../../domain/failure.dart';
import 'artifact_downloader.dart';

/// Where releases are published. The check is read-only and unauthenticated.
final releasesEndpoint = Uri.parse(
  'https://api.github.com/repos/Hecatoncheir/LoreDub/releases/latest',
);

/// Asks the repository whether a newer version has been published.
class UpdateService {
  UpdateService({this._client, Future<PackageInfo>? packageInfo})
    : _packageInfo = packageInfo ?? PackageInfo.fromPlatform();

  final http.Client? _client;
  final Future<PackageInfo> _packageInfo;

  /// The version this build reports for itself.
  Future<String> currentVersion() async => (await _packageInfo).version;

  /// The newest published release, or null when the repository has none.
  Future<AppRelease?> latestRelease({String proxyUrl = ''}) =>
      withDownloadClient(_client, proxyUrl, _latestRelease);

  Future<AppRelease?> _latestRelease(http.Client client) async {
    final response = await client
        .get(
          releasesEndpoint,
          headers: const {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        )
        .timeout(
          const Duration(seconds: 15),
          // Left to itself a `TimeoutException` reached the banner and
          // was printed as it came, which says nothing to a player.
          onTimeout: () => throw const LoreDubFailure(
            FailureCode.updateCheckFailed,
            detail: 'no answer in 15 s',
          ),
        );
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
      installer: releaseInstallerFrom(body['assets']),
    );
  }
}

/// The Windows setup among a release's files, named the way the release
/// workflow names it, or null when the release has none.
ReleaseInstaller? releaseInstallerFrom(Object? assets) {
  if (assets is! List<Object?>) return null;
  for (final asset in assets) {
    if (asset
        case {
          'name': final String name,
          'browser_download_url': final String url,
          'size': final int size,
        }
        when name.endsWith('-windows-x64-setup.exe')) {
      final digest = asset['digest'];
      return ReleaseInstaller(
        name: name,
        url: Uri.parse(url),
        size: size,
        sha256: digest is String && digest.startsWith('sha256:') ? digest.substring(7) : null,
      );
    }
  }
  return null;
}

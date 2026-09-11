// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import '../../domain/app_release.dart';
import '../../domain/failure.dart';
import '../services/artifact_downloader.dart';
import '../services/notification_service.dart';
import '../services/update_installer.dart';
import '../services/update_service.dart';

class UpdateRepository {
  UpdateRepository(this._updates, this._notifications, [UpdateInstaller? installer])
    : _installer = installer ?? UpdateInstaller();

  final UpdateService _updates;
  final NotificationService _notifications;
  final UpdateInstaller _installer;

  Future<String> currentVersion() => _updates.currentVersion();

  Future<AppRelease?> latestRelease({String proxyUrl = ''}) =>
      _updates.latestRelease(proxyUrl: proxyUrl);

  Future<void> announce({required String title, required String body}) =>
      _notifications.show(title: title, body: body);

  /// Whether this copy can be replaced by a newer setup.
  bool get canInstall => _installer.canInstall;

  /// Downloads a newer setup and returns where it landed.
  Future<String> downloadInstaller(
    ReleaseInstaller installer, {
    required DownloadProgress onProgress,
    String proxyUrl = '',
  }) => _installer.download(installer, onProgress: onProgress, proxyUrl: proxyUrl);

  /// Closes the application and lets the setup replace it.
  Future<void> restartInto(String setup) => _installer.restartInto(setup);

  /// Opens the release page in whatever the system uses for links.
  ///
  /// `explorer.exe` is how the application already opens the model folder,
  /// which keeps this off a separate dependency.
  Future<void> openPage(Uri page) async {
    if (!Platform.isWindows) {
      throw const LoreDubFailure(FailureCode.explorerUnsupported);
    }
    await Process.start(
      'explorer.exe',
      [page.toString()],
      mode: ProcessStartMode.detached,
    );
  }
}

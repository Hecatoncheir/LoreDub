// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import '../../domain/app_release.dart';
import '../../domain/failure.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';

class UpdateRepository {
  UpdateRepository(this._updates, this._notifications);

  final UpdateService _updates;
  final NotificationService _notifications;

  Future<String> currentVersion() => _updates.currentVersion();

  Future<AppRelease?> latestRelease({String proxyUrl = ''}) =>
      _updates.latestRelease(proxyUrl: proxyUrl);

  Future<void> announce({required String title, required String body}) =>
      _notifications.show(title: title, body: body);

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

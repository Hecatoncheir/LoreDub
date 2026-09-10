// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Raises Windows toasts.
///
/// The identifiers below are what Windows files notifications under; they are
/// fixed for the life of the application, because changing them makes the
/// system treat the toasts as coming from a different program.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _appName = 'LoreDub';
  static const _appUserModelId = 'com.loredub.LoreDub';
  static const _guid = '6f4d2a1c-9b3e-4c7a-8f21-0d5e7b3a9c64';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  /// Prepares the plugin once. A failure here is not worth stopping over:
  /// the application works without toasts, so it is swallowed and reported
  /// by [available] instead.
  Future<bool> initialize() async {
    if (_ready) return true;
    if (!Platform.isWindows) return false;
    try {
      _ready =
          await _plugin.initialize(
            settings: const InitializationSettings(
              windows: WindowsInitializationSettings(
                appName: _appName,
                appUserModelId: _appUserModelId,
                guid: _guid,
              ),
            ),
          ) ??
          false;
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  bool get available => _ready;

  Future<void> show({required String title, required String body}) async {
    if (!await initialize()) return;
    try {
      await _plugin.show(id: 0, title: title, body: body);
    } catch (_) {
      // A toast that will not appear is not a reason to disturb the run.
    }
  }
}

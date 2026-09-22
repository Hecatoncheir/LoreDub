// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/app_settings.dart';
import '../../domain/app_settings_json.dart';
import '../../domain/cpu_threads.dart';
import 'model_catalog.dart';
import 'runtime_paths.dart';

/// Where the settings are kept: one JSON object under one preference.
///
/// Every setting used to be a preference of its own, and a save wrote all
/// forty of them -- each a rewrite of the whole preferences file, on the
/// interface's isolate, on every tick of a slider. Now a save is one write.
/// A machine the older build ran on has no object yet, and its settings are
/// read off the preferences it left, which carry the same names.
class SettingsService {
  static const _key = 'settings';

  Future<AppSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    return appSettingsFromJson(
      _stored(preferences),
      dubbingLanguages: dubbingLanguages,
      bundledPython: bundledPythonExecutablePath(),
      defaultThreads: defaultCpuThreads(Platform.numberOfProcessors),
    );
  }

  Future<void> save(AppSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, jsonEncode(settings.toJson()));
  }

  /// The settings as they were last written, or as an older build left them
  /// one preference each. Damaged, they read as a fresh install's rather
  /// than refusing to start.
  static Map<String, Object?> _stored(SharedPreferences preferences) {
    final kept = preferences.getString(_key);
    if (kept == null) {
      return {
        for (final key in preferences.getKeys())
          if (key != _key) key: preferences.get(key),
      };
    }
    try {
      return switch (jsonDecode(kept)) {
        final Map<String, Object?> json => json,
        _ => const {},
      };
    } on FormatException {
      return const {};
    }
  }
}

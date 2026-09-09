// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads and persists OCR capture settings', () async {
    SharedPreferences.setMockInitialValues({
      'captureMode': 'ocr',
      'ocrRegionTop': 0.65,
    });
    final service = SettingsService();

    final loaded = await service.load();

    expect(loaded.captureMode, CaptureMode.ocr);
    expect(loaded.ocrRegionTop, 0.65);

    await service.save(loaded.copyWith(ocrRegionTop: 0.4));
    final saved = await service.load();
    expect(saved.ocrRegionTop, 0.4);
  });
}

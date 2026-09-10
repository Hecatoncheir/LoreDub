// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads and persists OCR capture settings', () async {
    SharedPreferences.setMockInitialValues({
      'captureMode': 'ocr',
      'ocrRegionTop': 0.65,
      'modelProxyUrl': 'http://127.0.0.1:7890',
      'audioCaptureSource': 'system',
      'pythonExecutable': r'C:\Python311\python.exe',
    });
    final service = SettingsService();

    final loaded = await service.load();

    expect(loaded.captureMode, CaptureMode.ocr);
    expect(loaded.ocrRegionTop, 0.65);
    expect(loaded.modelProxyUrl, 'http://127.0.0.1:7890');
    expect(loaded.audioCaptureSource, AudioCaptureSource.system);
    expect(loaded.pythonExecutable, r'C:\Python311\python.exe');

    await service.save(
      loaded.copyWith(
        ocrRegionTop: 0.4,
        modelProxyUrl: 'http://proxy.example:8080',
        audioCaptureSource: AudioCaptureSource.process,
        pythonExecutable: 'python.exe',
      ),
    );
    final saved = await service.load();
    expect(saved.ocrRegionTop, 0.4);
    expect(saved.modelProxyUrl, 'http://proxy.example:8080');
    expect(saved.audioCaptureSource, AudioCaptureSource.process);
    expect(saved.pythonExecutable, 'python.exe');
  });

  test('remembers a source language chosen in advance', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SettingsService();

    final defaults = await service.load();
    expect(defaults.detectSourceLanguage, isTrue);
    expect(defaults.effectiveSourceLanguage, 'auto');

    await service.save(
      defaults.copyWith(detectSourceLanguage: false, sourceLanguage: 'ja'),
    );
    final saved = await service.load();

    expect(saved.detectSourceLanguage, isFalse);
    expect(saved.sourceLanguage, 'ja');
    expect(saved.effectiveSourceLanguage, 'ja');
  });

  test('keeps the chosen language while detection is on', () async {
    SharedPreferences.setMockInitialValues({
      'detectSourceLanguage': true,
      'sourceLanguage': 'de',
    });

    final loaded = await SettingsService().load();

    expect(loaded.sourceLanguage, 'de');
    expect(loaded.effectiveSourceLanguage, 'auto');
  });

  test('refuses a stored language whisper would not accept', () async {
    SharedPreferences.setMockInitialValues({'sourceLanguage': 'klingon'});

    expect((await SettingsService().load()).sourceLanguage, 'en');
  });

  test('starts on automatic device selection with nothing pinned', () async {
    SharedPreferences.setMockInitialValues({});

    final loaded = await SettingsService().load();

    expect(loaded.computeDevice, ComputeDevice.auto);
    expect(loaded.recognitionBackend, isNull);
    expect(loaded.translationBackend, isNull);
    expect(loaded.speechBackend, isNull);
  });

  test('remembers the device preset and the stages pinned against it', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SettingsService();

    await service.save(
      const AppSettings()
          .withComputeDevice(ComputeDevice.gpu)
          .withBackend(ComputeStage.recognition, ComputeBackend.vulkan),
    );
    final saved = await service.load();

    expect(saved.computeDevice, ComputeDevice.gpu);
    expect(saved.recognitionBackend, ComputeBackend.vulkan);
    expect(saved.translationBackend, isNull);
  });

  test('clears a pin from storage when the preset is pressed again', () async {
    SharedPreferences.setMockInitialValues({'recognitionBackend': 'cuda'});
    final service = SettingsService();

    await service.save(const AppSettings().withComputeDevice(ComputeDevice.cpu));

    expect((await service.load()).recognitionBackend, isNull);
  });

  test('refuses a backend this build no longer offers', () async {
    SharedPreferences.setMockInitialValues({'recognitionBackend': 'metal'});

    expect((await SettingsService().load()).recognitionBackend, isNull);
  });

  test('follows the speaker until told otherwise', () async {
    SharedPreferences.setMockInitialValues({});

    final loaded = await SettingsService().load();

    expect(loaded.automaticVoice, isTrue);
    expect(loaded.voice, isEmpty, reason: 'the catalogue names the default');
  });

  test('remembers a voice picked by hand', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SettingsService();

    await service.save(const AppSettings(automaticVoice: false, voice: 'eugene'));
    final saved = await service.load();

    expect(saved.automaticVoice, isFalse);
    expect(saved.voice, 'eugene');
  });
}

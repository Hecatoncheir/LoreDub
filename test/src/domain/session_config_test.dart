// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/ocr_region.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart';
import 'package:lore_dub/src/domain/session_config.dart';

void main() {
  const worker = WorkerPlan(threads: 4, pythonExecutable: 'python.exe', runtimeDirectory: 'rt');
  const screen = ScreenSessionConfig(
    worker: WorkerPlan(
      threads: 4,
      pythonExecutable: 'python.exe',
      runtimeDirectory: 'rt',
      speaker: 'aidar',
    ),
    capture: CapturePlan(mode: CaptureMode.ocr, processId: 42),
    lines: LineRules(targetLanguage: 'ru', textLanguage: 'ru'),
  );

  test('writes the capture as the flat keys ld_start reads', () {
    const capture = CapturePlan(
      mode: CaptureMode.ocrAndAudio,
      processId: 42,
      audioSource: AudioCaptureSource.system,
      wholeScreen: true,
      region: OcrRegion(left: 0.1, top: 0.2, right: 0.9, bottom: 0.8),
      ocrLanguage: 'ru',
    );

    expect(capture.toNativeJson(captureDirectory: r'C:\capture'), {
      'processId': 42,
      'captureMode': 'ocrAndAudio',
      'audioSource': 'system',
      'ocrSource': 'screen',
      'ocrRegionLeft': 0.1,
      'ocrRegionTop': 0.2,
      'ocrRegionRight': 0.9,
      'ocrRegionBottom': 0.8,
      'ocrLanguage': 'ru',
      'captureDirectory': r'C:\capture',
    });
    expect(capture.toNativeJson(), isNot(contains('captureDirectory')));
  });

  test('a voice or a frame changed under a session keeps everything else', () {
    final voiced = screen.withSpeaker('xenia');
    expect(voiced.worker.speaker, 'xenia');
    expect(voiced.capture.processId, 42);
    expect(voiced.session, PipelineSession.screen);

    const frame = OcrRegion(left: 0.2, top: 0.6, right: 0.8, bottom: 0.9);
    final moved = voiced.withRegion(frame);
    expect(moved.capture.region, frame);
    expect(moved.worker.speaker, 'xenia');
  });

  test('a session that reads no frame has none to move', () {
    const files = VoiceFilesSessionConfig(worker: worker);
    expect(files.withRegion(OcrRegion.standard), same(files));
    expect(files.capture, isNull);
    expect(files.lines, isNull);
  });

  test('text in the dubbing language is voiced as it is', () {
    expect(screen.lines.translatesText, isFalse);
    expect(const LineRules(targetLanguage: 'ru').translatesText, isTrue);
    expect(const LineRules(targetLanguage: 'en').translatesHeard, isFalse);
  });

  test('a language model is handed every line, English into English included', () {
    // Whisper hands it what it heard rather than English, and the model
    // itself leaves a line already in the dubbing language as it is.
    expect(const LineRules(targetLanguage: 'en', languageModel: true).translatesHeard, isTrue);
    expect(const LineRules(targetLanguage: 'ru', languageModel: true).translatesHeard, isTrue);
  });

  test('a plan carries the dubbing language and the template its model wants', () {
    const settings = AppSettings(targetLanguage: 'en');
    final plan = WorkerPlan.under(
      settings,
      runtimeDirectory: 'rt',
      languageModel: true,
      chatTemplate: 'gemma',
    );

    expect(plan.targetLanguage, 'en');
    expect(plan.languageModel, isTrue);
    expect(plan.chatTemplate, 'gemma');
    expect(plan.copyWith(speaker: 'x').chatTemplate, 'gemma');
    expect(worker.languageModel, isFalse);
    expect(worker.chatTemplate, isEmpty);
  });
}

// Copyright (c) 2026 GameLingo contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_lingo/src/data/services/model_storage_service.dart';
import 'package:game_lingo/src/domain/model_package.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ModelStorageService', () {
    late Directory temporaryDirectory;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'game_lingo_models_test_',
      );
    });

    tearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test('installs an artifact only after hash verification', () async {
      final bytes = List<int>.generate(64, (index) => index);
      final model = _model(bytes, sha256.convert(bytes).toString());
      final progress = <double>[];
      final service = ModelStorageService(
        rootProvider: () async => temporaryDirectory,
        client: MockClient((_) async => http.Response.bytes(bytes, 200)),
      );

      await service.install(model, onProgress: progress.add);

      expect(await service.isInstalled(model), isTrue);
      expect(progress, isNotEmpty);
      expect(progress.last, 1);
      final directory = await service.modelDirectory(model);
      expect(File('${directory.path}/model.bin').existsSync(), isTrue);
      expect(File('${directory.path}/model.bin.part').existsSync(), isFalse);
    });

    test('removes a partial file when verification fails', () async {
      final bytes = List<int>.filled(16, 7);
      final model = _model(bytes, 'invalid-hash');
      final service = ModelStorageService(
        rootProvider: () async => temporaryDirectory,
        client: MockClient((_) async => http.Response.bytes(bytes, 200)),
      );

      await expectLater(
        service.install(model, onProgress: (_) {}),
        throwsA(isA<StateError>()),
      );

      final directory = await service.modelDirectory(model);
      expect(File('${directory.path}/model.bin').existsSync(), isFalse);
      expect(File('${directory.path}/model.bin.part').existsSync(), isFalse);
    });
  });
}

ModelPackage _model(List<int> bytes, String hash) => ModelPackage(
  id: 'test',
  title: 'Test model',
  description: 'Test model',
  artifacts: [
    ModelArtifact(
      fileName: 'model.bin',
      url: Uri.parse('https://example.invalid/model.bin'),
      byteSize: bytes.length,
      hash: hash,
    ),
  ],
);

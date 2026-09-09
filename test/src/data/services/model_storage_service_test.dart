// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/model_storage_service.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/model_proxy.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ModelStorageService', () {
    late Directory temporaryDirectory;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'lore_dub_models_test_',
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

  group('model proxy', () {
    test('accepts host and authenticated HTTP proxy URLs', () {
      final local = parseModelProxyUrl('127.0.0.1:7890');
      final authenticated = parseModelProxyUrl(
        'http://user:secret@proxy.example:8080',
      );

      expect(modelProxyDirective(local!), 'PROXY 127.0.0.1:7890');
      expect(
        modelProxyDirective(authenticated!),
        'PROXY proxy.example:8080',
      );
    });

    test('rejects unsupported proxy URLs', () {
      expect(
        () => parseModelProxyUrl('socks5://127.0.0.1:1080'),
        throwsFormatException,
      );
      expect(
        () => parseModelProxyUrl('http://proxy.example:70000'),
        throwsFormatException,
      );
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

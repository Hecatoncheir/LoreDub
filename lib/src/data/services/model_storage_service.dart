// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../domain/model_package.dart';
import '../../domain/model_proxy.dart';

typedef DownloadProgress = void Function(double value);
typedef ModelRootProvider = Future<Directory> Function();

class ModelStorageService {
  ModelStorageService({this._client, ModelRootProvider? rootProvider})
    : _rootProvider = rootProvider ?? _defaultRoot;

  final http.Client? _client;
  final ModelRootProvider _rootProvider;

  static Future<Directory> _defaultRoot() async {
    final support = await getApplicationSupportDirectory();
    return Directory(path.join(support.path, 'models'));
  }

  Future<Directory> modelDirectory(ModelPackage model) async {
    final root = await _rootProvider();
    return Directory(path.join(root.path, model.id));
  }

  Future<bool> isInstalled(ModelPackage model) async {
    final directory = await modelDirectory(model);
    for (final artifact in model.artifacts) {
      final file = File(path.join(directory.path, artifact.fileName));
      if (!await file.exists()) return false;
      if (artifact.byteSize case final expected?) {
        if (await file.length() != expected) return false;
      }
    }
    return true;
  }

  Future<void> install(
    ModelPackage model, {
    required DownloadProgress onProgress,
    String proxyUrl = '',
  }) async {
    final client = _client ?? _createDownloadClient(proxyUrl);
    try {
      await _install(model, client: client, onProgress: onProgress);
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<void> _install(
    ModelPackage model, {
    required http.Client client,
    required DownloadProgress onProgress,
  }) async {
    final directory = await modelDirectory(model);
    await directory.create(recursive: true);
    final knownTotal = model.artifacts.fold<int>(
      0,
      (sum, artifact) => sum + (artifact.byteSize ?? 0),
    );
    var completed = 0;
    for (final artifact in model.artifacts) {
      final destination = File(path.join(directory.path, artifact.fileName));
      final partial = File('${destination.path}.part');
      if (await destination.exists() && await _verify(destination, artifact)) {
        completed += artifact.byteSize ?? 0;
        continue;
      }
      if (await partial.exists()) await partial.delete();
      final response = await client.send(http.Request('GET', artifact.url));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Сервер вернул ${response.statusCode} для ${artifact.url}',
        );
      }
      final sink = partial.openWrite();
      var artifactBytes = 0;
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          artifactBytes += chunk.length;
          final responseTotal = response.contentLength;
          if (knownTotal > 0) {
            onProgress(((completed + artifactBytes) / knownTotal).clamp(0, 1));
          } else if (responseTotal != null && responseTotal > 0) {
            onProgress((artifactBytes / responseTotal).clamp(0, 1));
          } else {
            onProgress(0);
          }
        }
      } finally {
        await sink.close();
      }
      if (!await _verify(partial, artifact)) {
        await partial.delete();
        throw StateError('Проверка ${artifact.fileName} не пройдена');
      }
      await partial.rename(destination.path);
      completed += artifact.byteSize ?? artifactBytes;
    }
    onProgress(1);
  }

  static http.Client _createDownloadClient(String proxyUrl) {
    final proxy = parseModelProxyUrl(proxyUrl);
    if (proxy == null) return http.Client();
    final client = HttpClient()..findProxy = (_) => modelProxyDirective(proxy);
    if (proxy.userInfo.isNotEmpty) {
      final separator = proxy.userInfo.indexOf(':');
      final username = Uri.decodeComponent(
        separator < 0 ? proxy.userInfo : proxy.userInfo.substring(0, separator),
      );
      final password = separator < 0
          ? ''
          : Uri.decodeComponent(proxy.userInfo.substring(separator + 1));
      final credentials = HttpClientBasicCredentials(username, password);
      client.authenticateProxy = (host, port, _, realm) async {
        if (host != proxy.host || port != proxy.port) return false;
        client.addProxyCredentials(host, port, realm ?? '', credentials);
        return true;
      };
    }
    return IOClient(client);
  }

  Future<bool> _verify(File file, ModelArtifact artifact) async {
    if (artifact.byteSize case final expected?) {
      if (await file.length() != expected) return false;
    }
    if (artifact.hash case final expected?) {
      final algorithm = artifact.hashAlgorithm == HashAlgorithm.sha256 ? sha256 : md5;
      final actual = await algorithm.bind(file.openRead()).first;
      return actual.toString() == expected;
    }
    return true;
  }
}

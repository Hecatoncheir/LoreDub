// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path/path.dart' as path;
import 'package:socks5_proxy/socks_client.dart';

import '../../domain/failure.dart';
import '../../domain/model_package.dart';
import '../../domain/model_proxy.dart';

typedef DownloadProgress = void Function(double value);

/// Fetching files that must arrive intact, shared by the model and the GPU
/// runtime stores. Both stream to a `.part` file and rename only once size
/// and hash agree, so an interrupted download can never be mistaken for a
/// finished one.
Future<void> downloadArtifacts(
  List<ModelArtifact> artifacts, {
  required Directory directory,
  required http.Client client,
  required DownloadProgress onProgress,
}) async {
  await directory.create(recursive: true);
  final knownTotal = artifacts.fold<int>(0, (sum, artifact) => sum + (artifact.byteSize ?? 0));
  var completed = 0;
  for (final artifact in artifacts) {
    final destination = File(path.join(directory.path, artifact.fileName));
    final partial = File('${destination.path}.part');
    if (await destination.exists() && await verifyArtifact(destination, artifact)) {
      completed += artifact.byteSize ?? 0;
      continue;
    }
    if (await partial.exists()) await partial.delete();
    final response = await client.send(http.Request('GET', artifact.url));
    if (response.statusCode != HttpStatus.ok) {
      throw LoreDubFailure(
        FailureCode.downloadRejected,
        detail: '${response.statusCode} — ${artifact.url}',
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
    if (!await verifyArtifact(partial, artifact)) {
      await partial.delete();
      throw LoreDubFailure(FailureCode.verificationFailed, detail: artifact.fileName);
    }
    await partial.rename(destination.path);
    completed += artifact.byteSize ?? artifactBytes;
  }
  onProgress(1);
}

Future<bool> verifyArtifact(File file, ModelArtifact artifact) async {
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

Future<http.Client> createDownloadClient(String proxyUrl) async {
  final proxy = parseModelProxyUrl(proxyUrl);
  if (proxy == null) return http.Client();
  if (proxy.scheme.toLowerCase() == 'socks5') {
    final addresses = await InternetAddress.lookup(proxy.host);
    if (addresses.isEmpty) {
      throw const LoreDubFailure(FailureCode.socksLookupFailed);
    }
    final credentials = _proxyCredentials(proxy);
    final client = HttpClient();
    SocksTCPClient.assignToHttpClient(client, [
      ProxySettings(
        addresses.first,
        proxy.port,
        username: credentials.$1,
        password: credentials.$2,
      ),
    ]);
    return IOClient(client);
  }
  final client = HttpClient()..findProxy = (_) => modelProxyDirective(proxy);
  if (proxy.userInfo.isNotEmpty) {
    final values = _proxyCredentials(proxy);
    final credentials = HttpClientBasicCredentials(values.$1!, values.$2!);
    client.authenticateProxy = (host, port, _, realm) async {
      if (host != proxy.host || port != proxy.port) return false;
      client.addProxyCredentials(host, port, realm ?? '', credentials);
      return true;
    };
  }
  return IOClient(client);
}

(String?, String?) _proxyCredentials(Uri proxy) {
  if (proxy.userInfo.isEmpty) return (null, null);
  final separator = proxy.userInfo.indexOf(':');
  final username = Uri.decodeComponent(
    separator < 0 ? proxy.userInfo : proxy.userInfo.substring(0, separator),
  );
  final password = separator < 0
      ? ''
      : Uri.decodeComponent(proxy.userInfo.substring(separator + 1));
  return (username, password);
}

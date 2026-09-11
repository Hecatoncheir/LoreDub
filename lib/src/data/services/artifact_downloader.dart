// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path/path.dart' as path;
import 'package:socks5_proxy/socks_client.dart';

import '../../domain/download_control.dart';
import '../../domain/failure.dart';
import '../../domain/model_package.dart';
import '../../domain/model_proxy.dart';

typedef DownloadProgress = void Function(double value);

/// Fetching files that must arrive intact, shared by the model and the GPU
/// runtime stores. Both stream to a `.part` file and rename only once size
/// and hash agree, so an interrupted download can never be mistaken for a
/// finished one.
///
/// A `.part` left behind by a closed application is resumed with a range
/// request rather than thrown away: these are hundreds of megabytes, and
/// starting over is a poor answer to a lost connection.
Future<DownloadOutcome> downloadArtifacts(
  List<ModelArtifact> artifacts, {
  required Directory directory,
  required http.Client client,
  required DownloadProgress onProgress,
  DownloadControl? control,

  /// How long a response may go without delivering a byte before it counts
  /// as stalled. A stalled connection does not always close, and waiting on
  /// it is how a download could sit at the same percentage for an hour.
  Duration stallTimeout = const Duration(seconds: 60),

  /// How many times a stalled download reconnects before it gives up.
  int stallRetries = 5,
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
    if (control?.requestedStop case final stop?) {
      return _stopped(stop, partial);
    }
    var artifactBytes = 0;
    DownloadOutcome? stopped;
    for (var stalls = 0; ; stalls++) {
      try {
        final resumed = await _openStream(client, artifact, partial, stallTimeout);
        final response = resumed.response;
        final sink = partial.openWrite(
          mode: resumed.offset > 0 ? FileMode.writeOnlyAppend : FileMode.writeOnly,
        );
        artifactBytes = resumed.offset;
        try {
          await for (final chunk in response.stream.timeout(stallTimeout)) {
            // Checked between chunks so a stop lands within a few hundred
            // kilobytes rather than at the end of a half-gigabyte file.
            if (control?.requestedStop case final stop?) {
              stopped = stop;
              break;
            }
            sink.add(chunk);
            artifactBytes += chunk.length;
            final responseTotal = response.contentLength;
            if (knownTotal > 0) {
              onProgress(((completed + artifactBytes) / knownTotal).clamp(0, 1));
            } else if (responseTotal != null && responseTotal > 0) {
              onProgress(((artifactBytes) / (responseTotal + resumed.offset)).clamp(0, 1));
            } else {
              onProgress(0);
            }
          }
        } finally {
          await sink.close();
        }
        break;
      } on TimeoutException {
        // The connection went quiet without closing. What arrived is on
        // disk, so a fresh request picks up from there with a range.
        if (control?.requestedStop case final stop?) {
          stopped = stop;
          break;
        }
        if (stalls >= stallRetries) {
          throw LoreDubFailure(FailureCode.downloadStalled, detail: artifact.fileName);
        }
      }
    }
    if (stopped != null) return _stopped(stopped, partial);
    if (!await verifyArtifact(partial, artifact)) {
      // A part that fails here is not worth resuming: the bytes on disk are
      // wrong, and every later attempt would inherit them.
      await partial.delete();
      throw LoreDubFailure(FailureCode.verificationFailed, detail: artifact.fileName);
    }
    await partial.rename(destination.path);
    completed += artifact.byteSize ?? artifactBytes;
  }
  onProgress(1);
  return DownloadOutcome.completed;
}

/// Leaves the partial file in the state the stop asked for: a pause keeps it
/// so the next attempt resumes, a cancel takes it with it.
Future<DownloadOutcome> _stopped(DownloadOutcome stop, File partial) async {
  if (stop == DownloadOutcome.cancelled && await partial.exists()) {
    await partial.delete();
  }
  return stop;
}

/// What a download is starting from: the live response, and how many bytes
/// of the file are already on disk and must not be fetched again.
class _ResumedDownload {
  const _ResumedDownload(this.response, this.offset);

  final http.StreamedResponse response;
  final int offset;
}

Future<_ResumedDownload> _openStream(
  http.Client client,
  ModelArtifact artifact,
  File partial,
  Duration stallTimeout,
) async {
  var offset = await _resumeOffset(partial, artifact);
  var response = await _send(client, artifact.url, offset, stallTimeout);

  // The server no longer recognizes the range: the file changed, or what is
  // on disk is longer than it. Either way the part is worthless.
  if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable && offset > 0) {
    await partial.delete();
    offset = 0;
    response = await _send(client, artifact.url, 0, stallTimeout);
  }

  if (response.statusCode == HttpStatus.partialContent) {
    return _ResumedDownload(response, offset);
  }
  if (response.statusCode != HttpStatus.ok) {
    throw LoreDubFailure(
      FailureCode.downloadRejected,
      detail: '${response.statusCode} — ${artifact.url}',
    );
  }
  // A plain 200 to a range request means the server ignored it and is
  // sending the whole file, so whatever was on disk is overwritten.
  return _ResumedDownload(response, 0);
}

/// A server that never answers stalls as surely as one that stops sending.
Future<http.StreamedResponse> _send(
  http.Client client,
  Uri url,
  int offset,
  Duration stallTimeout,
) {
  final request = http.Request('GET', url);
  if (offset > 0) request.headers[HttpHeaders.rangeHeader] = 'bytes=$offset-';
  return client.send(request).timeout(stallTimeout);
}

/// How much of [partial] can be kept. Zero means starting over.
Future<int> _resumeOffset(File partial, ModelArtifact artifact) async {
  if (!await partial.exists()) return 0;
  final length = await partial.length();
  if (length <= 0) return 0;
  // A part at or beyond the full size is not a resume point: it is either
  // finished or wrong, and neither can be settled by asking for more bytes.
  if (artifact.byteSize case final expected? when length >= expected) {
    await partial.delete();
    return 0;
  }
  return length;
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

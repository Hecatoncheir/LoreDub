// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lore_dub/src/data/services/artifact_downloader.dart';
import 'package:lore_dub/src/domain/download_control.dart';
import 'package:lore_dub/src/domain/failure.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory directory;
  final payload = List<int>.generate(400, (index) => index % 251);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lore-dub-download');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  ModelArtifact artifactOf({int? byteSize}) => ModelArtifact(
    fileName: 'build.zip',
    url: Uri.parse('https://example.invalid/build.zip'),
    byteSize: byteSize ?? payload.length,
  );

  File partFile() => File(path.join(directory.path, 'build.zip.part'));
  File destinationFile() => File(path.join(directory.path, 'build.zip'));

  /// A server that honours `Range`, like the release hosts these files
  /// actually come from.
  MockClient rangeServer(List<String?> seenRanges) => MockClient((request) async {
    final range = request.headers[HttpHeaders.rangeHeader];
    seenRanges.add(range);
    if (range == null) return http.Response.bytes(payload, 200);
    final offset = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
    if (offset >= payload.length) return http.Response('', 416);
    return http.Response.bytes(payload.sublist(offset), 206);
  });

  test('asks for nothing extra when there is no part to resume', () async {
    final ranges = <String?>[];

    await downloadArtifacts(
      [artifactOf()],
      directory: directory,
      client: rangeServer(ranges),
      onProgress: (_) {},
    );

    expect(ranges, [null]);
    expect(await destinationFile().readAsBytes(), payload);
  });

  test('continues a part the application was closed on top of', () async {
    // 150 of the 400 bytes made it to disk before the app went away.
    await partFile().writeAsBytes(payload.sublist(0, 150));
    final ranges = <String?>[];

    await downloadArtifacts(
      [artifactOf()],
      directory: directory,
      client: rangeServer(ranges),
      onProgress: (_) {},
    );

    expect(ranges, ['bytes=150-'], reason: 'only the missing tail is fetched');
    expect(
      await destinationFile().readAsBytes(),
      payload,
      reason: 'the resumed halves must join into the original file',
    );
    expect(await partFile().exists(), isFalse);
  });

  test('reports progress from where the part left off, not from zero', () async {
    await partFile().writeAsBytes(payload.sublist(0, 300));
    final progress = <double>[];

    await downloadArtifacts(
      [artifactOf()],
      directory: directory,
      client: rangeServer([]),
      onProgress: progress.add,
    );

    expect(progress.first, greaterThan(0.7), reason: 'three quarters were already there');
    expect(progress.last, 1);
  });

  test('starts over when the server refuses the range', () async {
    // Longer than the file: the catalogue moved on, or the part is junk.
    await partFile().writeAsBytes(List<int>.filled(900, 7));
    final ranges = <String?>[];

    await downloadArtifacts(
      [artifactOf()],
      directory: directory,
      client: rangeServer(ranges),
      onProgress: (_) {},
    );

    expect(ranges, [null], reason: 'an oversized part is dropped before asking');
    expect(await destinationFile().readAsBytes(), payload);
  });

  test('overwrites the part when the server ignores the range', () async {
    await partFile().writeAsBytes(List<int>.filled(150, 7));
    var asked = 0;
    final client = MockClient((request) async {
      asked++;
      // A server that answers 200 to a range request is sending the whole
      // file; appending to it would corrupt the result.
      return http.Response.bytes(payload, 200);
    });

    await downloadArtifacts(
      [artifactOf()],
      directory: directory,
      client: client,
      onProgress: (_) {},
    );

    expect(asked, 1);
    expect(await destinationFile().readAsBytes(), payload);
  });

  test('throws away a part that resumed into the wrong bytes', () async {
    await partFile().writeAsBytes(List<int>.filled(150, 7));
    final artifact = ModelArtifact(
      fileName: 'build.zip',
      url: Uri.parse('https://example.invalid/build.zip'),
      byteSize: payload.length,
      hash: 'not the hash of what will arrive',
    );

    await expectLater(
      downloadArtifacts(
        [artifact],
        directory: directory,
        client: rangeServer([]),
        onProgress: (_) {},
      ),
      throwsA(
        isA<LoreDubFailure>().having(
          (error) => error.code,
          'code',
          FailureCode.verificationFailed,
        ),
      ),
    );
    expect(
      await partFile().exists(),
      isFalse,
      reason: 'a bad part must not be resumed forever',
    );
  });

  test('leaves a finished file alone instead of fetching it again', () async {
    await destinationFile().writeAsBytes(payload);
    final ranges = <String?>[];

    await downloadArtifacts(
      [artifactOf()],
      directory: directory,
      client: rangeServer(ranges),
      onProgress: (_) {},
    );

    expect(ranges, isEmpty);
  });

  test('reports a refusal that is not a range problem', () async {
    final client = MockClient((_) async => http.Response('', 404));

    await expectLater(
      downloadArtifacts(
        [artifactOf()],
        directory: directory,
        client: client,
        onProgress: (_) {},
      ),
      throwsA(
        isA<LoreDubFailure>()
            .having((error) => error.code, 'code', FailureCode.downloadRejected)
            .having((error) => error.detail, 'detail', contains('404')),
      ),
    );
  });

  group('stopping a download', () {
    test('a pause keeps what arrived so the next attempt resumes', () async {
      final control = DownloadControl();
      final client = MockClient((request) async {
        // Stop as soon as the first response is being handed over.
        control.pause();
        return http.Response.bytes(payload, 200);
      });

      final outcome = await downloadArtifacts(
        [artifactOf()],
        directory: directory,
        client: client,
        onProgress: (_) {},
        control: control,
      );

      expect(outcome, DownloadOutcome.paused);
      expect(destinationFile().existsSync(), isFalse, reason: 'nothing is finished');
    });

    test('a cancel throws the part away', () async {
      await partFile().writeAsBytes(payload.sublist(0, 150));
      final control = DownloadControl()..cancel();

      final outcome = await downloadArtifacts(
        [artifactOf()],
        directory: directory,
        client: MockClient((_) async => http.Response.bytes(payload, 200)),
        onProgress: (_) {},
        control: control,
      );

      expect(outcome, DownloadOutcome.cancelled);
      expect(partFile().existsSync(), isFalse, reason: 'a cancel leaves nothing behind');
    });

    test('a pause leaves the part for a later resume', () async {
      await partFile().writeAsBytes(payload.sublist(0, 150));
      final control = DownloadControl()..pause();

      final outcome = await downloadArtifacts(
        [artifactOf()],
        directory: directory,
        client: MockClient((_) async => http.Response.bytes(payload, 200)),
        onProgress: (_) {},
        control: control,
      );

      expect(outcome, DownloadOutcome.paused);
      expect(await partFile().length(), 150, reason: 'the bytes are kept');
    });

    test('resuming after a pause finishes the file', () async {
      await partFile().writeAsBytes(payload.sublist(0, 150));

      final outcome = await downloadArtifacts(
        [artifactOf()],
        directory: directory,
        client: rangeServer([]),
        onProgress: (_) {},
        control: DownloadControl(),
      );

      expect(outcome, DownloadOutcome.completed);
      expect(await destinationFile().readAsBytes(), payload);
    });

    test('a cancel asked for after a pause wins', () {
      final control = DownloadControl()
        ..pause()
        ..cancel();

      expect(control.requestedStop, DownloadOutcome.cancelled);
    });

    test('a pause does not undo a cancel', () {
      final control = DownloadControl()
        ..cancel()
        ..pause();

      expect(control.requestedStop, DownloadOutcome.cancelled);
    });
  });
}

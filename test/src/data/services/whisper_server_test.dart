// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lore_dub/src/data/services/whisper_server.dart';
import 'package:lore_dub/src/domain/failure.dart';
import 'package:path/path.dart' as path;

import '../../../support/fake_worker.dart';
import '../../../support/temporary_directory.dart';

void main() {
  late Directory runtime;
  late String server;

  /// The cli's place, which is where the server is looked for.
  late String cli_;
  late String phrase;
  late List<List<String>> started;
  late List<FakeWorker> servers;
  late List<http.Request> asked;
  late String answer;
  late int status;
  late bool up;

  setUp(() async {
    runtime = await Directory.systemTemp.createTemp('lore-dub-whisper-server');
    addTearDown(() => deleteOnceReleased(runtime));
    server = path.join(runtime.path, 'whisper-server.exe');
    cli_ = path.join(runtime.path, 'whisper-cli.exe');
    await File(server).writeAsString('binary');
    phrase = path.join(runtime.path, 'phrase.wav');
    await File(phrase).writeAsBytes(const [82, 73, 70, 70]);
    started = [];
    servers = [];
    asked = [];
    answer = '{"task":"transcribe","language":"english","text":" Hello there.\\n"}';
    status = 200;
    up = true;
  });

  ResidentWhisper resident({Duration limit = const Duration(seconds: 5)}) => ResidentWhisper(
    start: (executable, arguments) async {
      started.add([executable, ...arguments]);
      final process = FakeWorker();
      servers.add(process);
      return process;
    },
    client: MockClient((request) async {
      if (request.method == 'GET') return http.Response(up ? 'whisper' : '', up ? 200 : 503);
      asked.add(request);
      // Bytes, the way the server sends them: it names no charset, and the
      // line is read as UTF-8 whatever the header says.
      return http.Response.bytes(utf8.encode(answer), status);
    }),
    limit: limit,
    startupLimit: const Duration(seconds: 2),
  );

  /// The command line the service builds for `whisper-cli`.
  List<String> cli({String language = 'en', bool translate = false, bool rough = false}) => [
    '-m',
    'ggml-turbo.bin',
    '-f',
    phrase,
    '-l',
    language,
    if (translate) '-tr',
    if (rough) ...['-ac', '1000'],
    '-sns',
    '-otxt',
    '-of',
    path.withoutExtension(phrase),
    '-t',
    '6',
    '-np',
  ];

  test('starts the server beside the cli for the model asked, and asks it the phrase', () async {
    final whisper = resident();

    final run = await whisper.run(path.join(runtime.path, 'whisper-cli.exe'), cli());

    expect(started.single.first, server);
    expect(started.single, containsAllInOrder(['-m', 'ggml-turbo.bin', '--host', '127.0.0.1']));
    expect(started.single, containsAllInOrder(['-t', '6']));
    expect(run.exitCode, 0);
    expect(run.text, ' Hello there.\n');
    expect(run.language, 'en');
    final body = asked.single.body;
    expect(asked.single.url.path, '/inference');
    expect(body, contains('name="language"\r\n\r\nen'));
    expect(body, contains('name="translate"\r\n\r\nfalse'));
    expect(body, contains('name="suppress_non_speech"\r\n\r\ntrue'));
    expect(body, contains('name="response_format"\r\n\r\nverbose_json'));
    expect(body, isNot(contains('audio_ctx')));
  });

  test('passes the translation, the detection and the shortened window per request', () async {
    final whisper = resident();

    await whisper.run(cli_, cli(language: 'auto', translate: true, rough: true));

    final body = asked.single.body;
    expect(body, contains('name="language"\r\n\r\nauto'));
    expect(body, contains('name="translate"\r\n\r\ntrue'));
    expect(body, contains('name="audio_ctx"\r\n\r\n1000'));
  });

  test(
    'keeps one server for the phrases of a session, and restarts it for another model',
    () async {
      final whisper = resident();

      await whisper.run(cli_, cli());
      await whisper.run(cli_, cli());
      expect(started, hasLength(1));

      await whisper.run(cli_, [...cli()]..[1] = 'ggml-medium.bin');
      expect(started, hasLength(2));
      expect(servers.first.killed, isTrue, reason: 'the old model is let go of');
      expect(started.last, containsAllInOrder(['-m', 'ggml-medium.bin']));
    },
  );

  test('a stop ends the server, and the next phrase brings it back', () async {
    final whisper = resident();
    await whisper.run(cli_, cli());

    whisper.cancel();
    expect(servers.single.killed, isTrue);

    await whisper.run(cli_, cli());
    expect(started, hasLength(2));
  });

  test('names a language the catalogue knows, and leaves one it does not', () async {
    final whisper = resident();
    answer = '{"language":"russian","text":" Привет."}';
    expect((await whisper.run(cli_, cli())).language, 'ru');

    answer = '{"language":"klingon","text":" nuqneH."}';
    expect((await whisper.run(cli_, cli())).language, isNull);
    expect(languageCodeOf(null), isNull);
    expect(languageCodeOf('English'), 'en');
  });

  test('an answer other than success comes back as the run failing', () async {
    final whisper = resident();
    status = 500;
    answer = 'failed to decode';

    final run = await whisper.run(cli_, cli());

    expect(run.exitCode, 500);
    expect(run.stderr, 'failed to decode');
    expect(run.text, isNull);
  });

  test('a server that dies while loading fails the phrase with what it said', () async {
    up = false;
    final whisper = resident();

    final running = whisper.run(cli_, cli());
    await settle();
    servers.single.complain('failed to load model');
    await settle();
    servers.single.exit(1);

    await expectLater(
      running,
      throwsA(
        isA<LoreDubFailure>()
            .having((f) => f.code, 'code', FailureCode.whisperFailed)
            .having((f) => f.detail, 'detail', contains('failed to load model')),
      ),
    );
  });

  test('a server that never answers is given up on', () async {
    up = false;
    final whisper = resident();

    await expectLater(
      whisper.run(cli_, cli()),
      throwsA(isA<LoreDubFailure>().having((f) => f.code, 'code', FailureCode.whisperFailed)),
    );
    expect(servers.single.killed, isTrue);
  });

  test('a missing server is said so by name', () async {
    final whisper = resident();
    await File(server).delete();

    await expectLater(
      whisper.run(path.join(runtime.path, 'whisper-cli.exe'), cli()),
      throwsA(
        isA<LoreDubFailure>()
            .having((f) => f.code, 'code', FailureCode.whisperMissing)
            .having((f) => f.detail, 'detail', server),
      ),
    );
  });

  test('reads the cli command line back into what the server is asked', () {
    final ask = WhisperAsk.of(cli(language: 'de', translate: true, rough: true));

    expect(ask.model, 'ggml-turbo.bin');
    expect(ask.file, phrase);
    expect(ask.language, 'de');
    expect(ask.translate, isTrue);
    expect(ask.suppressNonSpeech, isTrue);
    expect(ask.audioContext, 1000);
    expect(ask.threads, 6);
    expect(() => WhisperAsk.of(const ['-l', 'en']), throwsArgumentError);
  });
}

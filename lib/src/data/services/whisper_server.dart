// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import '../../domain/failure.dart';
import 'process_launcher.dart';
import 'whisper_runner.dart';

/// whisper.cpp kept running through the session as a server of its own and
/// asked over HTTP for every phrase.
///
/// `whisper-cli` loaded the model afresh for each phrase, which on the card
/// cost three and a half seconds of every line's latency against a fifth of
/// a second here (ADR 0001, measured again). It answers the same call as
/// [WhisperRunner], reading the model, the file, the language and the flags
/// off the command line the service builds for `whisper-cli`, so the service
/// and its tests are the same whichever runs; what it heard comes back in
/// the run itself rather than in a file. The server is started on the first
/// phrase of a build and a model, restarted when either changes, and ended by
/// [cancel], which is what a stop calls.
class ResidentWhisper extends WhisperRunner {
  ResidentWhisper({
    ProcessLauncher? start,
    http.Client? client,
    super.limit,
    this.startupLimit = const Duration(minutes: 2),
  }) : _launch = start ?? Process.start,
       _client = client ?? http.Client();

  /// The longest the server may take to load the model and answer.
  final Duration startupLimit;

  final ProcessLauncher _launch;
  final http.Client _client;

  Process? _server;
  Uri? _address;

  /// The build and the model the server was started for.
  (String, String)? _serving;

  /// The last lines the server wrote, for a failure to say why.
  final List<String> _said = [];

  @override
  Future<WhisperRun> run(String executable, List<String> arguments) async {
    final ask = WhisperAsk.of(arguments);
    final server = path.join(path.dirname(executable), _serverName);
    final address = await _serve(server, ask.model, ask.threads);
    final request = http.MultipartRequest('POST', address.replace(path: '/inference'))
      ..fields['response_format'] = 'verbose_json'
      ..fields['language'] = ask.language
      ..fields['translate'] = '${ask.translate}'
      ..fields['suppress_non_speech'] = '${ask.suppressNonSpeech}'
      ..files.add(await http.MultipartFile.fromPath('file', ask.file));
    if (ask.audioContext case final context?) request.fields['audio_ctx'] = '$context';
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request)).timeout(limit);
    } on TimeoutException {
      // A recognition that hangs would hold every phrase behind it; the
      // server is ended, and the next phrase starts it again.
      cancel();
      throw LoreDubFailure(
        FailureCode.whisperFailed,
        detail: 'no answer within ${limit.inSeconds} s',
      );
    }
    // Read as UTF-8 whatever the header says: the server names no charset,
    // and a Russian line read as Latin-1 is not a line at all.
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode != 200) {
      return (exitCode: response.statusCode, stdout: '', stderr: body, text: null, language: null);
    }
    final answer = jsonDecode(body) as Map<String, Object?>;
    return (
      exitCode: 0,
      stdout: '',
      stderr: '',
      text: answer['text'] as String? ?? '',
      language: languageCodeOf(answer['language'] as String?),
    );
  }

  /// Ends the server. The phrase under way, if any, is answered to nobody;
  /// the next phrase brings the server up again.
  @override
  void cancel() {
    _server?.kill();
    _server = null;
    _serving = null;
    _address = null;
  }

  /// The server for [executable] over [model], started where it is not up.
  Future<Uri> _serve(String executable, String model, int threads) async {
    if (_server != null && _serving == (executable, model)) return _address!;
    cancel();
    if (!await File(executable).exists()) {
      throw LoreDubFailure(FailureCode.whisperMissing, detail: executable);
    }
    final port = await _freePort();
    final address = Uri.parse('http://127.0.0.1:$port');
    final process = await _launch(executable, [
      '-m',
      model,
      '--host',
      '127.0.0.1',
      '--port',
      '$port',
      '-t',
      '$threads',
    ]);
    _server = process;
    _serving = (executable, model);
    _address = address;
    _said.clear();
    _drain(process.stdout);
    _drain(process.stderr);
    var ended = false;
    unawaited(
      process.exitCode.then((_) {
        ended = true;
        if (identical(_server, process)) cancel();
      }),
    );
    final deadline = DateTime.now().add(startupLimit);
    while (DateTime.now().isBefore(deadline)) {
      if (ended) {
        throw LoreDubFailure(FailureCode.whisperFailed, detail: _said.join('\n'));
      }
      if (await _answers(address)) return address;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    cancel();
    throw LoreDubFailure(
      FailureCode.whisperFailed,
      detail: 'whisper-server did not answer within ${startupLimit.inSeconds} s',
    );
  }

  Future<bool> _answers(Uri address) async {
    try {
      final response = await _client.get(address).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } on Object {
      return false;
    }
  }

  /// Reads what the server prints, so the pipe never fills, keeping the
  /// last lines for a failure to name.
  void _drain(Stream<List<int>> output) {
    output.transform(systemEncoding.decoder).transform(const LineSplitter()).listen((line) {
      _said.add(line);
      if (_said.length > _linesKept) _said.removeAt(0);
    }, onError: (Object _) {});
  }

  static Future<int> _freePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  static const _serverName = 'whisper-server.exe';
  static const _linesKept = 40;
}

/// What the service asks of `whisper-cli`, read off its command line: the
/// model and the file, the language, and the flags the server takes per
/// request.
class WhisperAsk {
  const WhisperAsk({
    required this.model,
    required this.file,
    this.language = 'auto',
    this.translate = false,
    this.suppressNonSpeech = false,
    this.audioContext,
    this.threads = 4,
  });

  factory WhisperAsk.of(List<String> arguments) {
    String? model;
    String? file;
    var language = 'auto';
    var translate = false;
    var suppress = false;
    int? audioContext;
    var threads = 4;
    for (var at = 0; at < arguments.length; at++) {
      final flag = arguments[at];
      String next() => at + 1 < arguments.length ? arguments[++at] : '';
      switch (flag) {
        case '-m':
          model = next();
        case '-f':
          file = next();
        case '-l':
          language = next();
        case '-tr':
          translate = true;
        case '-sns':
          suppress = true;
        case '-ac':
          audioContext = int.tryParse(next());
        case '-t':
          threads = int.tryParse(next()) ?? threads;
        case '-of':
          next();
      }
    }
    if (model == null || file == null) {
      throw ArgumentError('whisper asked without a model or a file: $arguments');
    }
    return WhisperAsk(
      model: model,
      file: file,
      language: language,
      translate: translate,
      suppressNonSpeech: suppress,
      audioContext: audioContext,
      threads: threads,
    );
  }

  final String model;
  final String file;
  final String language;
  final bool translate;
  final bool suppressNonSpeech;
  final int? audioContext;
  final int threads;
}

/// The code of a language the server names in full, or null for one the
/// catalogue has no use for -- which leaves the session detecting.
String? languageCodeOf(String? name) => name == null ? null : _languageCodes[name.toLowerCase()];

const _languageCodes = {
  'english': 'en',
  'russian': 'ru',
  'ukrainian': 'uk',
  'german': 'de',
  'french': 'fr',
  'spanish': 'es',
  'italian': 'it',
  'portuguese': 'pt',
  'polish': 'pl',
  'japanese': 'ja',
  'korean': 'ko',
  'chinese': 'zh',
  'turkish': 'tr',
  'dutch': 'nl',
  'czech': 'cs',
  'swedish': 'sv',
  'arabic': 'ar',
  'hindi': 'hi',
  'finnish': 'fi',
  'greek': 'el',
  'hungarian': 'hu',
  'romanian': 'ro',
  'danish': 'da',
  'norwegian': 'no',
  'vietnamese': 'vi',
  'indonesian': 'id',
  'thai': 'th',
  'hebrew': 'he',
  'bulgarian': 'bg',
  'kazakh': 'kk',
  'belarusian': 'be',
};

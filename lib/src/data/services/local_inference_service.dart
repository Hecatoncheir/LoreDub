// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../domain/runtime_paths.dart';

class InferenceResult {
  const InferenceResult({required this.english, required this.translated, required this.wavePath});

  final String english;
  final String translated;
  final String wavePath;
}

class LocalInferenceService {
  Process? _worker;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  final _pending = <int, Completer<Map<String, Object?>>>{};
  Completer<void>? _workerReady;
  var _requestId = 0;

  static Future<Directory> createWorkDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(path.join(support.path, 'work'));
    await directory.create(recursive: true);
    return directory;
  }

  Future<void> start({
    required String translationModel,
    required String ttsModel,
    required int threads,
    required String pythonExecutable,
  }) async {
    _workerReady = Completer<void>();
    if (!Platform.isWindows) throw UnsupportedError('Локальный pipeline доступен только в Windows');
    final python = await resolvePythonExecutable(pythonExecutable);
    final work = await createWorkDirectory();
    final workerFile = File(path.join(work.path, 'inference_worker.py'));
    final workerBytes = await rootBundle.load('assets/runtime/inference_worker.py');
    await workerFile.writeAsBytes(workerBytes.buffer.asUint8List(), flush: true);
    _worker = await Process.start(python, [
      '-u',
      workerFile.path,
      '--translation-model',
      translationModel,
      '--tts-model',
      path.join(ttsModel, 'v5_3_ru.pt'),
      '--work-directory',
      work.path,
      '--threads',
      '$threads',
    ]);
    _stdoutSubscription = _worker!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleWorkerLine);
    _stderrSubscription = _worker!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => stderr.writeln('[inference] $line'));
    unawaited(
      _worker!.exitCode.then((code) {
        final error = StateError('Marian/Silero worker завершился с кодом $code');
        if (!(_workerReady?.isCompleted ?? true)) _workerReady!.completeError(error);
        for (final request in _pending.values) {
          if (!request.isCompleted) request.completeError(error);
        }
        _pending.clear();
      }),
    );
    await _workerReady!.future.timeout(const Duration(minutes: 5));
  }

  void _handleWorkerLine(String line) {
    try {
      final message = jsonDecode(line) as Map<String, Object?>;
      if (message['type'] == 'ready') {
        if (!(_workerReady?.isCompleted ?? true)) _workerReady!.complete();
        return;
      }
      final id = message['id'] as int?;
      if (id != null) _pending.remove(id)?.complete(message);
    } catch (error) {
      stderr.writeln('[inference] invalid worker response: $error');
    }
  }

  Future<InferenceResult?> processSegment({
    required String wavePath,
    required String whisperModel,
    required int threads,
  }) async {
    final executableDirectory = File(Platform.resolvedExecutable).parent;
    final whisper = path.join(
      executableDirectory.path,
      'runtime',
      'whisper',
      'whisper-cli.exe',
    );
    if (!File(whisper).existsSync()) throw StateError('Не найден whisper-cli.exe');
    final prefix = path.withoutExtension(wavePath);
    final recognition = await Process.run(whisper, [
      '-m',
      path.join(whisperModel, 'ggml-base.bin'),
      '-f',
      wavePath,
      '-l',
      'auto',
      '-tr',
      '-otxt',
      '-of',
      prefix,
      '-t',
      '$threads',
      '-np',
    ]);
    if (recognition.exitCode != 0) {
      throw StateError('whisper.cpp: ${recognition.stderr}');
    }
    final outputFile = File('$prefix.txt');
    if (!await outputFile.exists()) return null;
    final english = (await outputFile.readAsString()).trim();
    await outputFile.delete();
    if (english.isEmpty || RegExp(r'^\[.*\]$').hasMatch(english)) return null;

    return processText(english);
  }

  Future<InferenceResult> processText(String english) async {
    final normalized = english.trim();
    if (normalized.isEmpty) throw ArgumentError.value(english, 'english', 'Текст пуст');

    final id = ++_requestId;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    _worker!.stdin.writeln(jsonEncode({'id': id, 'text': normalized}));
    final response = await completer.future.timeout(const Duration(minutes: 2));
    if (response['error'] case final String error) throw StateError('Marian/Silero: $error');
    return InferenceResult(
      english: normalized,
      translated: response['translated']! as String,
      wavePath: response['wave']! as String,
    );
  }

  Future<void> stop() async {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(StateError('Pipeline остановлен'));
    }
    _pending.clear();
    await _worker?.stdin.close();
    _worker?.kill();
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _worker = null;
    _workerReady = null;
  }
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lore_dub/src/data/services/local_inference_service.dart';
import 'package:lore_dub/src/domain/compute_device.dart';

/// Lets what is already on its way arrive: a line through the decoder, a
/// start as far as its next wait.
Future<void> settle() async {
  for (var turn = 0; turn < 5; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const WorkerFiles workerFiles = (
  python: 'python.exe',
  script: 'inference_worker.py',
  work: 'work',
  whisper: null,
);

/// A machine with both binaries found and the worker's script written out.
Future<WorkerFiles> everythingInPlace({
  required String pythonExecutable,
  required bool requiresWhisper,
  required ComputeBackend recognitionBackend,
  String? downloadedRuntimeDirectory,
}) async => workerFiles;

/// A worker that says what the test tells it to and dies when it is killed —
/// or, with [lingers], only once the test lets it, the way Windows takes a
/// moment over a process that has been ended.
class FakeWorker implements Process {
  FakeWorker({this.lingers = false}) {
    _stdin.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _requests.add(jsonDecode(line) as Map<String, Object?>));
  }

  final bool lingers;
  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  final _stdin = StreamController<List<int>>();
  final _requests = <Map<String, Object?>>[];
  final _exit = Completer<int>();
  late final IOSink _sink = IOSink(_stdin);

  bool killed = false;

  /// The id of the request the service wrote last, which a reply repeats.
  int get lastRequestId => _requests.last['id']! as int;

  void say(Map<String, Object?> message) => _stdout.add(utf8.encode('${jsonEncode(message)}\n'));

  void complain(String line) => _stderr.add(utf8.encode('$line\n'));

  void exit(int code) {
    if (_exit.isCompleted) return;
    _exit.complete(code);
    unawaited(_stdout.close());
    unawaited(_stderr.close());
  }

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (!lingers) exit(-1);
    return true;
  }

  @override
  int get pid => 4242;

  @override
  IOSink get stdin => _sink;

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;
}

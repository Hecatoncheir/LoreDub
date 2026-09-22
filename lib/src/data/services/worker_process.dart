// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/failure.dart';
import 'worker_channel.dart';

/// The worker's output as lines, tolerating a malformed UTF-8 sequence instead
/// of tearing the stream down: the worker is forced into UTF-8, but a stray
/// byte from an unexpected interpreter must not silently swallow every reply.
Stream<String> decodeWorkerLines(Stream<List<int>> source) =>
    source.transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter());

/// Keeps the last stderr lines of the worker so that a crash can be reported
/// with the reason the interpreter printed instead of a bare exit code. The
/// application has no console, so this is the only place the user can see it.
class WorkerDiagnostics {
  WorkerDiagnostics({this.limit = 4});

  final int limit;
  final _lines = <String>[];

  bool get isEmpty => _lines.isEmpty;

  String get recentOutput => _lines.join(' | ');

  void clear() => _lines.clear();

  void add(String line) {
    final value = line.trim();
    if (value.isEmpty) return;
    _lines.add(value);
    if (_lines.length > limit) _lines.removeAt(0);
  }

  /// The reason the worker gave for dying, if it gave one.
  LoreDubFailure describeExit(int code) => _lines.isEmpty
      ? LoreDubFailure(FailureCode.workerExitedSilently, detail: '$code')
      : LoreDubFailure(FailureCode.workerExited, detail: '$code$exitDetailSeparator$recentOutput');
}

/// One running worker, from the moment its interpreter started to the moment
/// it is ended or dies: what it says, the requests written to it, and the
/// handshake it answers once its models are loaded.
///
/// Each worker is its own object rather than fields of the service reset by
/// hand, because for a moment two of them exist -- a stop kills the process
/// and returns before Windows has finished with it, while the next screen
/// is starting its own -- and read from shared fields, the dead one's exit
/// failed the live one's start: "the worker exited with -1 and said
/// nothing" after every card listened to. A worker that has been ended
/// answers for nobody: a line it still gets out is passed over, and its
/// exit is its own business.
class WorkerProcess {
  /// Listens to [process] from the start: a stop fails the handshake, and a
  /// failure nobody hears is an error of its own.
  WorkerProcess(this._process, {this._onProgress, required this._onDied}) {
    // Waited on by the start; marked handled so that a stop landing when
    // nobody is waiting yet does not raise an error of its own.
    _ready.future.ignore();
    // IOSink defaults to the system encoding, which would corrupt any
    // non-ASCII phrase on the way into the worker.
    _process.stdin.encoding = utf8;
    _listening = [
      decodeWorkerLines(_process.stdout).listen((line) {
        if (!_ended) _handleLine(line);
      }),
      decodeWorkerLines(_process.stderr).listen((line) {
        _diagnostics.add(line);
        stderr.writeln('[inference] $line');
      }),
    ];
    unawaited(_process.exitCode.then(_onExit));
  }

  final Process _process;
  final void Function(double value, String stage)? _onProgress;
  final void Function(WorkerProcess worker, LoreDubFailure error, {required bool starting}) _onDied;
  late final List<StreamSubscription<String>> _listening;
  final _diagnostics = WorkerDiagnostics();
  late final _channel = WorkerChannel(lastWords: () => _lastWords);
  final _ready = Completer<Map<String, Object?>>();

  /// Ended by the service or dead: either way nobody is to be told of it
  /// any more.
  bool _ended = false;

  String? get _lastWords => _diagnostics.isEmpty ? null : _diagnostics.recentOutput;

  /// Waits for the worker to say it is ready, and answers with what it said
  /// -- where it put each stage. One that does not say so within [limit]
  /// is not coming up at all, and is ended: given up on, it would go on
  /// loading, and holding what it loaded, with nobody left to end it.
  Future<Map<String, Object?>> handshake(Duration limit) async {
    try {
      return await _ready.future.timeout(limit);
    } on TimeoutException {
      final said = _lastWords;
      await end();
      throw LoreDubFailure(FailureCode.workerStartTimeout, detail: said);
    }
  }

  /// Writes [body] as one request and answers with the reply.
  Future<Map<String, Object?>> request(Map<String, Object?> body, {required Duration timeout}) =>
      _channel.request(_process.stdin, body, timeout: timeout);

  /// Fails whoever waits on the worker and takes it down, waiting for it to
  /// go so the next one starts on a machine this one has finished with: the
  /// extracted script, the work directory and the models it holds are all
  /// things two of them would share.
  Future<void> end() async {
    if (_ended) return;
    _ended = true;
    const stopped = LoreDubFailure(FailureCode.pipelineStopped);
    _channel.failAll(stopped);
    // A start waiting for the handshake is told now. Left unanswered it sat
    // out the whole startup limit: the exit of a worker already let go of is
    // nobody's, so nothing else was ever going to end that wait.
    if (!_ready.isCompleted) _ready.completeError(stopped);
    await _process.stdin.close();
    _process.kill();
    await _process.exitCode.timeout(const Duration(seconds: 5), onTimeout: () => -1);
    for (final subscription in _listening) {
      await subscription.cancel();
    }
  }

  /// Ends a worker nobody is going to talk to, before anybody listens to it.
  /// What it printed is read to the end and dropped: unread, it keeps the
  /// pipes of a dead process open.
  static void discard(Process process) {
    process.kill();
    process.stdout.drain<void>().ignore();
    process.stderr.drain<void>().ignore();
  }

  /// The worker is gone on its own. Whoever was waiting on it is told why:
  /// the start, if it had not come up yet, and every request in flight.
  void _onExit(int code) {
    if (_ended) return;
    _ended = true;
    final error = _diagnostics.describeExit(code);
    final starting = !_ready.isCompleted;
    if (starting) _ready.completeError(error);
    _channel.failAll(error);
    _onDied(this, error, starting: starting);
  }

  /// One line the worker wrote: its handshake, a step of its startup, or
  /// the answer to a request somebody is waiting for.
  void _handleLine(String line) {
    try {
      final message = jsonDecode(line) as Map<String, Object?>;
      switch (message['type']) {
        case 'ready':
          if (!_ready.isCompleted) _ready.complete(message);
        case 'progress':
          _onProgress?.call(
            (message['value']! as num).toDouble(),
            message['stage'] as String? ?? '',
          );
        default:
          _channel.answer(message);
      }
    } catch (error) {
      // Keep the offending line: a reply nobody can parse would otherwise only
      // show up as a request timeout two minutes later.
      _diagnostics.add('unreadable worker reply: $line');
      stderr.writeln('[inference] invalid worker response: $error');
    }
  }
}

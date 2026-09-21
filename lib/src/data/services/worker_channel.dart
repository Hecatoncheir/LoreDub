// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:convert';

import '../../domain/failure.dart';

/// Requests to the worker and the replies to them, matched by id.
///
/// The worker speaks line-delimited JSON: a request goes out as one line
/// carrying an `id`, and the reply that comes back carries the same one.
/// Every request is the same five steps -- number it, remember who waits,
/// write it, wait no longer than it is worth, and read an `error` as a
/// failure -- which were written out nine times before they lived here.
class WorkerChannel {
  WorkerChannel({required this._lastWords});

  /// What the worker said last, which a request that timed out is reported
  /// with: a reply that never came is usually explained there.
  final String? Function() _lastWords;
  final _pending = <int, Completer<Map<String, Object?>>>{};
  var _nextId = 0;

  /// Writes [body] to [worker] as one request and answers with the reply.
  ///
  /// Fails as `workerTimeout` when nothing comes within [timeout], and as
  /// `workerFailed` when the worker answers with an error of its own.
  Future<Map<String, Object?>> request(
    StringSink worker,
    Map<String, Object?> body, {
    required Duration timeout,
  }) async {
    final id = ++_nextId;
    final reply = Completer<Map<String, Object?>>();
    _pending[id] = reply;
    worker.writeln(jsonEncode({'id': id, ...body}));
    final response = await reply.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(id);
        throw LoreDubFailure(FailureCode.workerTimeout, detail: _lastWords());
      },
    );
    if (response['error'] case final String error) {
      throw LoreDubFailure(FailureCode.workerFailed, detail: error);
    }
    return response;
  }

  /// Hands a reply to whoever asked for it. A line carrying no request id,
  /// or one nobody waits for any longer, answers nobody.
  void answer(Map<String, Object?> message) {
    if (message['id'] case final int id) _pending.remove(id)?.complete(message);
  }

  /// Fails every request still waiting with [error]: the worker they were
  /// written to is gone.
  void failAll(Object error) {
    for (final reply in _pending.values) {
      if (!reply.isCompleted) reply.completeError(error);
    }
    _pending.clear();
  }
}

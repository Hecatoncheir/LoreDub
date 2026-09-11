// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import '../../domain/compute_device.dart';
import '../../domain/failure.dart';
import '../../domain/game_process.dart';
import '../../native/lore_dub_native.g.dart';
import 'local_inference_service.dart';
import 'phrase_queue.dart';

typedef NativeStringReader = int Function(Pointer<Char> output, int capacity);

class NativeEngineException implements Exception {
  const NativeEngineException(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'NativeEngineException($code): $message';
}

class NativeEngineService {
  NativeEngineService() {
    _inference.onStartupProgress = (value, stage) =>
        _events.add({'type': 'startup', 'value': value, 'stage': stage});
  }

  final _events = StreamController<Map<String, Object?>>.broadcast();
  final _inference = LocalInferenceService();
  Timer? _pollTimer;
  late final _phrases = PhraseQueue(process: _processPhrase);

  /// Playback runs beside recognition instead of inside it. Voicing a reply
  /// takes as long as the reply itself, and holding the pipeline for that
  /// would put every later phrase further behind the game.
  Future<void> _playback = Future.value();
  Map<String, Object?>? _activeConfig;
  String? _reportedLanguage;
  String? _reportedVoice;

  Stream<Map<String, Object?>> get events => _events.stream;
  bool get processLoopbackSupported => ld_is_process_loopback_supported() == 1;

  Future<List<GameProcess>> listProcesses() async {
    final json = _readNativeString(ld_list_processes_json);
    final values = jsonDecode(json) as List<Object?>;
    final processes = values
        .map((value) => GameProcess.fromJson(value! as Map<String, Object?>))
        .toList();
    processes.sort((left, right) => left.name.compareTo(right.name));
    return processes;
  }

  /// What the machine's graphics adapters and GPU drivers offer.
  ///
  /// Only the hardware half is filled in: whether the runtime for a backend
  /// has been downloaded is a question for the storage service.
  Future<ComputeAvailability> probeGraphics() async {
    final json = _readNativeString(ld_probe_graphics_json);
    return ComputeAvailability.fromProbeJson(jsonDecode(json) as Map<String, Object?>);
  }

  static ComputeBackend _backendFrom(Object? name) => ComputeBackend.values.firstWhere(
    (backend) => backend.name == name,
    orElse: () => ComputeBackend.cpu,
  );

  static List<String> _voiceList(Object? joined) =>
      (joined as String? ?? '').split(',').where((name) => name.isNotEmpty).toList();

  Future<void> start(Map<String, Object?> config) async {
    _reportedLanguage = null;
    _reportedVoice = null;
    await LocalInferenceService.removeStaleAudio();
    final models = config['models']! as Map<String, String>;
    await _inference.start(
      translationModel: models['translation']!,
      ttsModel: models['speech']!,
      speaker: config['speaker']! as String,
      threads: config['cpuThreads']! as int,
      speed: config['ttsSpeed']! as double,
      pythonExecutable: config['pythonExecutable']! as String,
      requiresWhisper: config['captureMode'] != 'ocr',
      sourceLanguage: config['sourceLanguage']! as String,
      translationPrefix: config['translationPrefix'] as String? ?? '',
      followSpeaker: config['followSpeaker'] as bool? ?? false,
      maleVoices: _voiceList(config['maleVoices']),
      femaleVoices: _voiceList(config['femaleVoices']),
      recognitionBackend: _backendFrom(config['recognitionBackend']),
      translationBackend: _backendFrom(config['translationBackend']),
      downloadedRuntimeDirectory: config['runtimeDirectory'] as String?,
      voiceConverter: models['converter'],
    );
    // What the worker settled on, which is not always what it was asked for.
    if (_inference.translationBackend case final actual?) {
      _events.add({'type': 'backend', 'stage': 'translation', 'backend': actual.name});
    }
    _events.add({'type': 'startup', 'value': 0.98, 'stage': 'capture'});
    final work = await LocalInferenceService.createWorkDirectory();
    final capture = Directory('${work.path}${Platform.pathSeparator}capture');
    await capture.create(recursive: true);
    _activeConfig = {...config, 'captureDirectory': capture.path};
    final pointer = jsonEncode(_activeConfig).toNativeUtf8();
    try {
      _throwIfError(ld_start(pointer.cast()));
    } catch (_) {
      await _inference.stop();
      rethrow;
    } finally {
      malloc.free(pointer);
    }
    _pollTimer ??= Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => _pollEvents(),
    );
  }

  Future<void> stop() async {
    // Cleared first: segments captured moments ago are still travelling
    // through the queue, and failing them is expected once the user stops.
    _activeConfig = null;
    _throwIfError(ld_stop());
    _pollEvents();
    _pollTimer?.cancel();
    _pollTimer = null;
    for (final phrase in _phrases.clear()) {
      final wavePath = phrase.wavePath;
      if (wavePath != null) unawaited(_deleteIfPresent(wavePath));
    }
    await _inference.stop();
  }

  Future<void> setProcessVolume(int processId, double volume) async {
    _throwIfError(ld_set_process_volume(processId, volume));
  }

  void _pollEvents() {
    for (var index = 0; index < 16; index++) {
      final json = _readNativeString(ld_poll_event_json, emptyAllowed: true);
      if (json.isEmpty) break;
      final event = jsonDecode(json) as Map<String, Object?>;
      if (event['type'] == 'audioSegment') {
        final wavePath = event['path']! as String;
        if (_activeConfig == null) {
          unawaited(_deleteIfPresent(wavePath));
          continue;
        }
        _phrases.add(PendingPhrase.audio(wavePath));
      } else if (event['type'] == 'ocrText') {
        if (_activeConfig == null) continue;
        _phrases.add(PendingPhrase.text(event['text']! as String));
      } else {
        _events.add(fromNativeEvent(event));
      }
    }
  }

  Future<void> _processPhrase(PendingPhrase phrase) {
    final wavePath = phrase.wavePath;
    return wavePath != null ? _processSegment(wavePath) : _processOcrText(phrase.text!);
  }

  Future<void> _processSegment(String wavePath) async {
    final started = Stopwatch()..start();
    try {
      final config = _activeConfig;
      if (config == null) return;
      final models = config['models']! as Map<String, String>;
      final result = await _inference.processSegment(
        wavePath: wavePath,
        whisperModel: models['whisper']!,
        threads: config['cpuThreads']! as int,
        translateSpeech: config['translateSpeech'] as bool? ?? true,
      );
      _publishSpokenLanguage();
      if (result == null) return;
      await _publishResult(result, started.elapsedMilliseconds, original: '');
    } catch (error) {
      _reportFailure(error);
    } finally {
      await _deleteIfPresent(wavePath);
    }
  }

  Future<void> _processOcrText(String recognizedText) async {
    final started = Stopwatch()..start();
    try {
      if (_activeConfig == null) return;
      final result = await _inference.processText(recognizedText);
      await _publishResult(
        result,
        started.elapsedMilliseconds,
        original: recognizedText,
      );
    } catch (error) {
      _reportFailure(error);
    }
  }

  /// Announces the language whisper settled on, once, so the interface can
  /// show what auto-detection actually decided.
  void _publishSpokenLanguage() {
    final detected = _inference.spokenLanguage;
    if (detected == null || detected == _reportedLanguage) return;
    _reportedLanguage = detected;
    _events.add({'type': 'language', 'code': detected});
  }

  /// Work already in flight fails when the user stops the pipeline. That is
  /// the expected outcome of stopping, not something to alarm them with.
  void _reportFailure(Object error) {
    if (_activeConfig == null) return;
    _events.add({'type': 'error', 'failure': error});
  }

  Future<void> _publishResult(
    InferenceResult result,
    int latencyMs, {
    required String original,
  }) async {
    _events.add({
      'type': 'transcript',
      'original': original,
      'english': result.english,
      'translated': result.translated,
      'latencyMs': latencyMs,
    });
    // Which voice read it: the automatic choice can change it per phrase, so
    // the interface should not have to guess.
    if (result.voice.isNotEmpty && result.voice != _reportedVoice) {
      _reportedVoice = result.voice;
      _events.add({'type': 'voice', 'name': result.voice});
    }
    _enqueuePlayback(result.wavePath);
  }

  /// Utterances are voiced one after another so they never overlap, but the
  /// next phrase is recognized while the previous one is still being spoken.
  void _enqueuePlayback(String wavePath) {
    _playback = _playback.then((_) => _playQueued(wavePath));
  }

  Future<void> _playQueued(String wavePath) async {
    try {
      if (_activeConfig != null) await _playInIsolate(wavePath);
    } catch (error) {
      _reportFailure(error);
    } finally {
      await _deleteIfPresent(wavePath);
    }
  }

  /// Static so the isolate closure captures nothing but the path. Reaching it
  /// from an instance closure would drag the whole service — and its futures,
  /// which cannot cross an isolate boundary — into the message.
  static Future<void> _playInIsolate(String wavePath) => Isolate.run(() => _playWave(wavePath));

  static void _playWave(String wavePath) {
    final pointer = wavePath.toNativeUtf8();
    try {
      final code = ld_play_wave(pointer.cast());
      if (code < 0) {
        throw NativeEngineException(
          code,
          ld_error_message(code).cast<Utf8>().toDartString(),
        );
      }
    } finally {
      malloc.free(pointer);
    }
  }

  static Future<void> _deleteIfPresent(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Temporary audio cleanup is best effort.
    }
  }

  String _readNativeString(
    NativeStringReader reader, {
    bool emptyAllowed = false,
  }) {
    return readNativeUtf8String(
      reader,
      emptyAllowed: emptyAllowed,
      throwIfError: _throwIfError,
    );
  }

  void _throwIfError(int code) {
    if (code >= 0) return;
    final message = ld_error_message(code).cast<Utf8>().toDartString();
    throw NativeEngineException(code, message);
  }

  void dispose() {
    _pollTimer?.cancel();
    ld_stop();
    unawaited(_inference.stop());
    _events.close();
  }
}

/// An event from the native queue in the shape the rest of the app reads.
///
/// Native capture reports trouble as `{"type":"error","message":...}`, a
/// sentence in English, while the interface expects a [LoreDubFailure] under
/// `failure`. Passed on as it came, the error arrived with no failure and
/// cleared the banner instead of raising one.
Map<String, Object?> fromNativeEvent(Map<String, Object?> event) {
  if (event['type'] != 'error' || event['failure'] != null) return event;
  return {
    'type': 'error',
    'failure': LoreDubFailure(FailureCode.captureFailed, detail: event['message'] as String?),
  };
}

String readNativeUtf8String(
  NativeStringReader reader, {
  bool emptyAllowed = false,
  required void Function(int code) throwIfError,
}) {
  var required = reader(nullptr, 0);
  if (required < 0) throwIfError(required);
  if (required == 0 && emptyAllowed) return '';

  // A native value can grow between the size query and the copy (for example,
  // when a Windows process starts while the process list is being built).
  // Retry with the newly reported size instead of decoding an untouched or
  // undersized buffer.
  for (var attempt = 0; attempt < 8; attempt++) {
    final capacity = required + 1;
    final buffer = calloc<Char>(capacity);
    try {
      final written = reader(buffer, capacity);
      if (written < 0) throwIfError(written);
      if (written < capacity) {
        return buffer.cast<Utf8>().toDartString(length: written);
      }
      required = written;
    } finally {
      calloc.free(buffer);
    }
  }

  throw const FormatException(
    'Native UTF-8 value kept changing while it was being read',
  );
}

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
import '../../domain/hotkey.dart';
import '../../domain/ocr_text_delta.dart';
import '../../domain/sound_captions.dart';
import '../../native/lore_dub_native.g.dart';
import 'local_inference_service.dart';
import 'phrase_queue.dart';
import 'playback_scheduler.dart';

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
  late final _playback = PlaybackScheduler(play: _playQueued);
  Map<String, Object?>? _activeConfig;
  String? _reportedLanguage;
  String? _reportedVoice;
  int? _reportedBankSize;

  /// Set while the session rests: capture hands nothing on, and a line
  /// finishing its translation meanwhile is shown but not voiced.
  bool _paused = false;

  /// What subtitle mode read last, so a line that grows in place is voiced
  /// only for what it gained, and one that comes back unchanged — even after
  /// leaving the screen — is not voiced again.
  String? _previousOcrText;

  Stream<Map<String, Object?>> get events => _events.stream;
  bool get processLoopbackSupported => ld_is_process_loopback_supported() == 1;

  Future<List<GameProcess>> listProcesses() async {
    final json = _readNativeString(ld_list_processes_json);
    final values = jsonDecode(json) as List<Object?>;
    final processes = values
        .map((value) => GameProcess.fromJson(value! as Map<String, Object?>))
        .toList();
    processes.sort(compareGameProcesses);
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
    _reportedBankSize = null;
    _paused = false;
    _playback.maxVoices = config['overlapVoices'] == true ? overlappingVoices : 1;
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
      voiceConversionBackend: _backendFrom(config['voiceConversionBackend']),
      voiceBank: config['voiceBank'] as String?,
    );
    // What the worker settled on, which is not always what it was asked for.
    if (_inference.translationBackend case final actual?) {
      _events.add({'type': 'backend', 'stage': 'translation', 'backend': actual.name});
    }
    if (_inference.voiceConversionBackend case final actual?) {
      _events.add({'type': 'backend', 'stage': 'voiceConversion', 'backend': actual.name});
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

  /// Loads the translator and the voice for the snapshot session, which
  /// captures nothing by itself: text arrives only from areas the player
  /// selects while holding the snapshot key.
  Future<void> startSnapshot(Map<String, Object?> config) async {
    _reportedLanguage = null;
    _reportedVoice = null;
    _reportedBankSize = null;
    _paused = false;
    // One selection at a time is read, so there is no one to talk over.
    _playback.maxVoices = 1;
    await LocalInferenceService.removeStaleAudio();
    final models = config['models']! as Map<String, String>;
    await _inference.start(
      translationModel: models['translation']!,
      ttsModel: models['speech']!,
      speaker: config['speaker']! as String,
      threads: config['cpuThreads']! as int,
      speed: config['ttsSpeed']! as double,
      pythonExecutable: config['pythonExecutable']! as String,
      requiresWhisper: false,
      translationPrefix: config['translationPrefix'] as String? ?? '',
      translationBackend: _backendFrom(config['translationBackend']),
      downloadedRuntimeDirectory: config['runtimeDirectory'] as String?,
    );
    if (_inference.translationBackend case final actual?) {
      _events.add({'type': 'backend', 'stage': 'translation', 'backend': actual.name});
    }
    _activeConfig = config;
    _pollTimer ??= Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => _pollEvents(),
    );
    // Nothing native starts here to say so itself.
    _events.add({'type': 'state', 'state': 'listening'});
  }

  Future<void> stop() async {
    // Cleared first: segments captured moments ago are still travelling
    // through the queue, and failing them is expected once the user stops.
    _activeConfig = null;
    _paused = false;
    _previousOcrText = null;
    // ld_stop drops the hotkeys too; nothing is left for them to pause.
    _throwIfError(ld_stop());
    _pollEvents();
    _pollTimer?.cancel();
    _pollTimer = null;
    for (final phrase in _phrases.clear()) {
      final wavePath = phrase.wavePath;
      if (wavePath != null) unawaited(_deleteIfPresent(wavePath));
    }
    for (final wavePath in _playback.clear()) {
      unawaited(_deleteIfPresent(wavePath));
    }
    await _inference.stop();
  }

  Future<void> setProcessVolume(int processId, double volume) async {
    _throwIfError(ld_set_process_volume(processId, volume));
  }

  /// Rests or wakes the running session without tearing it down, so the
  /// worker keeps its models and resuming costs no startup.
  void setPaused(bool paused) {
    if (_activeConfig == null) return;
    _paused = paused;
    _throwIfError(ld_set_paused(paused ? 1 : 0));
    if (!paused) return;
    // Nothing heard before the pause is voiced after it.
    for (final phrase in _phrases.clear()) {
      final wavePath = phrase.wavePath;
      if (wavePath != null) unawaited(_deleteIfPresent(wavePath));
    }
    for (final wavePath in _playback.clear()) {
      unawaited(_deleteIfPresent(wavePath));
    }
    // The game plays at its own volume while dubbing rests. A device that
    // cannot be reached is no reason to refuse the pause, so the result is
    // not checked.
    ld_restore_process_volumes();
  }

  /// Registers the system-wide combinations that pause and resume the
  /// session, and the one held to select an area of the screen. Presses
  /// arrive as `hotkey` events, a selection as `snapshotReading` and then
  /// `snapshot`. A combination another program holds comes back as an error
  /// naming the action.
  ///
  /// [textLanguage] is the language a selected area is read in.
  void setHotkeys({
    Hotkey? pause,
    Hotkey? resume,
    Hotkey? snapshot,
    String textLanguage = 'en',
  }) {
    final config = jsonEncode({
      'snapshotLanguage': textLanguage,
      'pauseKey': pause?.keyCode ?? 0,
      'pauseModifiers': pause?.modifiers ?? 0,
      'resumeKey': resume?.keyCode ?? 0,
      'resumeModifiers': resume?.modifiers ?? 0,
      'snapshotKey': snapshot?.keyCode ?? 0,
      'snapshotModifiers': snapshot?.modifiers ?? 0,
    }).toNativeUtf8();
    try {
      _throwIfError(ld_set_hotkeys(config.cast()));
    } finally {
      malloc.free(config);
    }
  }

  void _pollEvents() {
    for (var index = 0; index < 16; index++) {
      final json = _readNativeString(ld_poll_event_json, emptyAllowed: true);
      if (json.isEmpty) break;
      final event = jsonDecode(json) as Map<String, Object?>;
      if (event['type'] == 'audioSegment') {
        final wavePath = event['path']! as String;
        // A segment queued a moment before the pause is dropped like one
        // captured during it.
        if (_activeConfig == null || _paused) {
          unawaited(_deleteIfPresent(wavePath));
          continue;
        }
        _phrases.add(PendingPhrase.audio(wavePath));
      } else if (event['type'] == 'ocrText') {
        if (_activeConfig == null || _paused) continue;
        final text = event['text']! as String;
        final fresh = freshOcrText(_previousOcrText, text);
        _previousOcrText = text;
        if (fresh != null) _phrases.add(PendingPhrase.text(fresh));
      } else if (event['type'] == 'snapshot') {
        if (_activeConfig == null) continue;
        // Read even while dubbing rests: a selection is asked for by hand.
        // OCR reports the lines on screen apart; the translator wants prose.
        final text = (event['text'] as String? ?? '').split(RegExp(r'\s+')).join(' ').trim();
        if (text.isNotEmpty) _phrases.add(PendingPhrase.text(text, snapshot: true));
        _events.add(event);
      } else {
        _events.add(fromNativeEvent(event));
      }
    }
  }

  Future<void> _processPhrase(PendingPhrase phrase) {
    final wavePath = phrase.wavePath;
    return wavePath != null
        ? _processSegment(wavePath)
        : _processOcrText(phrase.text!, snapshot: phrase.snapshot);
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

  Future<void> _processOcrText(String recognizedText, {bool snapshot = false}) async {
    final started = Stopwatch()..start();
    try {
      final config = _activeConfig;
      if (config == null) return;
      // Subtitles caption sounds the way whisper does: "[Music]" is not a line.
      final spoken = withoutSoundCaptions(recognizedText);
      if (spoken.isEmpty) {
        // A selection is waiting for its answer; this one held no words.
        if (snapshot) _events.add({'type': 'snapshot', 'text': ''});
        return;
      }
      // Text read in the dubbing language itself is voiced as it is.
      final result = await _inference.processText(
        spoken,
        translate: config['textLanguage'] != config['targetLanguage'],
      );
      await _publishResult(
        result,
        started.elapsedMilliseconds,
        original: spoken,
        snapshot: snapshot,
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
    bool snapshot = false,
  }) async {
    _events.add({
      'type': 'transcript',
      'original': original,
      'english': result.english,
      'translated': result.translated,
      'latencyMs': latencyMs,
      if (snapshot) 'snapshot': true,
    });
    // Which voice read it: the automatic choice can change it per phrase, so
    // the interface should not have to guess.
    if (result.voice.isNotEmpty && result.voice != _reportedVoice) {
      _reportedVoice = result.voice;
      _events.add({'type': 'voice', 'name': result.voice});
    }
    // A new character joined the bank, so the count in the settings is stale.
    if (result.bankSize case final size? when size != _reportedBankSize) {
      _reportedBankSize = size;
      _events.add({'type': 'voiceBank', 'size': size});
    }
    // A line that was already being translated when the pause came is shown
    // in the transcript, but the pause means quiet. A selection is the
    // exception: the player asked for that one.
    if (_paused && !snapshot) {
      unawaited(_deleteIfPresent(result.wavePath));
      return;
    }
    // The worker says who is speaking, so a different character may start
    // while the last one is still talking — when the settings allow it.
    _playback.add(result.wavePath, speaker: result.speaker);
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
  // Windows has no text recognition for the language the text is read in.
  if (event['type'] == 'ocrLanguageMissing') {
    return {
      'type': 'error',
      'failure': LoreDubFailure(
        FailureCode.ocrLanguageMissing,
        detail: event['language'] as String?,
      ),
    };
  }
  // Windows refused a combination: another program already holds it.
  if (event['type'] == 'hotkeyTaken') {
    return {
      'type': 'error',
      'failure': LoreDubFailure(FailureCode.hotkeyTaken, detail: event['action'] as String?),
    };
  }
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

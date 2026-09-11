// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../domain/compute_device.dart';
import '../../domain/runtime_paths.dart';
import '../../domain/spoken_language.dart';
import '../../domain/failure.dart';
import 'runtime_catalog.dart';

class InferenceResult {
  const InferenceResult({
    required this.english,
    required this.translated,
    required this.wavePath,
    this.voice = '',
    this.bankSize,
  });

  final String english;
  final String translated;
  final String wavePath;

  /// The voice that read the line, which the automatic choice can change
  /// from phrase to phrase.
  final String voice;

  /// How many voices the game's bank holds after this line, or null when
  /// the session keeps none.
  final int? bankSize;
}

/// Picks the language code out of whisper.cpp's detection line.
///
/// Detecting the language costs a full extra encoder pass, roughly doubling
/// recognition time, so it is done once and reused. A shaky guess is refused
/// to avoid locking the whole session onto the wrong language.
String? parseDetectedLanguage(String output, {double minimumProbability = 0.5}) {
  final match = RegExp(
    r'auto-detected language:\s*([a-z]{2,3})\s*\(\s*p\s*=\s*([0-9.]+)\s*\)',
  ).firstMatch(output);
  if (match == null) return null;
  final probability = double.tryParse(match.group(2)!);
  if (probability == null || probability < minimumProbability) return null;
  return match.group(1);
}

/// Reads a worker stream as UTF-8 lines. Malformed bytes are replaced instead
/// of tearing the stream down: the worker is forced into UTF-8, but a stray
/// byte from an unexpected interpreter must not silently swallow every reply.
Stream<String> decodeWorkerLines(Stream<List<int>> source) =>
    source.transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter());

/// Separates the exit code from the worker output inside a failure detail.
const exitDetailSeparator = '\u0000';

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

class LocalInferenceService {
  Process? _worker;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  final _pending = <int, Completer<Map<String, Object?>>>{};
  final _diagnostics = WorkerDiagnostics();
  Completer<void>? _workerReady;
  String? _whisperExecutable;

  /// Detected once per session and reused; null means detection is still due.
  String? _spokenLanguage;
  var _requestId = 0;

  /// Reports how far the worker is through its startup, which takes long
  /// enough that the application must not look frozen while it happens.
  void Function(double value, String stage)? onStartupProgress;

  /// The language the pipeline is recognizing, once it is known.
  String? get spokenLanguage => _spokenLanguage;

  /// What the worker actually put the translator on, as it reported at start.
  String? _translationDevice;
  ComputeBackend? get translationBackend => _backendOf(_translationDevice);

  /// Where the worker put the voice converter, or null when it loaded none.
  String? _converterDevice;
  ComputeBackend? get voiceConversionBackend => _backendOf(_converterDevice);

  static ComputeBackend? _backendOf(String? device) => switch (device) {
    'cuda' => ComputeBackend.cuda,
    'cpu' => ComputeBackend.cpu,
    _ => null,
  };

  /// Removes audio a previous run left behind. The worker can finish writing a
  /// phrase just as the pipeline is stopped, and then nobody is waiting for
  /// that file any more; a crash leaves captured segments in the same way.
  static Future<void> removeStaleAudio([Directory? workDirectory]) async {
    final work = workDirectory ?? await createWorkDirectory();
    final directories = [work, Directory(path.join(work.path, 'capture'))];
    for (final directory in directories) {
      if (!await directory.exists()) continue;
      await for (final entry in directory.list(followLinks: false)) {
        if (entry is! File) continue;
        final name = path.basename(entry.path);
        if (!name.endsWith('.wav')) continue;
        if (!name.startsWith('speech-') && !name.startsWith('segment-')) continue;
        try {
          await entry.delete();
        } on FileSystemException {
          // Best effort: a file still held by playback is removed next time.
        }
      }
    }
  }

  static Future<Directory> createWorkDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(path.join(support.path, 'work'));
    await directory.create(recursive: true);
    return directory;
  }

  Future<void> start({
    required String translationModel,

    /// Full path to the Silero model file: its name differs per language.
    required String ttsModel,
    required String speaker,
    required int threads,
    required double speed,
    required String pythonExecutable,
    required bool requiresWhisper,
    String sourceLanguage = autoSpokenLanguage,
    ComputeBackend recognitionBackend = ComputeBackend.cpu,
    ComputeBackend translationBackend = ComputeBackend.cpu,

    /// Target-language token some translation models want in front of the
    /// text; empty for the pairs that serve one language.
    String translationPrefix = '',

    /// Pick the voice per phrase from the gender of the original speaker.
    bool followSpeaker = false,
    List<String> maleVoices = const [],
    List<String> femaleVoices = const [],

    /// Where downloaded GPU runtimes live; needed by the CUDA backends.
    String? downloadedRuntimeDirectory,

    /// The OpenVoice converter directory, when each line is to be re-voiced
    /// in the timbre of the phrase it answers.
    String? voiceConverter,
    ComputeBackend voiceConversionBackend = ComputeBackend.cpu,

    /// The game's voice bank file, when the converter is to remember the
    /// characters it meets rather than take each line's timbre afresh.
    String? voiceBank,
  }) async {
    _workerReady = Completer<void>();
    _converterDevice = null;
    _diagnostics.clear();
    // A language the user named is used as is; anything else is detected once
    // on the first phrase and then reused.
    _spokenLanguage = sourceLanguage == autoSpokenLanguage ? null : sourceLanguage;
    if (!Platform.isWindows) throw const LoreDubFailure(FailureCode.windowsOnly);
    // Both binaries are validated before the caller ducks the game, so a
    // broken installation cannot look like a silently working pipeline.
    _whisperExecutable = requiresWhisper
        ? await resolveWhisperExecutable(
            backend: recognitionBackend,
            downloadedRuntimeDirectory: downloadedRuntimeDirectory,
          )
        : null;
    final python = await resolvePythonExecutable(pythonExecutable);
    final work = await createWorkDirectory();
    final workerFile = File(path.join(work.path, 'inference_worker.py'));
    final workerBytes = await rootBundle.load('assets/runtime/inference_worker.py');
    await workerFile.writeAsBytes(workerBytes.buffer.asUint8List(), flush: true);
    // The converter is a module the worker imports from its own directory.
    final converterFile = File(path.join(work.path, 'tone_converter.py'));
    final converterBytes = await rootBundle.load('assets/runtime/tone_converter.py');
    await converterFile.writeAsBytes(converterBytes.buffer.asUint8List(), flush: true);
    // The translator and the converter each ask for the CUDA build on their
    // own, and whichever does brings it in for both.
    final cudaTorch =
        translationBackend == ComputeBackend.cuda ||
        (voiceConverter != null && voiceConversionBackend == ComputeBackend.cuda);
    onStartupProgress?.call(0.05, 'python');
    _worker = await Process.start(
      python,
      [
        '-u',
        workerFile.path,
        '--translation-model',
        translationModel,
        '--tts-model',
        ttsModel,
        '--speaker',
        speaker,
        '--work-directory',
        work.path,
        '--threads',
        '$threads',
        '--speed',
        speed.toStringAsFixed(3),
        '--device',
        translationBackend == ComputeBackend.cuda ? 'cuda' : 'cpu',
        if (translationPrefix.isNotEmpty) ...['--translation-prefix', translationPrefix],
        if (followSpeaker) ...[
          '--follow-speaker',
          '--male-voices',
          maleVoices.join(','),
          '--female-voices',
          femaleVoices.join(','),
        ],
        // CUDA torch is installed beside the models rather than over the
        // bundled CPU build, so the worker is told where to find it.
        if (cudaTorch && downloadedRuntimeDirectory != null) ...[
          '--extra-packages',
          path.join(downloadedRuntimeDirectory, torchCudaRuntimeId),
        ],
        if (voiceConverter != null) ...[
          '--voice-converter',
          voiceConverter,
          '--converter-device',
          voiceConversionBackend == ComputeBackend.cuda ? 'cuda' : 'cpu',
          if (voiceBank != null) ...['--voice-bank', voiceBank],
        ],
      ],
      environment: const {'PYTHONIOENCODING': 'utf-8'},
    );
    // IOSink defaults to the system encoding, which would corrupt any
    // non-ASCII phrase on the way into the worker.
    _worker!.stdin.encoding = utf8;
    _stdoutSubscription = decodeWorkerLines(_worker!.stdout).listen(_handleWorkerLine);
    _stderrSubscription = decodeWorkerLines(_worker!.stderr).listen((line) {
      _diagnostics.add(line);
      stderr.writeln('[inference] $line');
    });
    unawaited(
      _worker!.exitCode.then((code) {
        final error = _diagnostics.describeExit(code);
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
        _translationDevice = message['device'] as String?;
        _converterDevice = message['converterDevice'] as String?;
        if (!(_workerReady?.isCompleted ?? true)) _workerReady!.complete();
        return;
      }
      if (message['type'] == 'progress') {
        onStartupProgress?.call(
          (message['value']! as num).toDouble(),
          message['stage'] as String? ?? '',
        );
        return;
      }
      final id = message['id'] as int?;
      if (id != null) _pending.remove(id)?.complete(message);
    } catch (error) {
      // Keep the offending line: a reply nobody can parse would otherwise only
      // show up as a request timeout two minutes later.
      _diagnostics.add('unreadable worker reply: $line');
      stderr.writeln('[inference] invalid worker response: $error');
    }
  }

  Future<InferenceResult?> processSegment({
    required String wavePath,

    /// Full path to the ggml model file, which the user chooses.
    required String whisperModel,
    required int threads,

    /// Whether to ask whisper for English rather than the spoken language.
    /// `large-v3-turbo` was fine-tuned without translation data, so it is
    /// asked to transcribe and only suits an original already in English.
    bool translateSpeech = true,
  }) async {
    final whisper = _whisperExecutable ?? await resolveWhisperExecutable();
    final model = whisperModel;
    if (!await File(model).exists()) {
      throw LoreDubFailure(FailureCode.whisperModelMissing, detail: model);
    }
    final prefix = path.withoutExtension(wavePath);
    final detecting = _spokenLanguage == null;
    final recognition = await Process.run(whisper, [
      '-m',
      model,
      '-f',
      wavePath,
      '-l',
      _spokenLanguage ?? 'auto',
      if (translateSpeech) '-tr',
      '-otxt',
      '-of',
      prefix,
      '-t',
      '$threads',
      // The detection line is only printed while whisper is allowed to print.
      if (!detecting) '-np',
    ]);
    if (recognition.exitCode != 0) {
      throw LoreDubFailure(FailureCode.whisperFailed, detail: '${recognition.stderr}');
    }
    if (detecting) {
      _spokenLanguage = parseDetectedLanguage('${recognition.stderr}${recognition.stdout}');
    }
    final outputFile = File('$prefix.txt');
    if (!await outputFile.exists()) return null;
    final english = (await outputFile.readAsString()).trim();
    await outputFile.delete();
    if (english.isEmpty || RegExp(r'^\[.*\]$').hasMatch(english)) return null;

    // The captured audio is still on disk here: the worker reads its pitch to
    // decide whose voice to answer in.
    return processText(english, originalWavePath: wavePath);
  }

  /// [originalWavePath] is the captured phrase, when there is one. The
  /// worker reads its pitch to follow the speaker; OCR mode has no audio and
  /// passes nothing.
  Future<InferenceResult> processText(String english, {String? originalWavePath}) async {
    final normalized = english.trim();
    if (normalized.isEmpty) throw ArgumentError.value(english, 'english', 'is empty');

    final worker = _worker;
    if (worker == null) throw const LoreDubFailure(FailureCode.workerNotRunning);

    final id = ++_requestId;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    worker.stdin.writeln(
      jsonEncode({
        'id': id,
        'text': normalized,
        'wave': ?originalWavePath,
      }),
    );
    final response = await completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        _pending.remove(id);
        throw LoreDubFailure(
          FailureCode.workerTimeout,
          detail: _diagnostics.isEmpty ? null : _diagnostics.recentOutput,
        );
      },
    );
    if (response['error'] case final String error) {
      throw LoreDubFailure(FailureCode.workerFailed, detail: error);
    }
    return InferenceResult(
      english: normalized,
      translated: response['translated']! as String,
      wavePath: response['wave']! as String,
      voice: response['voice'] as String? ?? '',
      bankSize: (response['bankSize'] as num?)?.toInt(),
    );
  }

  Future<void> stop() async {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(const LoreDubFailure(FailureCode.pipelineStopped));
      }
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

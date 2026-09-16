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
import '../../domain/sound_captions.dart';
import '../../domain/spoken_language.dart';
import '../../domain/built_voice.dart';
import '../../domain/failure.dart';
import '../../domain/glossary.dart';
import 'runtime_catalog.dart';

class InferenceResult {
  const InferenceResult({
    required this.english,
    required this.translated,
    required this.wavePath,
    this.voice = '',
    this.bankSize,
    this.speaker,
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

  /// Who is speaking, as a key only compared for equality: the matched voice
  /// with the original voice on, the Silero voice otherwise. Null when the
  /// worker cannot tell.
  final String? speaker;
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

  /// Where the worker put the speech model, or null when it loaded none.
  String? _speechDevice;
  ComputeBackend? get speechBackend => _backendOf(_speechDevice);

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
    /// Empty with [embedOnly], which loads neither.
    String translationModel = '',

    /// Full path to the Silero model file: its name differs per language.
    String ttsModel = '',

    /// Load the voice converter and nothing else: the characters screen
    /// measures a voice without waiting a minute for Marian and Silero.
    bool embedOnly = false,

    /// Load the speech model and the converter without the translator: a
    /// sample of a voice speaks a line the application already wrote.
    bool speechOnly = false,
    String speaker = '',
    required int threads,
    required double speed,
    required String pythonExecutable,
    required bool requiresWhisper,
    String sourceLanguage = autoSpokenLanguage,
    ComputeBackend recognitionBackend = ComputeBackend.cpu,
    ComputeBackend translationBackend = ComputeBackend.cpu,

    /// Where the voice reads. Its own answer rather than the translator's,
    /// and the one stage a card barely changes: some 30 ms off a line, paid
    /// for with a second of the session's start.
    ComputeBackend speechBackend = ComputeBackend.cpu,

    /// Target-language token some translation models want in front of the
    /// text; empty for the pairs that serve one language.
    String translationPrefix = '',

    /// Pick the voice per phrase from the gender of the original speaker.
    bool followSpeaker = false,

    /// Carry the original's timbre onto the voice. Without it a loaded
    /// converter only tells the characters apart.
    bool revoice = false,
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

    /// The characters the player recorded and named, which belong to every
    /// game rather than one.
    String? characters,

    /// What the player wrote down about their games: the names the model
    /// leaves in Latin script and the sentences they have translated
    /// themselves. One file for every game, as the cast is.
    String? glossary,

    /// The cards cut out of the mix on the graph, by id. Each of them is
    /// read as it is heard: it lends its voice to nobody, and nobody stands
    /// in for it, though what the cards say waits in them.
    Set<String> asHeard = const {},
  }) async {
    // A worker left over from a session that was not stopped would go on
    // holding its models — and its share of a graphics card — with the
    // handle to it about to be overwritten and nobody left to end it.
    if (_worker != null) await stop();
    _workerReady = Completer<void>();
    _speechDevice = null;
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
    final workerFile = await _extractScript('assets/runtime/inference_worker.py', work);
    // The converter is a module the worker imports from its own directory.
    await _extractScript('assets/runtime/tone_converter.py', work);
    // The translator, the voice and the converter each ask for the CUDA build
    // on their own, and whichever does brings it in for all three.
    final cudaTorch =
        translationBackend == ComputeBackend.cuda ||
        (ttsModel.isNotEmpty && speechBackend == ComputeBackend.cuda) ||
        (voiceConverter != null && voiceConversionBackend == ComputeBackend.cuda);
    onStartupProgress?.call(0.05, 'python');
    _worker = await Process.start(
      python,
      [
        '-u',
        workerFile.path,
        if (embedOnly) '--embed-only',
        if (speechOnly) '--speech-only',
        if (translationModel.isNotEmpty) ...['--translation-model', translationModel],
        if (ttsModel.isNotEmpty) ...[
          '--tts-model',
          ttsModel,
          '--speech-device',
          speechBackend == ComputeBackend.cuda ? 'cuda' : 'cpu',
        ],
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
        // Outside the converter's own arguments: what the player wrote down
        // is read whether or not the original voice is carried over, and
        // nesting it there left a session without the original voice with no
        // glossary at all until the next entry was written.
        if (glossary != null) ...['--glossary', glossary],
        if (voiceConverter != null) ...[
          '--voice-converter',
          voiceConverter,
          '--converter-device',
          voiceConversionBackend == ComputeBackend.cuda ? 'cuda' : 'cpu',
          if (revoice) '--revoice',
          if (voiceBank != null) ...['--voice-bank', voiceBank],
          if (characters != null) ...['--characters', characters],
          if (asHeard.isNotEmpty) ...['--as-heard', asHeard.join(',')],
        ],
      ],
      environment: const {'PYTHONIOENCODING': 'utf-8'},
    );
    _listenTo(_worker!, _workerReady!);
    // Loading Marian and Silero is minutes on a cold machine; past that, the
    // worker is not coming up at all.
    await _workerReady!.future.timeout(const Duration(minutes: 5));
  }

  /// Copies one of the bundled runtime scripts into the work directory,
  /// where the interpreter can reach it, and answers with what it wrote.
  static Future<File> _extractScript(String asset, Directory work) async {
    final file = File(path.join(work.path, path.basename(asset)));
    final bytes = await rootBundle.load(asset);
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return file;
  }

  /// Reads what [worker] says and answers [ready] when it has started — or
  /// fails it, and every request in flight, if the worker dies first.
  ///
  /// The worker and the start are named rather than read from the fields. A
  /// stop kills the process and returns before Windows has finished with it,
  /// so for a moment two workers exist: the one being taken down and the one
  /// the next screen is starting. Unnamed, the dead one's exit code failed
  /// the live one's start — and that start is the minutes-long one, so a
  /// session begun after listening to a card gave "the worker exited with -1
  /// and said nothing" every time.
  void _listenTo(Process worker, Completer<void> ready) {
    // IOSink defaults to the system encoding, which would corrupt any
    // non-ASCII phrase on the way into the worker.
    worker.stdin.encoding = utf8;
    _stdoutSubscription = decodeWorkerLines(worker.stdout).listen(_handleWorkerLine);
    _stderrSubscription = decodeWorkerLines(worker.stderr).listen((line) {
      _diagnostics.add(line);
      stderr.writeln('[inference] $line');
    });
    unawaited(worker.exitCode.then((code) => _onWorkerExit(worker, ready, code)));
  }

  /// The worker is gone. Whoever was waiting on it is told why, unless it is
  /// a worker this service has already replaced.
  void _onWorkerExit(Process worker, Completer<void> ready, int code) {
    if (!identical(_worker, worker)) return;
    final error = _diagnostics.describeExit(code);
    if (!ready.isCompleted) ready.completeError(error);
    for (final request in _pending.values) {
      if (!request.isCompleted) request.completeError(error);
    }
    _pending.clear();
  }

  /// One line the worker wrote: its handshake, a step of its startup, or
  /// the answer to a request somebody is waiting for.
  void _handleWorkerLine(String line) {
    try {
      final message = jsonDecode(line) as Map<String, Object?>;
      switch (message['type']) {
        case 'ready':
          _onWorkerReady(message);
        case 'progress':
          onStartupProgress?.call(
            (message['value']! as num).toDouble(),
            message['stage'] as String? ?? '',
          );
        default:
          _answerRequest(message);
      }
    } catch (error) {
      // Keep the offending line: a reply nobody can parse would otherwise only
      // show up as a request timeout two minutes later.
      _diagnostics.add('unreadable worker reply: $line');
      stderr.writeln('[inference] invalid worker response: $error');
    }
  }

  /// The worker has loaded its models and says where it put them.
  void _onWorkerReady(Map<String, Object?> message) {
    _translationDevice = message['device'] as String?;
    _speechDevice = message['speechDevice'] as String?;
    _converterDevice = message['converterDevice'] as String?;
    final ready = _workerReady;
    if (ready != null && !ready.isCompleted) ready.complete();
  }

  /// Hands a reply to whoever asked for it. A line carrying no request id
  /// answers nobody and is passed over.
  void _answerRequest(Map<String, Object?> message) {
    if (message['id'] case final int id) _pending.remove(id)?.complete(message);
  }

  /// The audio context `-ac` is given when recognition is asked to hurry.
  ///
  /// Measured over nine clips of a recording, against the full window: 1000
  /// took 897 ms rather than 1329 and said the same words on all nine, two of
  /// them differing only by a comma. Below it the answers start to drift --
  /// 768 turned "struggling to reconcile" into "struggling the reconciled" --
  /// and at 512 whisper began repeating a phrase back to itself, which would
  /// then be translated and voiced. Measure again before moving it.
  static const _shortenedAudioContext = 1000;

  Future<InferenceResult?> processSegment({
    required String wavePath,

    /// Full path to the ggml model file, which the user chooses.
    required String whisperModel,
    required int threads,

    /// Whether to ask whisper for English rather than the spoken language.
    /// `large-v3-turbo` was fine-tuned without translation data, so it is
    /// asked to transcribe and only suits an original already in English.
    bool translateSpeech = true,

    /// The pace to read this one line at, when the queue asks for more than
    /// the session's own.
    double? speed,

    /// Whether what whisper heard still has to be translated. Dubbing into
    /// English does not: whisper was asked for English and handed it over.
    bool translate = true,

    /// Whether to shorten the stretch of sound whisper listens over, which
    /// is where nearly all of the recognition time goes.
    bool roughRecognition = false,
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
      if (roughRecognition) ...['-ac', '$_shortenedAudioContext'],
      // Music and noise would otherwise come back as "(soft music)" or
      // "[Music]" — captions whisper learned from subtitles — and be voiced.
      '-sns',
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
    // `-sns` keeps most captions out; what still comes back as "(soft music)"
    // or "[BLANK_AUDIO]" has nothing to translate once it is taken out.
    final english = withoutSoundCaptions(await outputFile.readAsString());
    await outputFile.delete();
    if (english.isEmpty) return null;

    // The captured audio is still on disk here: the worker reads its pitch to
    // decide whose voice to answer in.
    return processText(english, originalWavePath: wavePath, speed: speed, translate: translate);
  }

  /// The voice in [wavePath], as a character's card keeps it: the
  /// fingerprint, the gender it was heard as, and how long it ran.
  Future<({List<double> vector, String? gender, double seconds})> fingerprint(
    String wavePath,
  ) async {
    final worker = _worker;
    if (worker == null) throw const LoreDubFailure(FailureCode.workerNotRunning);

    final id = ++_requestId;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    worker.stdin.writeln(jsonEncode({'id': id, 'fingerprint': wavePath}));
    final response = await completer.future.timeout(
      const Duration(seconds: 30),
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
    return (
      vector: [
        for (final value in response['vector'] as List<Object?>? ?? const [])
          if (value is num) value.toDouble(),
      ],
      gender: response['gender'] as String?,
      seconds: (response['seconds'] as num?)?.toDouble() ?? 0,
    );
  }

  /// One fingerprint for a character, measured from every recording in
  /// [wavePaths] at once.
  ///
  /// The worker averages them, which is what makes a card built from files
  /// steadier than one built from a single line, and says how well they
  /// agreed so the player can see they were one voice.
  Future<BuiltVoice> buildVoice(List<String> wavePaths) async {
    final worker = _worker;
    if (worker == null) throw const LoreDubFailure(FailureCode.workerNotRunning);

    final id = ++_requestId;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    worker.stdin.writeln(jsonEncode({'id': id, 'voiceFrom': wavePaths}));
    // The converter runs once per file; a folder of them is a wait, not a
    // moment, and a card the player is watching must not give up first.
    final response = await completer.future.timeout(
      Duration(seconds: 30 + 15 * wavePaths.length),
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
    return BuiltVoice.fromJson(response);
  }

  /// A sample of [voice], in [timbre] when one is given and the converter
  /// is loaded. Answers with the file it wrote, for the caller to play.
  Future<String> previewVoice({
    required String text,
    required String voice,
    List<double> timbre = const [],
  }) async {
    final worker = _worker;
    if (worker == null) throw const LoreDubFailure(FailureCode.workerNotRunning);

    final id = ++_requestId;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    worker.stdin.writeln(
      jsonEncode({
        'id': id,
        'preview': {'text': text, 'voice': voice, if (timbre.isNotEmpty) 'vector': timbre},
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
    return response['wave']! as String;
  }

  /// The seconds at which the voice in [wavePath] changes, so the caller can
  /// cut the recording there and have each speaker recognized and voiced on
  /// their own. Empty when the worker has no converter to hear them with.
  Future<List<double>> speakerCuts(String wavePath) async {
    final worker = _worker;
    if (worker == null) throw const LoreDubFailure(FailureCode.workerNotRunning);

    final id = ++_requestId;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    worker.stdin.writeln(jsonEncode({'id': id, 'diarize': wavePath}));
    final response = await completer.future.timeout(
      const Duration(seconds: 30),
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
    return [
      for (final cut in response['cuts'] as List<Object?>? ?? const [])
        if (cut is num) cut.toDouble(),
    ];
  }

  /// Who is speaking in [wavePath], without recognizing or voicing a word.
  ///
  /// This is what the voices of a scene are gathered with before dubbing
  /// starts: only the converter is loaded, and a voice it has not met joins
  /// the game's bank here exactly as it would during a session.
  Future<({String? speaker, double seconds})> listenSpeaker(String wavePath) async {
    final worker = _worker;
    if (worker == null) throw const LoreDubFailure(FailureCode.workerNotRunning);

    final id = ++_requestId;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    worker.stdin.writeln(jsonEncode({'id': id, 'listen': wavePath}));
    final response = await completer.future.timeout(
      const Duration(seconds: 30),
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
    return (
      speaker: response['speaker'] as String?,
      seconds: (response['seconds'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Reads every voice as itself from now on, or lets the cast stand in
  /// again: the branch from the cast into the mix, cut or drawn on the graph
  /// while the session runs.
  ///
  /// The cards keep who stands in for whom either way; this is only whether
  /// any of it is applied.
  /// Hands a running worker what the player has just written down.
  ///
  /// The same shape the file holds, so the worker reads it with the parser
  /// it already has. Sent whether or not the worker translates: one that
  /// does not simply keeps it unread.
  Future<void> updateGlossary(Glossary glossary) async {
    final worker = _worker;
    if (worker == null) return;

    final id = ++_requestId;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    worker.stdin.writeln(jsonEncode({'id': id, 'glossary': glossary.toJson()}));
    final response = await completer.future.timeout(
      const Duration(seconds: 10),
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
  }

  Future<void> readAsHeard(Set<String> value) async {
    final worker = _worker;
    if (worker == null) return;

    final id = ++_requestId;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    worker.stdin.writeln(
      jsonEncode({
        'id': id,
        'asHeard': [...value],
      }),
    );
    final response = await completer.future.timeout(
      const Duration(seconds: 10),
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
  }

  /// Reads [character] in [target]'s voice wherever they are recognized, as
  /// their card now says, or in their own again when [target] is null.
  ///
  /// The cast is read from its file when a session starts, so this is what
  /// carries an edit made meanwhile into the session already running.
  Future<void> voiceCharacterAs(String character, String? target) async {
    final worker = _worker;
    if (worker == null) return;

    final id = ++_requestId;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    worker.stdin.writeln(
      jsonEncode({
        'id': id,
        'voicedBy': {'character': character, 'target': target ?? ''},
      }),
    );
    final response = await completer.future.timeout(
      const Duration(seconds: 10),
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
  }

  /// [originalWavePath] is the captured phrase, when there is one. The
  /// worker reads its pitch to follow the speaker; OCR mode has no audio and
  /// passes nothing. Without [translate] the text is already in the dubbing
  /// language and is voiced as it is.
  Future<InferenceResult> processText(
    String english, {
    String? originalWavePath,
    bool translate = true,

    /// Read at this pace instead of the session's, when lines are waiting
    /// for the voice. The worker retimes the waveform it synthesized.
    double? speed,
  }) async {
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
        'speed': ?speed,
        if (!translate) 'translate': false,
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
      speaker: response['speaker'] as String?,
    );
  }

  Future<void> stop() async {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(const LoreDubFailure(FailureCode.pipelineStopped));
      }
    }
    _pending.clear();
    final worker = _worker;
    // Cleared before the process is waited on: whatever else asks for the
    // worker while it dies must be told there is none, not handed the one
    // on its way out.
    _worker = null;
    _workerReady = null;
    await worker?.stdin.close();
    worker?.kill();
    // Waited for, so the next worker starts on a machine this one has
    // finished with: the extracted script, the work directory and the
    // models it holds are all things two of them would share.
    await worker?.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () => -1,
    );
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
  }
}

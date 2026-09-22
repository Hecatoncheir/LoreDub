// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../domain/compute_device.dart';
import 'runtime_paths.dart';
import '../../domain/sound_captions.dart';
import '../../domain/spoken_language.dart';
import '../../domain/built_voice.dart';
import '../../domain/failure.dart';
import '../../domain/glossary.dart';
import 'worker_channel.dart';
import 'worker_arguments.dart';
import '../../domain/session_config.dart';
import 'whisper_runner.dart';
import 'process_launcher.dart';

class InferenceResult {
  const InferenceResult({
    required this.english,
    required this.translated,
    required this.wavePath,
    this.voice = '',
    this.bankSize,
    this.speaker,
    this.silenced = false,
  });

  final String english;
  final String translated;

  /// Null for a line that was passed over: there is nothing to play.
  final String? wavePath;

  /// Whether the player silenced this line in the glossary. It is still
  /// recognized and still shown -- what is missing is the voice.
  final bool silenced;

  /// The voice that read the line, which the automatic choice can change
  /// from phrase to phrase.
  final String voice;

  /// How many voices the game's bank holds after this line, or null when
  /// the session keeps none.
  final int? bankSize;

  /// Who is speaking, as a key only compared for equality: the matched voice
  /// with the original voice on, the Vosk voice otherwise. Null when the
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

/// What a start asks of the machine before the interpreter runs: both
/// binaries found, and the worker's script written out where it can be run.
typedef WorkerFiles = ({String python, String script, String work, String? whisper});
typedef WorkerPreparation = Future<WorkerFiles> Function({
  required String pythonExecutable,
  required bool requiresWhisper,
  required ComputeBackend recognitionBackend,
  String? downloadedRuntimeDirectory,
});

class LocalInferenceService {
  LocalInferenceService({
    WorkerPreparation? prepare,
    ProcessLauncher? startWorker,
    WhisperRunner? whisper,
    this.startupLimit = const Duration(minutes: 5),
  }) : _prepare = prepare ?? _prepareOnThisMachine,
       _startWorker = startWorker ?? _startInterpreter,
       _whisper = whisper ?? WhisperRunner();

  final WorkerPreparation _prepare;
  final ProcessLauncher _startWorker;
  final WhisperRunner _whisper;

  /// Loading Marian and Vosk is minutes on a cold machine; past this, the
  /// worker is not coming up at all.
  final Duration startupLimit;

  Process? _worker;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  final _diagnostics = WorkerDiagnostics();
  late final _channel = WorkerChannel(
    lastWords: () => _diagnostics.isEmpty ? null : _diagnostics.recentOutput,
  );
  Completer<void>? _workerReady;
  String? _whisperExecutable;

  /// Goes up with every start and every stop, so that a start coming back
  /// from one of its waits can tell whether it is still the one wanted.
  ///
  /// Starting is minutes of waiting, and the button that starts a session
  /// also cancels a start in progress. A stop that landed in one of those
  /// waits found nothing it could end: the start carried on into fields the
  /// stop had cleared, and either left a worker running that nobody held or
  /// sat out the whole of [startupLimit] — to fail then into whichever
  /// session was running by that time.
  var _generation = 0;

  /// Detected once per session and reused; null means detection is still due.
  String? _spokenLanguage;

  /// Reports how far the worker is through its startup, which takes long
  /// enough that the application must not look frozen while it happens.
  void Function(double value, String stage)? onStartupProgress;

  /// Told when a worker that had started dies on its own, with the reason
  /// it gave. Nothing can be dubbed from then on, so whoever holds the
  /// session is expected to end it rather than let phrases pile up.
  void Function(LoreDubFailure failure)? onWorkerLost;

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

  /// Brings up the worker [plan] describes, loading what [load] says of it.
  /// [requiresWhisper] has the recognition binary found and checked too.
  Future<void> start(
    WorkerPlan plan, {
    bool requiresWhisper = false,
    WorkerLoad load = WorkerLoad.full,
  }) async {
    // Named before anything is waited for: each wait below is somewhere a
    // stop can land, and the start asks after every one of them whether it
    // is still wanted. What it waited for stays in locals until then, so a
    // start already replaced writes nothing over the one that replaced it.
    final generation = ++_generation;
    // A worker left over from a session that was not stopped would go on
    // holding its models — and its share of a graphics card — with the
    // handle to it about to be overwritten and nobody left to end it.
    if (_worker != null) await _endWorker();
    _throwIfSuperseded(generation);
    _speechDevice = null;
    _converterDevice = null;
    _diagnostics.clear();
    // A language the user named is used as is; anything else is detected once
    // on the first phrase and then reused.
    _spokenLanguage = plan.sourceLanguage == autoSpokenLanguage ? null : plan.sourceLanguage;
    // Both binaries are validated before the caller ducks the game, so a
    // broken installation cannot look like a silently working pipeline.
    final files = await _prepare(
      pythonExecutable: plan.pythonExecutable,
      requiresWhisper: requiresWhisper,
      recognitionBackend: plan.backends.recognition,
      downloadedRuntimeDirectory: plan.runtimeDirectory,
    );
    _throwIfSuperseded(generation);
    _whisperExecutable = files.whisper;
    onStartupProgress?.call(0.05, 'python');
    final worker = await _startWorker(
      files.python,
      workerArguments(plan, script: files.script, work: files.work, load: load),
    );
    if (generation != _generation) {
      // Stopped while the interpreter was coming up. The stop found no
      // worker to end, so this one is ended here, where it is still held.
      _discard(worker);
      throw const LoreDubFailure(FailureCode.pipelineStopped);
    }
    // Made only now, with nothing waited for before it is listened to: a
    // stop fails it, and a failure nobody hears is an error of its own.
    final ready = Completer<void>();
    _worker = worker;
    _workerReady = ready;
    _listenTo(worker, ready);
    try {
      await ready.future.timeout(startupLimit);
    } on TimeoutException {
      final said = _diagnostics.isEmpty ? null : _diagnostics.recentOutput;
      // Given up on, it would go on loading — and holding what it loaded —
      // with nobody left to end it.
      await _endWorker();
      throw LoreDubFailure(FailureCode.workerStartTimeout, detail: said);
    }
    _throwIfSuperseded(generation);
  }

  /// A start that was stopped, or replaced by a later one, ends here: what
  /// it was waiting for came back to nobody.
  void _throwIfSuperseded(int generation) {
    if (generation != _generation) throw const LoreDubFailure(FailureCode.pipelineStopped);
  }

  /// Ends a worker nobody is going to talk to. What it printed is read to
  /// the end and dropped: unread, it keeps the pipes of a dead process open.
  static void _discard(Process worker) {
    worker.kill();
    worker.stdout.drain<void>().ignore();
    worker.stderr.drain<void>().ignore();
  }

  /// The real [WorkerPreparation]. The work directory is the application's
  /// own and the scripts come out of its bundle, neither of which a test has.
  static Future<WorkerFiles> _prepareOnThisMachine({
    required String pythonExecutable,
    required bool requiresWhisper,
    required ComputeBackend recognitionBackend,
    String? downloadedRuntimeDirectory,
  }) async {
    if (!Platform.isWindows) throw const LoreDubFailure(FailureCode.windowsOnly);
    final whisper = requiresWhisper
        ? await resolveWhisperExecutable(
            backend: recognitionBackend,
            downloadedRuntimeDirectory: downloadedRuntimeDirectory,
          )
        : null;
    final python = await resolvePythonExecutable(pythonExecutable);
    final work = await createWorkDirectory();
    final script = await _extractScript('assets/runtime/inference_worker.py', work);
    // The converter and the voices are modules the worker imports from its
    // own directory. Both voices travel whichever language the session dubs
    // into: which one is loaded is decided there, off the package on disk.
    await _extractScript('assets/runtime/tone_converter.py', work);
    await _extractScript('assets/runtime/onnx_speech.py', work);
    await _extractScript('assets/runtime/vosk_voice.py', work);
    await _extractScript('assets/runtime/kokoro_voice.py', work);
    await _extractScript('assets/runtime/english_g2p.py', work);
    return (python: python, script: script.path, work: work.path, whisper: whisper);
  }

  /// The real [ProcessLauncher].
  static Future<Process> _startInterpreter(String executable, List<String> arguments) =>
      Process.start(executable, arguments, environment: const {'PYTHONIOENCODING': 'utf-8'});

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
    _stdoutSubscription = decodeWorkerLines(worker.stdout).listen((line) {
      // A worker on its way out can still get a line in, and it answers for
      // nobody: its handshake would end the start of the one replacing it.
      if (identical(_worker, worker)) _handleWorkerLine(line);
    });
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
    // Let go of, so the next phrase is told there is no worker. Left in
    // place it was written into a pipe nobody reads, and every phrase after
    // it waited out its two minutes while the queue behind them grew.
    _worker = null;
    _workerReady = null;
    final starting = !ready.isCompleted;
    if (starting) ready.completeError(error);
    _channel.failAll(error);
    // A start still waiting has just been told, and fails with the reason.
    // A session already running has nobody waiting on the worker as a whole.
    if (!starting) onWorkerLost?.call(error);
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
          _channel.answer(message);
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
    final recognition = await _whisper.run(whisper, [
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
      throw LoreDubFailure(FailureCode.whisperFailed, detail: recognition.stderr);
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
    final response = await _ask({'fingerprint': wavePath}, timeout: const Duration(seconds: 30));
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
    // The converter runs once per file; a folder of them is a wait, not a
    // moment, and a card the player is watching must not give up first.
    final response = await _ask({
      'voiceFrom': wavePaths,
    }, timeout: Duration(seconds: 30 + 15 * wavePaths.length));
    return BuiltVoice.fromJson(response);
  }

  /// A sample of [voice], in [timbre] when one is given and the converter
  /// is loaded. Answers with the file it wrote, for the caller to play.
  Future<String> previewVoice({
    required String text,
    required String voice,
    List<double> timbre = const [],
  }) async {
    final response = await _ask({
      'preview': {'text': text, 'voice': voice, if (timbre.isNotEmpty) 'vector': timbre},
    }, timeout: const Duration(minutes: 2));
    return response['wave']! as String;
  }

  /// The seconds at which the voice in [wavePath] changes, so the caller can
  /// cut the recording there and have each speaker recognized and voiced on
  /// their own. Empty when the worker has no converter to hear them with.
  Future<List<double>> speakerCuts(String wavePath) async {
    final response = await _ask({'diarize': wavePath}, timeout: const Duration(seconds: 30));
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
    final response = await _ask({'listen': wavePath}, timeout: const Duration(seconds: 30));
    return (
      speaker: response['speaker'] as String?,
      seconds: (response['seconds'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Hands a running worker what the player has just written down.
  ///
  /// The same shape the file holds, so the worker reads it with the parser
  /// it already has. Sent whether or not the worker translates: one that
  /// does not simply keeps it unread.
  Future<void> updateGlossary(Glossary glossary) => _tell({'glossary': glossary.toJson()});

  /// Reads every voice as itself from now on, or lets the cast stand in
  /// again: the branch from the cast into the mix, cut or drawn on the graph
  /// while the session runs.
  ///
  /// The cards keep who stands in for whom either way; this is only whether
  /// any of it is applied.
  Future<void> readAsHeard(Set<String> value) => _tell({
    'asHeard': [...value],
  });

  /// Reads the lines that follow in [voice], which is what the picker on
  /// the settings and screen pages changes while a session runs.
  ///
  /// The voice is given to the worker when it starts, so this is what
  /// carries a change made meanwhile: the next line is read in it rather
  /// than the next session.
  Future<void> useVoice(String voice) => _tell({'speaker': voice});

  /// Reads [character] in [target]'s voice wherever they are recognized, as
  /// their card now says, or in their own again when [target] is null.
  ///
  /// The cast is read from its file when a session starts, so this is what
  /// carries an edit made meanwhile into the session already running.
  Future<void> voiceCharacterAs(String character, String? target) => _tell({
    'voicedBy': {'character': character, 'target': target ?? ''},
  });

  /// Asks the running worker for something only it can answer, failing as
  /// `workerNotRunning` when there is none to ask.
  Future<Map<String, Object?>> _ask(Map<String, Object?> body, {required Duration timeout}) async {
    final worker = _worker;
    if (worker == null) throw const LoreDubFailure(FailureCode.workerNotRunning);
    return _channel.request(worker.stdin, body, timeout: timeout);
  }

  /// Tells a running worker something that changes how it reads from now
  /// on. With no worker there is nobody to tell: the next session reads the
  /// same thing from its files when it starts.
  Future<void> _tell(Map<String, Object?> body) async {
    final worker = _worker;
    if (worker == null) return;
    await _channel.request(worker.stdin, body, timeout: const Duration(seconds: 10));
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

    final response = await _ask({
      'text': normalized,
      'wave': ?originalWavePath,
      'speed': ?speed,
      if (!translate) 'translate': false,
    }, timeout: const Duration(minutes: 2));
    final silenced = response['silenced'] == true;
    return InferenceResult(
      english: normalized,
      translated: response['translated']! as String,
      silenced: silenced,
      wavePath: silenced ? null : response['wave']! as String,
      voice: response['voice'] as String? ?? '',
      bankSize: (response['bankSize'] as num?)?.toInt(),
      speaker: response['speaker'] as String?,
    );
  }

  Future<void> stop() {
    // Whichever start is still in one of its waits is no longer wanted, and
    // finds that out when it comes back from it.
    _generation++;
    // The phrase being recognized belongs to the session that is ending.
    _whisper.cancel();
    return _endWorker();
  }

  /// Fails whoever is waiting on the worker and takes it down. A start does
  /// this to the worker it replaces, which is not a stop of the start itself.
  Future<void> _endWorker() async {
    const stopped = LoreDubFailure(FailureCode.pipelineStopped);
    _channel.failAll(stopped);
    // A start waiting for the handshake is told now. Left unanswered it sat
    // out the whole startup limit: the exit of a worker already let go of is
    // nobody's, so nothing else was ever going to end that wait.
    final ready = _workerReady;
    if (ready != null && !ready.isCompleted) ready.completeError(stopped);
    final worker = _worker;
    final listening = [_stdoutSubscription, _stderrSubscription];
    // Cleared before the process is waited on: whatever else asks for the
    // worker while it dies must be told there is none, not handed the one
    // on its way out. The subscriptions with it — the next start may be
    // listening to its own worker by the time this one has died, and those
    // are not this call's to cancel.
    _worker = null;
    _workerReady = null;
    _stdoutSubscription = null;
    _stderrSubscription = null;
    await worker?.stdin.close();
    worker?.kill();
    // Waited for, so the next worker starts on a machine this one has
    // finished with: the extracted script, the work directory and the
    // models it holds are all things two of them would share.
    await worker?.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () => -1,
    );
    for (final subscription in listening) {
      await subscription?.cancel();
    }
  }
}

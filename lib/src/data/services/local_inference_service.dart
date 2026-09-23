// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
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
import 'worker_arguments.dart';
import '../../domain/session_config.dart';
import 'whisper_runner.dart';
import 'process_launcher.dart';
import 'worker_process.dart';

export 'worker_process.dart' show WorkerDiagnostics, decodeWorkerLines;

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

/// What a start asks of the machine before the interpreter runs: the
/// binaries found -- whisper's where the session recognizes, llama.cpp's
/// where its translator is a language model -- and the worker's script
/// written out where it can be run.
typedef WorkerFiles = ({
  String python,
  String script,
  String work,
  String? whisper,
  String? llama,
});
typedef WorkerPreparation = Future<WorkerFiles> Function({
  required String pythonExecutable,
  required bool requiresWhisper,
  required ComputeBackend recognitionBackend,
  ComputeBackend? languageModelBackend,
  String? downloadedRuntimeDirectory,
});

/// The worker's scripts among the application's [assets]: every Python file
/// in `assets/runtime/`, the worker and what it imports alike.
Iterable<String> workerScripts(Iterable<String> assets) => assets.where(
  (asset) => asset.startsWith('assets/runtime/') && asset.endsWith('.py'),
);

/// The clips a voice that clones reads its fixed voices from, with their
/// transcripts beside them: everything under `assets/runtime/references/`.
Iterable<String> workerReferences(Iterable<String> assets) =>
    assets.where((asset) => asset.startsWith('assets/runtime/references/'));

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

  /// The worker up or coming up, or null when there is none.
  WorkerProcess? _worker;
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
    'vulkan' => ComputeBackend.vulkan,
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
        if (entry is File && _isSessionAudio(entry)) await _deleteIfFree(entry);
      }
    }
  }

  /// A phrase the worker spoke or a segment the capture wrote; nothing else
  /// in the directory is the pipeline's to throw away.
  static bool _isSessionAudio(File file) {
    final name = path.basename(file.path);
    if (!name.endsWith('.wav')) return false;
    return name.startsWith('speech-') || name.startsWith('segment-');
  }

  static Future<void> _deleteIfFree(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // Best effort: a file still held by playback is removed next time.
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
    // A language the user named is used as is; anything else is detected once
    // on the first phrase and then reused.
    _spokenLanguage = plan.sourceLanguage == autoSpokenLanguage ? null : plan.sourceLanguage;
    // Both binaries are validated before the caller ducks the game, so a
    // broken installation cannot look like a silently working pipeline.
    final files = await _prepare(
      pythonExecutable: plan.pythonExecutable,
      requiresWhisper: requiresWhisper,
      recognitionBackend: plan.backends.recognition,
      // The worker starts llama.cpp's server itself, so the build is looked
      // for here, where a missing one is reported before the minute of
      // loading rather than at the end of it.
      languageModelBackend: plan.languageModel && plan.models.translation != null
          ? plan.backends.languageModel
          : null,
      downloadedRuntimeDirectory: plan.runtimeDirectory,
    );
    _throwIfSuperseded(generation);
    _whisperExecutable = files.whisper;
    onStartupProgress?.call(0.05, 'python');
    final process = await _startWorker(
      files.python,
      workerArguments(plan, script: files.script, work: files.work, load: load, llama: files.llama),
    );
    if (generation != _generation) {
      // Stopped while the interpreter was coming up. The stop found no
      // worker to end, so this one is ended here, where it is still held.
      WorkerProcess.discard(process);
      throw const LoreDubFailure(FailureCode.pipelineStopped);
    }
    // Held from the moment it is listened to: a stop from here on ends it,
    // and fails the handshake it is waiting for.
    final worker = WorkerProcess(
      process,
      onProgress: (value, stage) => onStartupProgress?.call(value, stage),
      onDied: _onWorkerDied,
    );
    _worker = worker;
    final said = await worker.handshake(startupLimit);
    _throwIfSuperseded(generation);
    _translationDevice = said['device'] as String?;
    _speechDevice = said['speechDevice'] as String?;
    _converterDevice = said['converterDevice'] as String?;
  }

  /// The worker died on its own. Let go of, so the next phrase is told there
  /// is no worker: left in place it was written into a pipe nobody reads,
  /// and every phrase after it waited out its two minutes while the queue
  /// behind them grew. A start still waiting has been told already, and
  /// fails with the reason; a session already running has nobody waiting on
  /// the worker as a whole, so whoever holds it is told.
  void _onWorkerDied(WorkerProcess worker, LoreDubFailure error, {required bool starting}) {
    if (!identical(_worker, worker)) return;
    _worker = null;
    if (!starting) onWorkerLost?.call(error);
  }

  /// A start that was stopped, or replaced by a later one, ends here: what
  /// it was waiting for came back to nobody.
  void _throwIfSuperseded(int generation) {
    if (generation != _generation) throw const LoreDubFailure(FailureCode.pipelineStopped);
  }

  /// The real [WorkerPreparation]. The work directory is the application's
  /// own and the scripts come out of its bundle, neither of which a test has.
  static Future<WorkerFiles> _prepareOnThisMachine({
    required String pythonExecutable,
    required bool requiresWhisper,
    required ComputeBackend recognitionBackend,
    ComputeBackend? languageModelBackend,
    String? downloadedRuntimeDirectory,
  }) async {
    if (!Platform.isWindows) throw const LoreDubFailure(FailureCode.windowsOnly);
    final whisper = requiresWhisper
        ? await resolveWhisperExecutable(
            backend: recognitionBackend,
            downloadedRuntimeDirectory: downloadedRuntimeDirectory,
          )
        : null;
    final llama = languageModelBackend == null
        ? null
        : await resolveLlamaDirectory(
            backend: languageModelBackend,
            downloadedRuntimeDirectory: downloadedRuntimeDirectory,
          );
    final python = await resolvePythonExecutable(pythonExecutable);
    final work = await createWorkDirectory();
    // The worker and the modules it imports from its own directory, all of
    // them: every voice travels whichever language the session dubs into,
    // which one is loaded being decided there, off the package on disk. The
    // clips a voice that clones reads its fixed voices from go beside them.
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();
    for (final asset in workerScripts(assets)) {
      await _extractScript(asset, work);
    }
    final references = Directory(path.join(work.path, 'references'));
    await references.create(recursive: true);
    for (final asset in workerReferences(assets)) {
      await _extractScript(asset, references);
    }
    final script = path.join(work.path, 'inference_worker.py');
    return (python: python, script: script, work: work.path, whisper: whisper, llama: llama);
  }

  /// The real [ProcessLauncher]. torch's allocator is told to grow its
  /// segments rather than keep one block per size: the voice on the card
  /// otherwise held a gigabyte more than it used, on a card the language
  /// model and whisper share with it.
  static Future<Process> _startInterpreter(String executable, List<String> arguments) =>
      Process.start(
        executable,
        arguments,
        environment: const {
          'PYTHONIOENCODING': 'utf-8',
          'PYTORCH_CUDA_ALLOC_CONF': 'expandable_segments:True',
        },
      );

  /// Copies one of the bundled runtime scripts into the work directory,
  /// where the interpreter can reach it, and answers with what it wrote.
  static Future<File> _extractScript(String asset, Directory work) async {
    final file = File(path.join(work.path, path.basename(asset)));
    final bytes = await rootBundle.load(asset);
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return file;
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
    // decide whose voice to answer in. What language it heard travels with
    // the text, for a translator that reads any.
    return processText(
      english,
      originalWavePath: wavePath,
      speed: speed,
      translate: translate,
      spoken: translateSpeech ? null : _spokenLanguage,
      // Asked for what it heard rather than for English, whisper wrote the
      // clip down: a voice that clones can read from the clip and its
      // words together.
      transcript: !translateSpeech,
    );
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

    /// The card's own recording, which a voice that clones reads the
    /// sample from.
    String? clip,
  }) async {
    final response = await _ask({
      'preview': {
        'text': text,
        'voice': voice,
        if (timbre.isNotEmpty) 'vector': timbre,
        'clip': ?clip,
      },
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
    return worker.request(body, timeout: timeout);
  }

  /// Tells a running worker something that changes how it reads from now
  /// on. With no worker there is nobody to tell: the next session reads the
  /// same thing from its files when it starts.
  Future<void> _tell(Map<String, Object?> body) async {
    final worker = _worker;
    if (worker == null) return;
    await worker.request(body, timeout: const Duration(seconds: 10));
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

    /// The language the text is in, where it is known and is not English:
    /// a translator that is a language model reads it from there.
    String? spoken,

    /// Whether the text is what [originalWavePath] says, word for word.
    bool transcript = false,
  }) async {
    final normalized = english.trim();
    if (normalized.isEmpty) throw ArgumentError.value(english, 'english', 'is empty');

    final response = await _ask({
      'text': normalized,
      'wave': ?originalWavePath,
      'speed': ?speed,
      'spoken': ?spoken,
      if (transcript) 'transcript': true,
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
    // Let go of before it is waited on: whatever else asks for the worker
    // while it dies must be told there is none, not handed the one on its
    // way out.
    final worker = _worker;
    _worker = null;
    await worker?.end();
  }
}

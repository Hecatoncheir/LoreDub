// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:io';

import '../../domain/engine_event.dart';
import '../../domain/pipeline_state.dart';
import '../../domain/session_config.dart';
import '../../domain/sound_captions.dart';
import '../../domain/speech_pace.dart';
import '../../domain/wave_slices.dart';
import 'engine_session.dart';
import 'local_inference_service.dart';
import 'phrase_queue.dart';
import 'voice_take.dart';

/// What becomes of one phrase the capture or the screen handed over, in the
/// run of the engine that is up.
///
/// A segment of the game's sound is measured for a card on the characters
/// screen, placed among the voices of a scene, or cut where the speaker
/// changes and recognized, translated and voiced; text off the screen is
/// translated and voiced. The answer is published only into the run that
/// asked for it. Phrases reach it one at a time, through the engine's
/// [PhraseQueue], so a small processor is never asked for two at once.
class PhraseProcessor {
  PhraseProcessor(
    this._inference, {
    required this._run,
    required this._emit,
    required this._take,
    required this._voice,
    required this._waiting,
    required this._releaseVoiceHeard,
    required this._reportFailure,
    required this._discard,
  });

  final LocalInferenceService _inference;

  /// The run of the engine under way, asked afresh at every step: a phrase
  /// outlives the run it began in when a stop lands while it is worked on.
  final EngineSession? Function() _run;
  final void Function(EngineEvent event) _emit;
  final VoiceTake _take;

  /// Queues a line's reading to be heard, and keeps it to be heard again.
  final void Function(String wavePath, {String? speaker}) _voice;

  /// How many readings wait for the voice, which hurries the next line.
  final int Function() _waiting;
  final Future<void> Function(String? wavePath) _releaseVoiceHeard;
  final void Function(Object error) _reportFailure;
  final Future<void> Function(String path) _discard;

  PipelineSession? get _session => _run()?.kind;
  SessionConfig? get _active {
    final run = _run();
    return run != null && run.running ? run.config : null;
  }

  bool get _paused => _run()?.paused ?? false;

  Future<void> process(PendingPhrase phrase) {
    final wavePath = phrase.wavePath;
    return wavePath != null
        ? _processSegment(wavePath)
        : _processOcrText(
            phrase.text!,
            snapshot: phrase.snapshot,
            heardWave: phrase.heardWave,
          );
  }

  /// Measures a recorded voice for a character's card and hands it over; the
  /// characters screen keeps the clearest one it hears.
  Future<void> _measureVoice(String wavePath) async {
    var kept = false;
    try {
      final heard = await _inference.fingerprint(wavePath);
      if (heard.vector.isEmpty) return;
      // Kept while the recording runs, so the screen can put the clip that
      // earned the card beside it and let the player hear it back.
      kept = _take.keep(wavePath);
      _emit(
        CharacterVoiceMeasured(
          vector: heard.vector,
          gender: heard.gender,
          seconds: heard.seconds,
          clip: kept ? wavePath : null,
        ),
      );
    } catch (error) {
      _reportFailure(error);
    } finally {
      if (!kept) await _discard(wavePath);
      // Whoever is waiting for the take to close has what it heard now.
      _take.measured();
    }
  }

  /// Places a phrase among the voices of the scene without dubbing it, which
  /// is what Live does before the pipeline itself runs.
  Future<void> _listenForSpeaker(String wavePath) async {
    try {
      final heard = await _inference.listenSpeaker(wavePath);
      // Too short or too unvoiced to belong to anyone.
      if (heard.speaker == null) return;
      _emit(SceneVoiceHeard(speaker: heard.speaker, seconds: heard.seconds));
    } catch (error) {
      _reportFailure(error);
    } finally {
      await _discard(wavePath);
    }
  }

  Future<void> _processSegment(String wavePath) async {
    // The characters screen listens for a voice, not for a phrase.
    if (_session == PipelineSession.characters) return _measureVoice(wavePath);
    // Live before it dubs: who is speaking, and nothing more.
    if (_session == PipelineSession.scene) return _listenForSpeaker(wavePath);
    // Two characters answering each other without a pause land in one
    // segment; each of their halves earns its own recognition and voice.
    for (final piece in await _splitBySpeaker(wavePath)) {
      await _recognizeSegment(piece);
    }
  }

  /// [wavePath] cut where the voice in it changes, or the recording itself
  /// when it holds one speaker — or when nobody can tell.
  Future<List<String>> _splitBySpeaker(String wavePath) async {
    final config = _active;
    if (config == null) return [wavePath];
    // The converter is what hears who is speaking; without it the segment
    // goes on whole.
    if (config.worker.models.converter == null) return [wavePath];
    try {
      final cuts = await _inference.speakerCuts(wavePath);
      if (cuts.isEmpty) return [wavePath];
      final pieces = sliceWave(await File(wavePath).readAsBytes(), cuts);
      if (pieces.length < 2) return [wavePath];
      final stem = wavePath.endsWith('.wav')
          ? wavePath.substring(0, wavePath.length - 4)
          : wavePath;
      final written = <String>[];
      for (var index = 0; index < pieces.length; index++) {
        final piece = '$stem-$index.wav';
        await File(piece).writeAsBytes(pieces[index], flush: true);
        written.add(piece);
      }
      await _discard(wavePath);
      return written;
    } catch (error) {
      // Hearing a second speaker is a courtesy; a phrase nobody could split
      // is still a phrase, and it is dubbed whole.
      _reportFailure(error);
      return [wavePath];
    }
  }

  Future<void> _recognizeSegment(String wavePath) async {
    final started = Stopwatch()..start();
    try {
      final run = _run();
      final config = _active;
      final lines = config?.lines;
      if (run == null || config == null || lines == null) return;
      final result = await _inference.processSegment(
        wavePath: wavePath,
        whisperModel: config.worker.models.whisper!,
        threads: config.worker.threads,
        translateSpeech: lines.translateSpeech,
        roughRecognition: lines.roughRecognition,
        // What whisper hands over is English; dubbing into English reads it
        // as it is, and the worker was started without a translator anyway.
        translate: lines.translatesHeard,
        speed: _pace(lines),
      );
      if (identical(run, _run())) _publishSpokenLanguage();
      if (result == null) return;
      await _publish(run, result, started.elapsedMilliseconds, original: '');
    } catch (error) {
      _reportFailure(error);
    } finally {
      await _discard(wavePath);
    }
  }

  Future<void> _processOcrText(
    String recognizedText, {
    bool snapshot = false,
    String? heardWave,
  }) async {
    final started = Stopwatch()..start();
    try {
      final run = _run();
      final lines = _active?.lines;
      if (run == null || lines == null) return;
      // Subtitles caption sounds the way whisper does: "[Music]" is not a line.
      final spoken = withoutSoundCaptions(recognizedText);
      if (spoken.isEmpty) {
        // A selection is waiting for its answer; this one held no words.
        if (snapshot) _emit(const SnapshotRead(text: ''));
        return;
      }
      // Text read in the dubbing language itself is voiced as it is.
      final result = await _inference.processText(
        spoken,
        // The voice heard as the words appeared, so the worker can place
        // the speaker and lay their timbre over the reading.
        originalWavePath: heardWave,
        translate: lines.translatesText,
        // What language the text is in, for a translator that reads any.
        spoken: lines.textLanguage,
        speed: _pace(lines),
      );
      await _publish(
        run,
        result,
        started.elapsedMilliseconds,
        original: spoken,
        snapshot: snapshot,
      );
    } catch (error) {
      _reportFailure(error);
    } finally {
      await _releaseVoiceHeard(heardWave);
    }
  }

  /// The pace the next line is read at: the player's own, hurried while
  /// lines are already queued for the voice. Counted at the moment the line
  /// is asked for, which is the last moment anything can be done about it —
  /// the worker retimes the waveform as it synthesizes it.
  double _pace(LineRules lines) {
    if (!lines.hurryWhenQueued) return lines.speed;
    return hurriedSpeed(lines.speed, _waiting());
  }

  /// Announces the language whisper settled on, once, so the interface can
  /// show what auto-detection actually decided.
  void _publishSpokenLanguage() {
    final detected = _inference.spokenLanguage;
    final run = _run();
    if (run == null || detected == null || detected == run.reportedLanguage) return;
    run.reportedLanguage = detected;
    _emit(LanguageDetected(detected));
  }

  Future<void> _publish(
    EngineSession run,
    InferenceResult result,
    int latencyMs, {
    required String original,
    bool snapshot = false,
  }) async {
    if (!identical(run, _run())) {
      // Asked for by a run that has ended since: a line nobody is listening
      // for any longer, or -- a new session up already -- one it never heard.
      if (result.wavePath case final wave?) unawaited(_discard(wave));
      return;
    }
    _emit(
      LineDubbed(
        line: TranscriptEntry(
          original: original,
          english: result.english,
          translated: result.translated,
          latency: Duration(milliseconds: latencyMs),
          // Shown as heard and passed over, rather than as a line that
          // arrived with nothing in it.
          silenced: result.silenced,
          // Who said it, so the scene list can offer the voice a
          // replacement.
          speaker: result.speaker,
          // What it was read as, so the line can be heard again.
          spoken: result.wavePath,
        ),
        snapshot: snapshot,
      ),
    );
    // Which voice read it: the automatic choice can change it per phrase, so
    // the interface should not have to guess.
    if (result.voice.isNotEmpty && result.voice != run.reportedVoice) {
      run.reportedVoice = result.voice;
      _emit(VoiceSpoken(result.voice));
    }
    // A new character joined the bank, so the count in the settings is stale.
    if (result.bankSize case final size? when size != run.reportedBankSize) {
      run.reportedBankSize = size;
      _emit(VoiceBankGrew(size));
    }
    // A line that was already being translated when the pause came is shown
    // in the transcript, but the pause means quiet. A selection is the
    // exception: the player asked for that one.
    final wavePath = result.wavePath;
    // A line the player silenced has no audio at all: it was never
    // synthesized, so there is nothing to play and nothing to delete.
    if (wavePath == null) return;
    if (_paused && !snapshot) {
      unawaited(_discard(wavePath));
      return;
    }
    // Kept after it has sounded, so the player can hear the line again
    // from the transcript rather than wait for the game to say it twice.
    // The worker says who is speaking, so a different character may start
    // while the last one is still talking — when the settings allow it.
    _voice(wavePath, speaker: result.speaker);
  }
}

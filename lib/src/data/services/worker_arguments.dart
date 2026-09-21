// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:path/path.dart' as path;

import '../../domain/compute_device.dart';
import '../../domain/session_config.dart';
import 'runtime_catalog.dart';

/// What the worker's models are loaded for, beyond what [WorkerPlan] names.
enum WorkerLoad {
  /// Everything the plan names: the translator, the voice and the converter.
  full,

  /// The converter alone: a card is measured without waiting a minute for
  /// Marian and the voice.
  embedOnly,

  /// The voice and the converter without the translator: a sample of a
  /// voice speaks a line the application already wrote.
  speechOnly,
}

/// The command line the worker is started with: [script] and everything
/// [plan] asks it to load, run on and read, with [work] as the directory it
/// writes its audio into.
///
/// Pure, so what reaches the worker can be checked without starting one --
/// which is how an argument nested under the wrong flag is caught. The
/// glossary was once written among the converter's, and a session without
/// the original voice started with no glossary at all.
List<String> workerArguments(
  WorkerPlan plan, {
  required String script,
  required String work,
  WorkerLoad load = WorkerLoad.full,
}) {
  final models = plan.models;
  final backends = plan.backends;
  String device(ComputeBackend backend) => backend == ComputeBackend.cuda ? 'cuda' : 'cpu';
  final translation = models.translation ?? '';
  final speech = models.speech ?? '';
  final converter = models.converter;
  // The translator, the voice and the converter each ask for the CUDA build
  // on their own, and whichever does brings it in for all three.
  final cudaTorch =
      backends.translation == ComputeBackend.cuda ||
      (speech.isNotEmpty && backends.speech == ComputeBackend.cuda) ||
      (converter != null && backends.voiceConversion == ComputeBackend.cuda);
  return [
    '-u',
    script,
    if (load == WorkerLoad.embedOnly) '--embed-only',
    if (load == WorkerLoad.speechOnly) '--speech-only',
    if (translation.isNotEmpty) ...['--translation-model', translation],
    if (speech.isNotEmpty) ...['--tts-model', speech, '--speech-device', device(backends.speech)],
    '--speaker',
    plan.speaker,
    '--work-directory',
    work,
    '--threads',
    '${plan.threads}',
    '--speed',
    plan.speed.toStringAsFixed(3),
    '--device',
    device(backends.translation),
    if (plan.translationPrefix.isNotEmpty) ...['--translation-prefix', plan.translationPrefix],
    if (plan.followSpeaker) ...[
      '--follow-speaker',
      '--male-voices',
      plan.maleVoices.join(','),
      '--female-voices',
      plan.femaleVoices.join(','),
    ],
    // CUDA torch is installed beside the models rather than over the
    // bundled CPU build, so the worker is told where to find it.
    if (cudaTorch && plan.runtimeDirectory.isNotEmpty) ...[
      '--extra-packages',
      path.join(plan.runtimeDirectory, torchCudaRuntimeId),
    ],
    // Outside the converter's own arguments: what the player wrote down is
    // read whether or not the original voice is carried over.
    if (plan.glossary case final glossary?) ...['--glossary', glossary],
    if (converter != null) ...[
      '--voice-converter',
      converter,
      '--converter-device',
      device(backends.voiceConversion),
      if (plan.revoice) '--revoice',
      if (plan.voiceBank case final bank?) ...['--voice-bank', bank],
      if (plan.characters case final characters?) ...['--characters', characters],
      if (plan.asHeard.isNotEmpty) ...['--as-heard', plan.asHeard.join(',')],
    ],
  ];
}

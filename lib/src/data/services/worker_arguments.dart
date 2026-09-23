// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:path/path.dart' as path;

import '../../domain/compute_device.dart';
import '../../domain/session_config.dart';
import '../../domain/spoken_language.dart';
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

  /// Where llama.cpp's server stands, for a plan whose translator is a
  /// language model.
  String? llama,
}) => [
  '-u',
  script,
  ..._loadArguments(load),
  ..._modelArguments(plan),
  '--speaker',
  plan.speaker,
  '--work-directory',
  work,
  '--threads',
  '${plan.threads}',
  '--speed',
  plan.speed.toStringAsFixed(3),
  '--device',
  _device(plan.backends.translation),
  if (plan.translationPrefix.isNotEmpty) ...['--translation-prefix', plan.translationPrefix],
  ..._languageArguments(plan, llama),
  ..._followArguments(plan),
  ..._extraPackages(plan),
  // Outside the converter's own arguments: what the player wrote down is
  // read whether or not the original voice is carried over.
  if (plan.glossary case final glossary?) ...['--glossary', glossary],
  ..._converterArguments(plan),
];

String _device(ComputeBackend backend) => backend == ComputeBackend.cuda ? 'cuda' : 'cpu';

/// The languages the session runs between, and the server a translator
/// that is a language model is started through. The game's language is
/// named only where the player named it: detected, it travels with each
/// line instead.
List<String> _languageArguments(WorkerPlan plan, String? llama) => [
  '--language',
  plan.targetLanguage,
  if (plan.sourceLanguage != autoSpokenLanguage) ...['--source-language', plan.sourceLanguage],
  if (plan.languageModel && llama != null) ...[
    '--llama-server',
    llama,
    '--translation-backend',
    plan.backends.languageModel.name,
    if (plan.chatTemplate.isNotEmpty) ...['--chat-template', plan.chatTemplate],
  ],
];

List<String> _loadArguments(WorkerLoad load) => switch (load) {
  WorkerLoad.full => const [],
  WorkerLoad.embedOnly => const ['--embed-only'],
  WorkerLoad.speechOnly => const ['--speech-only'],
};

/// The translator and the voice, each where the plan names one.
List<String> _modelArguments(WorkerPlan plan) {
  final translation = plan.models.translation ?? '';
  final speech = plan.models.speech ?? '';
  return [
    if (translation.isNotEmpty) ...['--translation-model', translation],
    if (speech.isNotEmpty) ...[
      '--tts-model',
      speech,
      '--speech-device',
      _device(plan.backends.speech),
    ],
  ];
}

List<String> _followArguments(WorkerPlan plan) => [
  if (plan.followSpeaker) ...[
    '--follow-speaker',
    '--male-voices',
    plan.maleVoices.join(','),
    '--female-voices',
    plan.femaleVoices.join(','),
  ],
];

/// CUDA torch is installed beside the models rather than over the bundled
/// CPU build, so the worker is told where to find it.
List<String> _extraPackages(WorkerPlan plan) => [
  if (_wantsCudaTorch(plan) && plan.runtimeDirectory.isNotEmpty) ...[
    '--extra-packages',
    path.join(plan.runtimeDirectory, torchCudaRuntimeId),
  ],
];

/// The translator, the voice and the converter each ask for the CUDA build
/// on their own, and whichever does brings it in for all three. A language
/// model runs in llama.cpp's own build and asks nothing of torch.
bool _wantsCudaTorch(WorkerPlan plan) {
  final backends = plan.backends;
  final translation = plan.models.translation ?? '';
  if (translation.isNotEmpty &&
      !plan.languageModel &&
      backends.translation == ComputeBackend.cuda) {
    return true;
  }
  final speech = plan.models.speech ?? '';
  if (speech.isNotEmpty && backends.speech == ComputeBackend.cuda) return true;
  return plan.models.converter != null && backends.voiceConversion == ComputeBackend.cuda;
}

List<String> _converterArguments(WorkerPlan plan) {
  final converter = plan.models.converter;
  if (converter == null) return const [];
  return [
    '--voice-converter',
    converter,
    '--converter-device',
    _device(plan.backends.voiceConversion),
    if (plan.revoice) '--revoice',
    if (plan.voiceBank case final bank?) ...['--voice-bank', bank],
    if (plan.characters case final characters?) ...['--characters', characters],
    if (plan.asHeard.isNotEmpty) ...['--as-heard', plan.asHeard.join(',')],
  ];
}

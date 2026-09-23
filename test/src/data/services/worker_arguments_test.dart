// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/worker_arguments.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:lore_dub/src/domain/session_config.dart';
import 'package:path/path.dart' as path;

void main() {
  const base = WorkerPlan(
    threads: 6,
    pythonExecutable: 'python.exe',
    runtimeDirectory: 'runtime',
    speaker: 'aidar',
    speed: 1.2,
  );

  List<String> of(WorkerPlan plan, {WorkerLoad load = WorkerLoad.full}) =>
      workerArguments(plan, script: 'worker.py', work: 'work', load: load);

  /// The value written after [flag], or null when the flag is not there.
  String? valueOf(List<String> arguments, String flag) {
    final at = arguments.indexOf(flag);
    return at < 0 ? null : arguments[at + 1];
  }

  test('starts the script unbuffered, with the threads, the pace and the voice', () {
    final arguments = of(base);

    expect(arguments.take(2), ['-u', 'worker.py']);
    expect(valueOf(arguments, '--threads'), '6');
    expect(valueOf(arguments, '--speed'), '1.200');
    expect(valueOf(arguments, '--speaker'), 'aidar');
    expect(valueOf(arguments, '--work-directory'), 'work');
    expect(arguments, isNot(contains('--translation-model')), reason: 'none was named');
  });

  test('hands the glossary over without the converter', () {
    // It was once written among the converter's arguments, and a session
    // without the original voice started with no glossary at all.
    final arguments = of(
      const WorkerPlan(
        threads: 2,
        pythonExecutable: 'python.exe',
        runtimeDirectory: 'runtime',
        glossary: 'glossary.session.json',
      ),
    );

    expect(valueOf(arguments, '--glossary'), 'glossary.session.json');
    expect(arguments, isNot(contains('--voice-converter')));
  });

  test('names the bank, the cast and the cut only beside a converter', () {
    const plan = WorkerPlan(
      threads: 2,
      pythonExecutable: 'python.exe',
      runtimeDirectory: 'runtime',
      revoice: true,
      voiceBank: 'bank.json',
      characters: 'characters.json',
      asHeard: {'guard', 'smith'},
    );
    expect(of(plan), isNot(contains('--voice-bank')), reason: 'nothing to hear them with');

    final arguments = of(
      WorkerPlan(
        threads: plan.threads,
        pythonExecutable: plan.pythonExecutable,
        runtimeDirectory: plan.runtimeDirectory,
        models: const ModelPaths(converter: 'converter'),
        revoice: true,
        voiceBank: plan.voiceBank,
        characters: plan.characters,
        asHeard: plan.asHeard,
      ),
    );
    expect(valueOf(arguments, '--voice-converter'), 'converter');
    expect(arguments, contains('--revoice'));
    expect(valueOf(arguments, '--voice-bank'), 'bank.json');
    expect(valueOf(arguments, '--characters'), 'characters.json');
    expect(valueOf(arguments, '--as-heard')?.split(','), unorderedEquals(['guard', 'smith']));
  });

  test('brings in the CUDA torch once any stage asks for the card', () {
    expect(of(base), isNot(contains('--extra-packages')));

    final arguments = of(
      const WorkerPlan(
        threads: 2,
        pythonExecutable: 'python.exe',
        runtimeDirectory: 'runtime',
        models: ModelPaths(speech: 'model.onnx'),
        backends: StageBackends(speech: ComputeBackend.cuda),
      ),
    );
    expect(valueOf(arguments, '--speech-device'), 'cuda');
    expect(valueOf(arguments, '--device'), 'cpu', reason: 'the translator stays where it was put');
    expect(valueOf(arguments, '--extra-packages'), path.join('runtime', 'torch-cuda'));
  });

  test('asks for the converter alone, or the voice alone, where that is all a session wants', () {
    expect(of(base, load: WorkerLoad.embedOnly), contains('--embed-only'));
    expect(of(base, load: WorkerLoad.speechOnly), contains('--speech-only'));
    expect(of(base), isNot(anyOf(contains('--embed-only'), contains('--speech-only'))));
  });

  test('names the dubbing language, and the game\'s only where the player named it', () {
    expect(valueOf(of(base), '--language'), 'ru');
    expect(of(base), isNot(contains('--source-language')), reason: 'detected, it travels per line');

    final named = of(
      const WorkerPlan(
        threads: 2,
        pythonExecutable: 'python.exe',
        runtimeDirectory: 'runtime',
        sourceLanguage: 'de',
        targetLanguage: 'en',
      ),
    );
    expect(valueOf(named, '--source-language'), 'de');
    expect(valueOf(named, '--language'), 'en');
  });

  test('starts llama.cpp for a language model on its own backend, with its template', () {
    const plan = WorkerPlan(
      threads: 2,
      pythonExecutable: 'python.exe',
      runtimeDirectory: 'runtime',
      models: ModelPaths(translation: 'translategemma'),
      backends: StageBackends(
        translation: ComputeBackend.cuda,
        languageModel: ComputeBackend.vulkan,
      ),
      languageModel: true,
      chatTemplate: 'gemma',
    );
    final arguments = workerArguments(
      plan,
      script: 'worker.py',
      work: 'work',
      llama: path.join('runtime', 'llama-vulkan'),
    );

    expect(valueOf(arguments, '--translation-model'), 'translategemma');
    expect(valueOf(arguments, '--llama-server'), path.join('runtime', 'llama-vulkan'));
    expect(valueOf(arguments, '--translation-backend'), 'vulkan');
    expect(valueOf(arguments, '--chat-template'), 'gemma');
    // The model runs in llama.cpp's own build: nothing asks torch for the card.
    expect(arguments, isNot(contains('--extra-packages')));
    // Without the server found there is nothing to start it with.
    expect(of(plan), isNot(contains('--llama-server')));
  });

  test('Marian on the card still wants the CUDA torch', () {
    final arguments = of(
      const WorkerPlan(
        threads: 2,
        pythonExecutable: 'python.exe',
        runtimeDirectory: 'runtime',
        models: ModelPaths(translation: 'opus-mt'),
        backends: StageBackends(translation: ComputeBackend.cuda),
      ),
    );

    expect(valueOf(arguments, '--extra-packages'), path.join('runtime', 'torch-cuda'));
    expect(arguments, isNot(contains('--llama-server')));
  });
}

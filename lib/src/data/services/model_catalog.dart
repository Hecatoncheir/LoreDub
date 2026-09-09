// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/model_package.dart';

final modelCatalog = <ModelPackage>[
  ModelPackage(
    id: 'whisper-base',
    title: 'Whisper base',
    description: 'Распознавание речи и перевод любого языка на английский.',
    artifacts: [
      ModelArtifact(
        fileName: 'ggml-base.bin',
        url: Uri.parse(
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin',
        ),
        byteSize: 147951465,
        hash: '60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe',
      ),
    ],
  ),
  ModelPackage(
    id: 'bergamot-en-ru',
    title: 'Marian English → Russian',
    description: 'Локальный CPU-переводчик Helsinki-NLP/Marian.',
    artifacts: [
      ModelArtifact(
        fileName: 'config.json',
        url: Uri.parse(
          'https://huggingface.co/Helsinki-NLP/opus-mt-en-ru/resolve/main/config.json',
        ),
        byteSize: 1381,
      ),
      ModelArtifact(
        fileName: 'generation_config.json',
        url: Uri.parse(
          'https://huggingface.co/Helsinki-NLP/opus-mt-en-ru/resolve/main/generation_config.json',
        ),
        byteSize: 293,
      ),
      ModelArtifact(
        fileName: 'pytorch_model.bin',
        url: Uri.parse(
          'https://huggingface.co/Helsinki-NLP/opus-mt-en-ru/resolve/main/pytorch_model.bin',
        ),
        byteSize: 306991893,
        hash: 'd15fa58c6bc3efd3629c1b6b86d9aa6d15d2751a4620aa4cdd7eed7b5cbe583b',
      ),
      ModelArtifact(
        fileName: 'source.spm',
        url: Uri.parse(
          'https://huggingface.co/Helsinki-NLP/opus-mt-en-ru/resolve/main/source.spm',
        ),
        byteSize: 802781,
      ),
      ModelArtifact(
        fileName: 'target.spm',
        url: Uri.parse(
          'https://huggingface.co/Helsinki-NLP/opus-mt-en-ru/resolve/main/target.spm',
        ),
        byteSize: 1080169,
      ),
      ModelArtifact(
        fileName: 'tokenizer_config.json',
        url: Uri.parse(
          'https://huggingface.co/Helsinki-NLP/opus-mt-en-ru/resolve/main/tokenizer_config.json',
        ),
        byteSize: 42,
      ),
      ModelArtifact(
        fileName: 'vocab.json',
        url: Uri.parse(
          'https://huggingface.co/Helsinki-NLP/opus-mt-en-ru/resolve/main/vocab.json',
        ),
        byteSize: 2601758,
      ),
    ],
  ),
  ModelPackage(
    id: 'silero-ru-v5.3',
    title: 'Silero TTS Russian v5.3',
    description: 'Русская речь, 24 kHz; aidar, baya, kseniya и eugene.',
    artifacts: [
      ModelArtifact(
        fileName: 'v5_3_ru.pt',
        url: Uri.parse(
          'https://models.silero.ai/models/tts/ru/v5_3_ru.pt',
        ),
      ),
    ],
  ),
];

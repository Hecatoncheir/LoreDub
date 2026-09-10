// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/model_package.dart';

/// Recognition needs nothing but Whisper: it turns speech in any language
/// into English on its own. Everything after that comes in pairs — a Marian
/// translator and a Silero voice for the same language.
const whisperModelId = 'whisper-base';

ModelPackage _marian({
  required String id,
  required String language,
  required String pair,
  required Map<String, int> sizes,
  String? weightsHash,
}) => ModelPackage(
  id: id,
  kind: ModelKind.translation,
  language: language,
  artifacts: [
    for (final entry in sizes.entries)
      ModelArtifact(
        fileName: entry.key,
        url: Uri.parse(
          'https://huggingface.co/Helsinki-NLP/opus-mt-$pair/resolve/main/${entry.key}',
        ),
        byteSize: entry.value,
        hash: entry.key == 'pytorch_model.bin' ? weightsHash : null,
      ),
  ],
);

ModelPackage _silero({
  required String id,
  required String language,
  required String fileName,
  required String directory,
  required int byteSize,
  required String speaker,
  required String version,
}) => ModelPackage(
  id: id,
  kind: ModelKind.speech,
  language: language,
  speaker: speaker,
  version: version,
  artifacts: [
    ModelArtifact(
      fileName: fileName,
      url: Uri.parse('https://models.silero.ai/models/tts/$directory/$fileName'),
      byteSize: byteSize,
    ),
  ],
);

final modelCatalog = <ModelPackage>[
  ModelPackage(
    id: whisperModelId,
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

  // The identifiers of the Russian pair predate the other languages and are
  // kept as they are: they name the folders models are already stored in.
  _marian(
    id: 'bergamot-en-ru',
    language: 'ru',
    pair: 'en-ru',
    weightsHash: 'd15fa58c6bc3efd3629c1b6b86d9aa6d15d2751a4620aa4cdd7eed7b5cbe583b',
    sizes: const {
      'config.json': 1381,
      'generation_config.json': 293,
      'pytorch_model.bin': 306991893,
      'source.spm': 802781,
      'target.spm': 1080169,
      'tokenizer_config.json': 42,
      'vocab.json': 2601758,
    },
  ),
  _marian(
    id: 'marian-en-de',
    language: 'de',
    pair: 'en-de',
    sizes: const {
      'config.json': 1335,
      'generation_config.json': 293,
      'pytorch_model.bin': 297928209,
      'source.spm': 768489,
      'target.spm': 796845,
      'tokenizer_config.json': 42,
      'vocab.json': 1273232,
    },
  ),
  _marian(
    id: 'marian-en-es',
    language: 'es',
    pair: 'en-es',
    sizes: const {
      'config.json': 1473,
      'generation_config.json': 293,
      'pytorch_model.bin': 312087523,
      'source.spm': 801636,
      'target.spm': 825924,
      'tokenizer_config.json': 44,
      'vocab.json': 1590040,
    },
  ),
  _marian(
    id: 'marian-en-fr',
    language: 'fr',
    pair: 'en-fr',
    sizes: const {
      'config.json': 1416,
      'generation_config.json': 293,
      'pytorch_model.bin': 300827685,
      'source.spm': 778395,
      'target.spm': 802397,
      'tokenizer_config.json': 42,
      'vocab.json': 1339166,
    },
  ),
  _marian(
    id: 'marian-en-uk',
    language: 'uk',
    pair: 'en-uk',
    sizes: const {
      'config.json': 1381,
      'generation_config.json': 293,
      'pytorch_model.bin': 305081481,
      'source.spm': 808645,
      'target.spm': 1007605,
      'tokenizer_config.json': 42,
      'vocab.json': 2367710,
    },
  ),

  _silero(
    id: 'silero-ru-v5.3',
    version: 'v5.3',
    language: 'ru',
    fileName: 'v5_3_ru.pt',
    directory: 'ru',
    byteSize: 145359640,
    speaker: 'xenia',
  ),
  _silero(
    id: 'silero-de-v3',
    version: 'v3',
    language: 'de',
    fileName: 'v3_de.pt',
    directory: 'de',
    byteSize: 57076082,
    speaker: 'eva_k',
  ),
  _silero(
    id: 'silero-es-v3',
    version: 'v3',
    language: 'es',
    fileName: 'v3_es.pt',
    directory: 'es',
    byteSize: 57079302,
    speaker: 'es_0',
  ),
  _silero(
    id: 'silero-fr-v3',
    version: 'v3',
    language: 'fr',
    fileName: 'v3_fr.pt',
    directory: 'fr',
    byteSize: 57085158,
    speaker: 'fr_0',
  ),
  _silero(
    id: 'silero-uk-v4',
    version: 'v4',
    language: 'uk',
    fileName: 'v4_ua.pt',
    directory: 'ua',
    byteSize: 35354913,
    speaker: 'mykyta',
  ),
];

/// Languages the pipeline can dub into: those with both a translator and a
/// voice, in catalogue order.
List<String> get dubbingLanguages => [
  for (final model in modelCatalog)
    if (model.kind == ModelKind.translation &&
        model.language != null &&
        speechModelFor(model.language!) != null)
      model.language!,
];

ModelPackage? _modelFor(ModelKind kind, String language) {
  for (final model in modelCatalog) {
    if (model.kind == kind && model.language == language) return model;
  }
  return null;
}

ModelPackage? translationModelFor(String language) => _modelFor(ModelKind.translation, language);

ModelPackage? speechModelFor(String language) => _modelFor(ModelKind.speech, language);

ModelPackage get whisperModel => modelCatalog.firstWhere((model) => model.id == whisperModelId);

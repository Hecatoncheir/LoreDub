// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/model_package.dart';

/// Recognition needs nothing but Whisper: it turns speech in any language
/// into English on its own. Everything after that comes in pairs — a Marian
/// translator and a Silero voice for the same language.
const whisperModelId = 'whisper-base';

/// The whisper.cpp builds on offer, smallest first.
///
/// `base` stays the default because it is the one that fits a plain CPU;
/// everything above it is worth the download once recognition runs on a card.
ModelPackage _whisper({
  required String id,
  required String fileName,
  required int byteSize,
  required String version,
  String? hash,
  bool translatesSpeech = true,
}) => ModelPackage(
  id: id,
  version: version,
  translatesSpeech: translatesSpeech,
  artifacts: [
    ModelArtifact(
      fileName: fileName,
      url: Uri.parse('https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$fileName'),
      byteSize: byteSize,
      hash: hash,
    ),
  ],
);

ModelPackage _marian({
  required String id,
  required String language,
  required String pair,
  required Map<String, int> sizes,
  String? weightsHash,
  String? translationPrefix,

  /// Repository name under Helsinki-NLP, when it is not `opus-mt-<pair>`.
  String? repository,
}) => ModelPackage(
  id: id,
  kind: ModelKind.translation,
  language: language,
  translationPrefix: translationPrefix,
  artifacts: [
    for (final entry in sizes.entries)
      ModelArtifact(
        fileName: entry.key,
        url: Uri.parse(
          'https://huggingface.co/Helsinki-NLP/${repository ?? 'opus-mt-$pair'}'
          '/resolve/main/${entry.key}',
        ),
        byteSize: entry.value,
        hash: entry.key == 'pytorch_model.bin' ? weightsHash : null,
      ),
  ],
);

/// Voices, with the gender each one reads as.
///
/// The genders are measured rather than looked up: every voice was
/// synthesized and its median fundamental taken, which separates the two
/// groups by a wide margin. Packages whose voices are named by number are
/// left [VoiceGender.unknown], and the automatic choice then stays out of it.
VoiceOption _male(String id) => VoiceOption(id, gender: VoiceGender.male);
VoiceOption _female(String id) => VoiceOption(id, gender: VoiceGender.female);

ModelPackage _silero({
  required String id,
  required String language,
  required String fileName,
  required String directory,
  required int byteSize,
  required String speaker,
  required String version,
  List<VoiceOption> voices = const [],
}) => ModelPackage(
  id: id,
  kind: ModelKind.speech,
  language: language,
  speaker: speaker,
  version: version,
  voices: voices,
  artifacts: [
    ModelArtifact(
      fileName: fileName,
      url: Uri.parse('https://models.silero.ai/models/tts/$directory/$fileName'),
      byteSize: byteSize,
    ),
  ],
);

final modelCatalog = <ModelPackage>[
  _whisper(
    id: whisperModelId,
    version: 'base',
    fileName: 'ggml-base.bin',
    byteSize: 147951465,
    hash: '60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe',
  ),
  _whisper(
    id: 'whisper-small',
    version: 'small',
    fileName: 'ggml-small.bin',
    byteSize: 487601967,
  ),
  _whisper(
    id: 'whisper-medium-q5',
    version: 'medium q5_0',
    fileName: 'ggml-medium-q5_0.bin',
    byteSize: 539212467,
  ),
  _whisper(
    id: 'whisper-large-v3-turbo-q5',
    version: 'large-v3-turbo q5_0',
    fileName: 'ggml-large-v3-turbo-q5_0.bin',
    byteSize: 574041195,
    // Fine-tuned without translation data, so it is only asked to transcribe.
    translatesSpeech: false,
  ),

  // The Tatoeba-Challenge model rather than the 2020 opus-mt-en-ru it
  // replaced: on the same newstest sets it scores 4 to 7 BLEU higher, which
  // is the difference between a line that parses and one that does not. It
  // serves the East Slavic languages together, hence the target token.
  _marian(
    id: 'opus-mt-tc-big-en-zle',
    language: 'ru',
    pair: 'en-zle',
    repository: 'opus-mt-tc-big-en-zle',
    translationPrefix: '>>rus<<',
    sizes: const {
      'config.json': 1076,
      'generation_config.json': 301,
      'pytorch_model.bin': 479034117,
      'source.spm': 802747,
      'special_tokens_map.json': 65,
      'target.spm': 1017004,
      'tokenizer_config.json': 339,
      'vocab.json': 2510527,
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
    voices: [
      _male('aidar'),
      _female('baya'),
      _female('kseniya'),
      _male('eugene'),
      _female('xenia'),
    ],
  ),
  _silero(
    id: 'silero-de-v3',
    version: 'v3',
    language: 'de',
    fileName: 'v3_de.pt',
    directory: 'de',
    byteSize: 57076082,
    speaker: 'eva_k',
    voices: [
      _male('bernd_ungerer'),
      _female('eva_k'),
      _male('friedrich'),
      _female('hokuspokus'),
      _male('karlsson'),
    ],
  ),
  _silero(
    id: 'silero-es-v3',
    version: 'v3',
    language: 'es',
    fileName: 'v3_es.pt',
    directory: 'es',
    byteSize: 57079302,
    speaker: 'es_0',
    // Measured: all three Spanish voices are men, so there is no second
    // gender for the automatic choice to switch to.
    voices: [_male('es_0'), _male('es_1'), _male('es_2')],
  ),
  _silero(
    id: 'silero-fr-v3',
    version: 'v3',
    language: 'fr',
    fileName: 'v3_fr.pt',
    directory: 'fr',
    byteSize: 57085158,
    speaker: 'fr_0',
    voices: [
      _male('fr_0'),
      _male('fr_1'),
      _male('fr_2'),
      _male('fr_3'),
      _female('fr_4'),
      _male('fr_5'),
    ],
  ),
  _silero(
    id: 'silero-uk-v4',
    version: 'v4',
    language: 'uk',
    fileName: 'v4_ua.pt',
    directory: 'ua',
    byteSize: 35354913,
    speaker: 'mykyta',
    // The Ukrainian package ships one voice, so there is nothing to follow.
    voices: [_male('mykyta')],
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

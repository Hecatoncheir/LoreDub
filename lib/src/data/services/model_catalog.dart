// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/model_package.dart';
import '../../domain/spoken_language.dart';

/// Recognition needs nothing but Whisper: it turns speech in any language
/// into English on its own. Everything after that comes in pairs — a Marian
/// translator and a Silero voice for the same language.
const whisperModelId = 'whisper-base';

/// OpenVoice V2's tone colour converter, which re-voices Silero in the timbre
/// of the phrase being answered. MIT, and the same package for every language.
const voiceConverterModelId = 'openvoice-v2-converter';

/// The whisper.cpp builds on offer, smallest first.
///
/// `base` stays the default because it is the one that fits a plain CPU;
/// everything above it is worth the download once recognition runs on a card.
ModelPackage _whisper({
  required String id,
  required String fileName,
  required int byteSize,
  required String version,
  required RecognitionQuality quality,
  String? hash,
  bool translatesSpeech = true,
}) => ModelPackage(
  id: id,
  version: version,
  quality: quality,
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

/// Where the converted translators are published: an asset of the release
/// that carries them. Release assets are flat, so a file is named by its
/// package and its own name together.
const convertedTranslatorRelease =
    'https://github.com/Hecatoncheir/LoreDub/releases/download/translators-ct2-v1';

/// A translator of the OPUS-MT project, converted to CTranslate2 int8 and
/// published by this project rather than fetched from its authors.
///
/// What Helsinki-NLP publishes is a PyTorch checkpoint for transformers. The
/// same weights under CTranslate2 read a line in about half the time and take
/// half the disk, and the conversion wants a transformers newer than the
/// shipped runtime carries -- so it is made once, here, rather than on every
/// machine. CC-BY-4.0 allows both the conversion and its distribution; the
/// NOTICE that travels in every package names the authors and the change.
///
/// `scripts/convert_translators.py` builds them and prints these entries.
/// Each file carries its size and its SHA-256, which the upstream checkpoints
/// could not: only a hash the authors publish can be pinned, and they publish
/// none. Converting them ourselves means measuring them ourselves.
ModelPackage _converted({
  required String id,
  required String language,

  /// File name to its size in bytes and its SHA-256.
  required Map<String, (int, String)> files,
  String? translationPrefix,
}) => ModelPackage(
  id: id,
  kind: ModelKind.translation,
  language: language,
  translationPrefix: translationPrefix,
  artifacts: [
    for (final entry in files.entries)
      ModelArtifact(
        fileName: entry.key,
        url: Uri.parse('$convertedTranslatorRelease/$id-${entry.key}'),
        byteSize: entry.value.$1,
        hash: entry.value.$2,
      ),
  ],
);

/// Voices, with the gender each one reads as.
///
/// The genders are measured rather than looked up: every voice was
/// synthesized and its median fundamental taken, which separates the two
/// groups by a wide margin. Packages whose voices are named by number are
/// left [VoiceGender.unknown], and the automatic choice then stays out of it.
/// The English voices that read as women and as men, by the median
/// fundamental of one phrase each -- the same measurement the worker makes
/// of a game's speaker.
const _englishWomen = [
  0,
  4,
  5,
  6,
  10,
  11,
  12,
  14,
  16,
  18,
  21,
  24,
  25,
  26,
  28,
  33,
  36,
  37,
  38,
  39,
  41,
  43,
  44,
  45,
  47,
  49,
  50,
  51,
  52,
  53,
  54,
  55,
  56,
  60,
  61,
  62,
  65,
  67,
  72,
  75,
  82,
  83,
  85,
  86,
  92,
  94,
  95,
  96,
  97,
  98,
  99,
  101,
  107,
  108,
  109,
  116,
  117,
];
const _englishMen = [
  2,
  13,
  15,
  17,
  19,
  20,
  22,
  23,
  27,
  29,
  30,
  31,
  32,
  34,
  35,
  40,
  42,
  46,
  57,
  58,
  63,
  66,
  69,
  70,
  71,
  73,
  77,
  78,
  79,
  80,
  81,
  84,
  87,
  89,
  90,
  91,
  93,
  100,
  102,
  103,
  104,
  105,
  106,
  110,
  112,
  113,
  114,
  115,
];

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
    quality: RecognitionQuality.fair,
    fileName: 'ggml-base.bin',
    byteSize: 147951465,
    hash: '60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe',
  ),
  _whisper(
    id: 'whisper-small',
    version: 'small',
    quality: RecognitionQuality.good,
    fileName: 'ggml-small.bin',
    byteSize: 487601967,
  ),
  _whisper(
    id: 'whisper-medium-q5',
    version: 'medium q5_0',
    quality: RecognitionQuality.excellent,
    fileName: 'ggml-medium-q5_0.bin',
    byteSize: 539212467,
  ),
  _whisper(
    id: 'whisper-large-v3-turbo-q5',
    version: 'large-v3-turbo q5_0',
    // As accurate as medium on transcription, and faster.
    quality: RecognitionQuality.excellent,
    fileName: 'ggml-large-v3-turbo-q5_0.bin',
    byteSize: 574041195,
    // Fine-tuned without translation data, so it is only asked to transcribe.
    translatesSpeech: false,
  ),

  // The Tatoeba-Challenge model rather than the 2020 opus-mt-en-ru it
  // replaced: on the same newstest sets it scores 4 to 7 BLEU higher, which
  // is the difference between a line that parses and one that does not. It
  // serves the East Slavic languages together, hence the target token.
  _converted(
    id: 'opus-mt-tc-big-en-zle',
    language: 'ru',
    translationPrefix: '>>rus<<',
    files: const {
      'config.json': (233, '72901fbd8abd89fb5cf4a388f26fc681f5c4c58a1e1a88b30b879f107270e7ee'),
      'model.bin': (242630403, 'fbd24e6fdfa27fb69d4bbce7968eccef693b7a6249ec09733269e96cf2d1a319'),
      'NOTICE': (585, '1d1e628c4559cff17a077fef9d0c847f614a9e185ecb7e22323d5928ffc07058'),
      'shared_vocabulary.json': (
        2152164,
        '558fb7414f75540fc3e9f272dac90cb85272083014978e5a8f81c7e35ae2a49b',
      ),
      'source.spm': (802747, '3612abfe04bf08344ba91115f0e15e228a7a15a621ea856bfd548097dbaeb43c'),
      'target.spm': (1017004, '22940e744b3a9fd166a04880938fb61f7dfa8ba4b5d2d3f6371a6c4ba8f3b019'),
      'tokenizer_config.json': (
        339,
        '41deeedfc0e3ce366d6bde180dee025a8ca1bcd62b1451889301e8ea4bcbb609',
      ),
      'vocab.json': (2510527, '41dbdff4a0b5a6ab125715c3342c5ce6516e93ffd49608813240403f036c5efb'),
    },
  ),
  _converted(
    id: 'marian-en-de',
    language: 'de',
    files: const {
      'config.json': (233, '72901fbd8abd89fb5cf4a388f26fc681f5c4c58a1e1a88b30b879f107270e7ee'),
      'model.bin': (75979635, '3cad348e65aa400a0fce83b2b89a876030092e108ebc5a824ac1def6c76957b2'),
      'NOTICE': (569, 'a0af054f2180db4e0cd071db94a3fa2887cbff13ce77535b017d3cbf31873ded'),
      'shared_vocabulary.json': (
        1051929,
        'c32eadf3db9b4884a959858d7294f7c61e20067fc47564ae3c56d180c1ee6178',
      ),
      'source.spm': (768489, '678f2a1177d8389f67b66299762dcc4fc567e89b07e212ba91b0c56daecf47ce'),
      'target.spm': (796845, 'bbd1f495eea99c8e21ae086d9146e0fa7b096c3dfdd9ba07ab8b631889df5c9b'),
      'tokenizer_config.json': (
        42,
        '052c28be2c51ea3398bf9b9de92004270e29a51f8404f9921ec025986ffbefae',
      ),
      'vocab.json': (1273232, '0d70d89fee4a8b4ef99a56d712163baadcabd5600a597f71515547ee70306329'),
    },
  ),
  _converted(
    id: 'marian-en-es',
    language: 'es',
    files: const {
      'config.json': (233, '72901fbd8abd89fb5cf4a388f26fc681f5c4c58a1e1a88b30b879f107270e7ee'),
      'model.bin': (79567635, '30c5c2de08329c61860777fbe471e2dd413f64adbde543b2848b5ac3b5d6f865'),
      'NOTICE': (569, 'd589b8d5b129e95bec670b2ce7dd44fe1127e3fdd0ec60c570dae86233f75d24'),
      'shared_vocabulary.json': (
        1341137,
        '5d57da3a8899ca0a45f085eff04c41553d784a981544702996001911b9dd0af1',
      ),
      'source.spm': (801636, '4dd547c24816a335e7b0b2e63376a8f1b3cbfc671eda5ab808dd44fdadaa8791'),
      'target.spm': (825924, 'e236ee6d866b635c0142114f8647f39831f9d92534aa2aad75c942f6a78ad0e3'),
      'tokenizer_config.json': (
        44,
        '9859e3f8f73e2f50ab3e5cc2de432645347432956df4772d33209a346dd97f3b',
      ),
      'vocab.json': (1590040, '257f346d7a6b2ecceafcca8ba05648ce2fd68dfaf105fb0e913dca7198f3f6d5'),
    },
  ),
  _converted(
    id: 'marian-en-fr',
    language: 'fr',
    files: const {
      'config.json': (233, '72901fbd8abd89fb5cf4a388f26fc681f5c4c58a1e1a88b30b879f107270e7ee'),
      'model.bin': (76714395, '236b63e3029611a328693d704067ebdd75b800e5b3011cdec3dad4287fd29a36'),
      'NOTICE': (569, '3a76b5f5a1c95b848595772ddc736e7277b0f66c4543bc6a4894d3bc446cd049'),
      'shared_vocabulary.json': (
        1112211,
        '528a527b3504bda364600f8bd7a2db1b0d7f82ef97a33ba0e80c289c4ae63c24',
      ),
      'source.spm': (778395, '173e9f493a668fe396d599e28d414a201193094e6ffd7a4678e5aab0f6d3d838'),
      'target.spm': (802397, '78d0e717c77053f1c4b856d8661d9cb87c64f083a35418c087b9146300e4f585'),
      'tokenizer_config.json': (
        42,
        '3492a8555368d21fc116cac84bdf551aee16783413be3afbfe4823de045960cf',
      ),
      'vocab.json': (1339166, '945c604346ce15ce4aff9001001e7f925e336d942c4087017f191871162cbdc4'),
    },
  ),
  _converted(
    id: 'marian-en-uk',
    language: 'uk',
    files: const {
      'config.json': (233, '72901fbd8abd89fb5cf4a388f26fc681f5c4c58a1e1a88b30b879f107270e7ee'),
      'model.bin': (77792355, '48294770fc750ac5ef9f998d46c99e30eddda60e8267a23ed7c3420ce7976e00'),
      'NOTICE': (569, '22f2fe24971d0a4af13020cb7996dca0c8548a8ce54d27085d6c0bf956011cdc'),
      'shared_vocabulary.json': (
        2132463,
        '7c3e274a6272691b85fd24075451d3abd4c72052c89bf672e571185ee44e311a',
      ),
      'source.spm': (808645, '4dc9157e60a15b157c2f3d5f892379b03aed111c9fe8ac7cecba5f2aa56379ef'),
      'target.spm': (1007605, '7abd810b2df512e6fe177f8732f6a0b3107614c84cc52aba20d805b4cb0d7b6b'),
      'tokenizer_config.json': (
        42,
        '33e70590c12ca4b2de861bec63a06eb2a884a1d835ecc6301122d77eb66b959f',
      ),
      'vocab.json': (2367710, '992107700c8d5f9c1f41fefa5f72ac99050852b39d75f979c4e59344e6d14770'),
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
  // The same Silero under MIT instead of CC BY-NC-SA, which is the whole
  // reason it is here: every voice of the CIS package also reads Russian, so
  // this is the Russian voice a build that earns money could carry. The
  // `nostress` build is the one that fits the pipeline -- plain
  // `v5_cis_base` expects the stress marked in the text (`в н+едрах`), and
  // what arrives here is Marian's output, unmarked.
  //
  // The voices are the package's own CIS speakers reading Russian, so
  // whatever accent they carry is theirs. The genders are measured the way
  // the others are; `ru_albina`, `ru_gamat` and `ru_igor` are left out
  // rather than guessed, sitting between the thresholds at 159 to 171 Hz
  // over four phrases each -- one phrase alone had put `ru_igor` on the
  // women's side at 180.
  _silero(
    id: 'silero-ru-cis-v5',
    version: 'v5 cis base',
    language: 'ru',
    fileName: 'v5_cis_base_nostress.pt',
    directory: 'ru',
    byteSize: 91685438,
    speaker: 'ru_ekaterina',
    voices: [
      _female('ru_aigul'),
      _male('ru_alexandr'),
      _female('ru_alfia'),
      _female('ru_alfia2'),
      _male('ru_bogdan'),
      _male('ru_dmitriy'),
      _female('ru_ekaterina'),
      _female('ru_vika'),
      _female('ru_karina'),
      _male('ru_kejilgan'),
      _female('ru_kermen'),
      _male('ru_marat'),
      _male('ru_miyau'),
      _female('ru_nurgul'),
      _female('ru_oksana'),
      _female('ru_onaoy'),
      _female('ru_ramilia'),
      _male('ru_roman'),
      _male('ru_safarhuja'),
      _female('ru_saida'),
      _male('ru_sibday'),
      _female('ru_zara'),
      _female('ru_zhadyra'),
      _female('ru_zhazira'),
      _female('ru_zinaida'),
      _male('ru_eduard'),
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

  // The one language with a voice and no translator: whisper is already
  // asked for English, so a phrase arrives in it and Marian is left out of
  // the session entirely -- a stage less to load, and a machine too small
  // for the translator can still dub.
  //
  // The package ships 118 numbered voices of uneven quality. All 118 were
  // synthesized and measured; the 13 that landed between the thresholds
  // (156 to 174 Hz) are left off the list rather than guessed at, which is
  // what the rest of the catalogue does. They are grouped by gender rather
  // than left in numeric order: a picker of a hundred names is read by
  // looking for a man's or a woman's voice first.
  _silero(
    id: 'silero-en-v3',
    version: 'v3',
    language: 'en',
    fileName: 'v3_en.pt',
    directory: 'en',
    byteSize: 57194546,
    speaker: 'en_0',
    voices: [
      for (final number in _englishWomen) _female('en_$number'),
      for (final number in _englishMen) _male('en_$number'),
    ],
  ),

  ModelPackage(
    id: voiceConverterModelId,
    kind: ModelKind.voiceConversion,
    version: 'V2',
    artifacts: [
      ModelArtifact(
        fileName: 'checkpoint.pth',
        url: Uri.parse(
          'https://huggingface.co/myshell-ai/OpenVoiceV2/resolve/main/converter/checkpoint.pth',
        ),
        byteSize: 131320490,
        hash: '9652c27e92b6b2a91632590ac9962ef7ae2b712e5c5b7f4c34ec55ee2b37ab9e',
      ),
      ModelArtifact(
        fileName: 'config.json',
        url: Uri.parse(
          'https://huggingface.co/myshell-ai/OpenVoiceV2/resolve/main/converter/config.json',
        ),
        byteSize: 838,
        hash: '9dfff60350b8c63f2c664efd92a61b2516efb22671466960f0e5dfebd881fa47',
      ),
    ],
  ),
];

/// Languages the pipeline can dub into, in catalogue order: those with a
/// voice and either a translator or nothing to translate.
///
/// English is the second kind. Whisper hands English over whatever the game
/// speaks, so dubbing into it asks for a voice and no Marian at all -- which
/// is also why it is the one language a machine too small for the translator
/// can still dub into.
///
/// Counted over the voices rather than the translators, because a language
/// may have more than one voice package and every one of them names it.
List<String> get dubbingLanguages {
  final languages = <String>[];
  for (final model in modelCatalog) {
    final language = model.language;
    if (model.kind != ModelKind.speech || language == null) continue;
    if (languages.contains(language)) continue;
    if (translationModelFor(language) == null && language != untranslatedDubbingLanguage) {
      continue;
    }
    languages.add(language);
  }
  return languages;
}

ModelPackage? _modelFor(ModelKind kind, String language) {
  for (final model in modelCatalog) {
    if (model.kind == kind && model.language == language) return model;
  }
  return null;
}

ModelPackage? translationModelFor(String language) => _modelFor(ModelKind.translation, language);

ModelPackage? speechModelFor(String language) => _modelFor(ModelKind.speech, language);

ModelPackage get whisperModel => modelCatalog.firstWhere((model) => model.id == whisperModelId);

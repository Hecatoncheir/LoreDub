// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/model_package.dart';
import '../../domain/spoken_language.dart';

/// Recognition needs nothing but Whisper: it turns speech in any language
/// into English on its own. What follows is Russian alone -- a Marian
/// translator and a Vosk voice. The other languages and every Silero voice
/// were taken out: Silero's are CC BY-NC, and the dubbing is to be free to
/// earn money with.
const whisperModelId = 'whisper-base';

/// OpenVoice V2's tone colour converter, which re-voices the voice in the timbre
/// of the phrase being answered. MIT, and the same package for every language.
const voiceConverterModelId = 'openvoice-v2-converter';

/// The English voice. It is named here because it is the one speech package
/// with no translator behind it: whisper hands English over whatever the game
/// speaks, so a session dubbing into English translates nothing.
const englishVoiceModelId = 'kokoro-en-1.0';

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

/// Where this project publishes the model files it prepares: a public
/// repository of their own, since the application's may be private and a
/// release asset of a private repository answers an anonymous download with
/// 404. It holds no code, only releases.
const _modelReleases = 'https://github.com/Hecatoncheir/LoreDub-models/releases/download';

/// Where the converted translators are published: an asset of the release
/// that carries them. Release assets are flat, so a file is named by its
/// package and its own name together.
const convertedTranslatorRelease = '$_modelReleases/translators-ct2-v1';

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

VoiceOption _male(String id) => VoiceOption(id, gender: VoiceGender.male);
VoiceOption _female(String id) => VoiceOption(id, gender: VoiceGender.female);

/// Where the Vosk voices are published: a release beside the translators'. The authors hand the model out as one archive with nothing to
/// check it by; laid out as files here, every one carries its size and its
/// SHA-256 and a download resumes where it stopped.
const voskVoiceRelease = '$_modelReleases/voices-vosk-v1';

/// Where the English voice is published: a release beside the Russian one.
/// Its authors publish the weights on Hugging Face and the ONNX export in
/// another project's GitHub release, neither with a digest to check them by;
/// laid out as files here, every one carries its size and its SHA-256.
const kokoroVoiceRelease = '$_modelReleases/voices-kokoro-v1';

/// A speech package, read by `vosk_voice.py` or `kokoro_voice.py` in the
/// worker -- which of the two is the package's own answer, not a flag.
/// `model.onnx` goes first either way: the pipeline names a speech package by
/// its first file, and the worker takes the directory it sits in.
ModelPackage _voice({
  required String id,
  required String release,
  required String engine,
  required String version,
  required String language,
  required String speaker,
  required List<VoiceOption> voices,

  /// File name to its size in bytes and its SHA-256.
  required Map<String, (int, String)> files,
}) => ModelPackage(
  id: id,
  kind: ModelKind.speech,
  language: language,
  speaker: speaker,
  version: version,
  engine: engine,
  voices: voices,
  artifacts: [
    for (final entry in files.entries)
      ModelArtifact(
        fileName: entry.key,
        url: Uri.parse('$release/$id-${entry.key}'),
        byteSize: entry.value.$1,
        hash: entry.value.$2,
      ),
  ],
);

/// Read only: a list handed out to every screen must not be changed by one
/// of them under the others.
final modelCatalog = List<ModelPackage>.unmodifiable(<ModelPackage>[
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

  // Vosk-TTS, the Russian voice, under Apache 2.0. Measured against the
  // Silero v5.3 it replaced over the same four characters, the two are a tie
  // under the converter (0.743 against 0.745 from a game line); Vosk reads a
  // line in 0.9 s on the processor to Silero's 0.2.
  //
  // Three of its five voices are listed: `female_0` and `female_2` measure
  // 173 Hz over four phrases, inside the gap the worker leaves undecided, and
  // are left out rather than guessed. The model's own names call them women;
  // one phrase alone had put `female_2` at 160 Hz, on the men's side.
  _voice(
    id: 'vosk-ru-0.9',
    release: voskVoiceRelease,
    engine: 'Vosk',
    version: '0.9',
    language: 'ru',
    speaker: 'female_1',
    voices: [
      _female('female_1'),
      _male('male_0'),
      _male('male_1'),
    ],
    files: {
      'model.onnx': (179314533, '0fa5a36b22a8bf7fe7179a3882c6371d2c01e5317019e717516f892d329c24b9'),
      'config.json': (1518, 'e155fb266a730e1858a2420442b465acf08a3236dffad7d1a507bf155b213d50'),
      'dictionary': (
        101431118,
        '2939e72c170bb41ac8e256828cca1c5fac4db1e36717f9f53fde843b00a220ba',
      ),
      'bert.onnx': (654361598, '2e2f1740eaae5e29c2b4844625cbb01ff644b2b5fb0560bd34374c35d8a092c1'),
      'bert-vocab.txt': (
        1780720,
        'bbe5063cc3d7a314effd90e9c5099cf493b81f2b9552c155264e16eeab074237',
      ),
      'NOTICE': (986, '43c94f4c0fd4a3bddff2546da61f4c7622e1922dadac6bc650d043f1261cb8a7'),
    },
  ),

  // Kokoro-82M, the English voice, under Apache 2.0 — and the one dubbing
  // language that needs no translator, whisper handing English over whatever
  // the game speaks. Measured against the Russian voice on the same machine
  // over fifteen game lines: a tie per second of speech on the processor
  // (RTF 0.29 against 0.31), 353 MB against 894 on disk, open in 1 s against
  // 17, and 174 ms a line on an RTX 3080 Ti — where Vosk pays about 1.9 s
  // for every line of a length it has not seen. Under the converter it lands
  // closer to the character it aims at (0.805 and 0.865 against two targets,
  // to Vosk's 0.763 and 0.839) and its worst line is far better (0.717
  // against 0.548).
  //
  // Twenty-three of the package's twenty-eight English voices are listed.
  // The genders are measured with the worker's own `median_f0` over two
  // lines each, and the names say nothing: `af_alloy` reads at 147 Hz, a
  // man, and `am_santa` at 182, a woman. Five sit inside the gap the worker
  // leaves undecided — af_kore 160, af_nicole 148, af_nova 165, af_sky 164
  // and am_eric 165 Hz — and are left out rather than guessed.
  _voice(
    id: englishVoiceModelId,
    release: kokoroVoiceRelease,
    engine: 'Kokoro',
    version: '1.0',
    language: untranslatedDubbingLanguage,
    speaker: 'af_heart',
    voices: [
      _male('af_alloy'),
      _female('af_aoede'),
      _female('af_bella'),
      _female('af_heart'),
      _female('af_jessica'),
      _female('af_river'),
      _female('af_sarah'),
      _male('am_adam'),
      _male('am_echo'),
      _male('am_fenrir'),
      _male('am_liam'),
      _male('am_michael'),
      _male('am_onyx'),
      _male('am_puck'),
      _female('am_santa'),
      _female('bf_alice'),
      _female('bf_emma'),
      _female('bf_isabella'),
      _female('bf_lily'),
      _male('bm_daniel'),
      _male('bm_fable'),
      _male('bm_george'),
      _male('bm_lewis'),
    ],
    files: {
      'model.onnx': (
        325505369,
        'beb0d1848dee9a49da392cc3df26958d46cfa35d321edf434f52949153f0df3a',
      ),
      'voices.bin': (
        28214398,
        'bca610b8308e8d99f32e6fe4197e7ec01679264efed0cac9140fe9c29f1fbf7d',
      ),
      'NOTICE': (1457, 'af1f04524c2d3723317856d20af6b1c5489dd653ffe334b19ca12e27a48c51de'),
    },
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
]);

/// Languages the pipeline can dub into, in catalogue order: those with a
/// voice and either a translator or nothing to translate.
///
/// English would be the second kind -- whisper hands English over whatever the
/// game speaks, so it would ask for a voice and no Marian -- but the catalogue
/// carries no English voice, so today this is Russian alone.
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

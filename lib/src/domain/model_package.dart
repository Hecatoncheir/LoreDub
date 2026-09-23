// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package_download.dart';

enum HashAlgorithm { md5, sha256 }

class ModelArtifact {
  const ModelArtifact({
    required this.fileName,
    required this.url,
    this.byteSize,
    this.hash,
    this.hashAlgorithm = HashAlgorithm.sha256,
  });

  final String fileName;
  final Uri url;
  final int? byteSize;
  final String? hash;
  final HashAlgorithm hashAlgorithm;
}

/// What a package is for. Recognition is language-independent — one Whisper
/// model turns any speech into English — while translation and speech come as
/// a pair per language the game can be dubbed into. The voice converter is
/// language-independent too: it only moves a timbre from one recording onto
/// another.
enum ModelKind { recognition, translation, speech, voiceConversion }

/// Whether a voice reads as a man or a woman.
///
/// [unknown] is a real answer, not a placeholder: a package may ship
/// voices under bare numbers, and guessing at them would make the automatic
/// choice pick wrongly with confidence.
enum VoiceGender { male, female, unknown }

/// How well a recognition model hears speech, as the models screen ranks
/// the builds against each other. A rank, not a score.
enum RecognitionQuality { fair, good, excellent }

/// One voice inside a speech package.
class VoiceOption {
  const VoiceOption(this.id, {this.gender = VoiceGender.unknown, this.language});

  final String id;
  final VoiceGender gender;

  /// The language this voice reads, in a package that reads several: a
  /// Russian line in an English voice would carry its accent. Null in a
  /// package of one language, whose every voice reads it.
  final String? language;

  bool reads(String code) => language == null || language == code;
}

class ModelPackage {
  const ModelPackage({
    required this.id,
    required this.artifacts,
    this.kind = ModelKind.recognition,
    this.language,
    this.speaker,
    this.version,
    this.engine,
    this.voices = const [],
    this.translatesSpeech = true,
    this.translationPrefix,
    this.quality,
    this.languages = const [],
    this.speakers = const {},
    this.languageModel = false,
    this.chatTemplate,
    this.clonesVoice = false,
  });

  final String id;
  final List<ModelArtifact> artifacts;
  final ModelKind kind;

  /// The language this package produces; null for recognition.
  final String? language;

  /// The languages it produces beside [language], for a package that serves
  /// several at once: one Qwen3-TTS reads Russian and English both, and one
  /// language model translates into either.
  final List<String> languages;

  /// The voice to synthesize with. The worker falls back to whatever the
  /// package actually ships if this name is not among its speakers.
  final String? speaker;

  /// The voice to synthesize each of [languages] with, where the package
  /// serves several and one voice would read the other language with an
  /// accent; [speaker] stands for a language named here.
  final Map<String, String> speakers;

  /// A translator that is a language model run by llama.cpp rather than
  /// Marian under CTranslate2: it translates from whatever language the
  /// game speaks, and is told the scene, the glossary and who is speaking
  /// with every line.
  final bool languageModel;

  /// One of llama.cpp's built-in chat templates, for a language model whose
  /// own cannot be rendered from a plain message: TranslateGemma's expects
  /// a message of its own shape, and the built-in `gemma` template wraps
  /// the same turns around ours. Null leaves the model's own in use.
  final String? chatTemplate;

  /// A voice that reads in the timbre of a clip it is handed itself, so the
  /// original voice needs no converter laid over the result, and one of
  /// the player's cards reads its lines from its own recording.
  final bool clonesVoice;

  /// Upstream release the voice comes from, shown in its name.
  final String? version;

  /// What reads a speech package, shown in its name beside the version: the
  /// catalogue carries a voice of one engine per language, and which engine
  /// it is says more about a package than its version does.
  final String? engine;

  /// Every voice the package ships, [speaker] among them.
  final List<VoiceOption> voices;

  /// Whether a recognition model can turn foreign speech into English on its
  /// own. `large-v3-turbo` cannot: OpenAI fine-tuned it without translation
  /// data, so it is asked to transcribe and only suits an English original.
  final bool translatesSpeech;

  /// A token a translation model needs in front of the text to name the
  /// target language, for the models that serve several at once.
  final String? translationPrefix;

  /// Where a recognition model stands among the others; null for the rest.
  final RecognitionQuality? quality;

  /// What the whole package costs to fetch.
  int get downloadBytes => artifacts.fold(0, (sum, artifact) => sum + (artifact.byteSize ?? 0));

  /// The file the pipeline hands to the runtime, for packages that ship one.
  String get primaryFileName => artifacts.first.fileName;

  /// Whether the package produces [code]: its language, or one of the
  /// others it serves.
  bool serves(String code) => language == code || languages.contains(code);

  /// Every language the package produces, [language] first.
  List<String> get servedLanguages => [?language, ...languages];

  /// The voice to read [code] in: the one named for it, or [speaker].
  String? speakerFor(String code) => speakers[code] ?? speaker;

  /// The voices that read [code]: every voice of a package of one language,
  /// and the ones named for it in a package of several.
  List<VoiceOption> voicesFor(String code) => [
    for (final voice in voices)
      if (voice.reads(code)) voice,
  ];

  /// The voices of [gender] -- among the ones that read [language], where
  /// one is named.
  List<String> voicesOf(VoiceGender gender, {String? language}) => [
    for (final voice in language == null ? voices : voicesFor(language))
      if (voice.gender == gender) voice.id,
  ];

  /// Whether the automatic choice has anything to choose between. A package
  /// with only women's voices cannot follow a man's, and saying so beats
  /// silently reading every character in the same voice.
  bool get canFollowSpeaker =>
      voicesOf(VoiceGender.male).isNotEmpty && voicesOf(VoiceGender.female).isNotEmpty;

  /// The same, among the voices that read [code].
  bool canFollowSpeakerIn(String code) =>
      voicesOf(VoiceGender.male, language: code).isNotEmpty &&
      voicesOf(VoiceGender.female, language: code).isNotEmpty;
}

class ModelInstallState with PackageDownload<ModelInstallState> {
  const ModelInstallState({
    required this.model,
    this.installed = false,
    this.progress,
    this.paused = false,
    this.error,
  });

  final ModelPackage model;

  @override
  final bool installed;

  @override
  final double? progress;

  /// Stopped part way, with what arrived kept on disk. Asking again carries
  /// on from there rather than starting over.
  @override
  final bool paused;

  @override
  final Object? error;

  @override
  String get packageId => model.id;

  /// [PackageDownload.arriving] in this screen's words.
  bool get downloading => arriving;

  @override
  ModelInstallState started() => copyWith(progress: progress ?? 0, paused: false, clearError: true);

  @override
  ModelInstallState reaching(double progress) => copyWith(progress: progress);

  @override
  ModelInstallState arrived() => copyWith(installed: true, clearProgress: true);

  @override
  ModelInstallState held() => copyWith(paused: true);

  @override
  ModelInstallState dropped() => copyWith(clearProgress: true, paused: false);

  @override
  ModelInstallState failing(Object error) => copyWith(clearProgress: true, error: error);

  ModelInstallState copyWith({
    bool? installed,
    double? progress,
    bool clearProgress = false,
    bool? paused,
    Object? error,
    bool clearError = false,
  }) => ModelInstallState(
    model: model,
    installed: installed ?? this.installed,
    progress: clearProgress ? null : progress ?? this.progress,
    paused: paused ?? this.paused,
    error: clearError ? null : error ?? this.error,
  );
}

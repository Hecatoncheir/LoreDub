// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

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
/// [unknown] is a real answer, not a placeholder: several Silero packages ship
/// voices under bare numbers, and guessing at them would make the automatic
/// choice pick wrongly with confidence.
enum VoiceGender { male, female, unknown }

/// How well a recognition model hears speech, as the models screen ranks
/// the builds against each other. A rank, not a score.
enum RecognitionQuality { fair, good, excellent }

/// One voice inside a speech package.
class VoiceOption {
  const VoiceOption(this.id, {this.gender = VoiceGender.unknown});

  final String id;
  final VoiceGender gender;
}

class ModelPackage {
  const ModelPackage({
    required this.id,
    required this.artifacts,
    this.kind = ModelKind.recognition,
    this.language,
    this.speaker,
    this.version,
    this.voices = const [],
    this.translatesSpeech = true,
    this.translationPrefix,
    this.quality,
  });

  final String id;
  final List<ModelArtifact> artifacts;
  final ModelKind kind;

  /// The language this package produces; null for recognition.
  final String? language;

  /// Silero voice to synthesize with. The worker falls back to whatever the
  /// package actually ships if this name is not among its speakers.
  final String? speaker;

  /// Upstream release the voice comes from, shown in its name.
  final String? version;

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

  List<String> voicesOf(VoiceGender gender) => [
    for (final voice in voices)
      if (voice.gender == gender) voice.id,
  ];

  /// Whether the automatic choice has anything to choose between. A package
  /// with only women's voices cannot follow a man's, and saying so beats
  /// silently reading every character in the same voice.
  bool get canFollowSpeaker =>
      voicesOf(VoiceGender.male).isNotEmpty && voicesOf(VoiceGender.female).isNotEmpty;
}

class ModelInstallState {
  const ModelInstallState({
    required this.model,
    this.installed = false,
    this.progress,
    this.paused = false,
    this.error,
  });

  final ModelPackage model;
  final bool installed;
  final double? progress;

  /// Stopped part way, with what arrived kept on disk. Asking again carries
  /// on from there rather than starting over.
  final bool paused;

  /// Why the download failed, as raised; written out by the interface.
  final Object? error;

  bool get downloading => progress != null && !paused;

  /// Whether there is an attempt to pause or cancel.
  bool get stoppable => progress != null;

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

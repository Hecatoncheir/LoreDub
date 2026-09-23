// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'app_settings.dart';
import 'language_pair.dart';
import 'model_package.dart';
import 'spoken_language.dart';

export 'language_pair.dart';

/// What the Screen page reads and what it says it in: the language of the
/// text on the screen and the dubbing language, picked as one choice.
typedef ScreenLanguages = ({String text, String dubbing});

/// What the settings and the installed packages together say the pipeline
/// will use.
///
/// Neither half answers on its own: the catalogue knows what a model can do,
/// the settings know which one was asked for. Keeping the pair here lets the
/// interface ask one object instead of joining the two at every call site.
class ModelSelection {
  const ModelSelection({required this.models, required this.settings});

  final List<ModelInstallState> models;
  final AppSettings settings;

  List<ModelInstallState> ofKind(ModelKind kind) =>
      models.where((state) => state.model.kind == kind).toList();

  /// Whisper is language-independent and OCR mode does without it entirely.
  List<ModelInstallState> get recognitionModels => ofKind(ModelKind.recognition);

  List<ModelInstallState> get translationModels => ofKind(ModelKind.translation);

  List<ModelInstallState> get speechModels => ofKind(ModelKind.speech);

  List<ModelInstallState> get voiceConverters => ofKind(ModelKind.voiceConversion);

  /// Every dubbing language with its translator and voice, in catalogue order.
  List<LanguagePair> get languagePairs {
    final languages = <String>[];
    for (final state in models) {
      final language = state.model.language;
      final paired =
          state.model.kind == ModelKind.translation || state.model.kind == ModelKind.speech;
      if (language != null && paired && !languages.contains(language)) languages.add(language);
    }
    ModelInstallState? find(ModelKind kind, String language) {
      for (final state in models) {
        if (state.model.kind == kind && state.model.language == language) return state;
      }
      return null;
    }

    return [
      for (final language in languages)
        LanguagePair(
          language: language,
          translation: find(ModelKind.translation, language),
          speech: find(ModelKind.speech, language),
        ),
    ];
  }

  /// The converter the original voice needs, if the catalogue has one.
  ModelInstallState? get voiceConverter => voiceConverters.firstOrNull;

  /// Whether a voice can be recorded at all: the converter is what measures
  /// one, and it is downloaded on the models screen.
  bool get measuresVoices => voiceConverter?.installed ?? false;

  /// Whether a sample can be spoken: the speech model of the dubbing
  /// language is what says it.
  bool get speaksSamples => forTargetLanguage(ModelKind.speech)?.installed ?? false;

  /// Whether each line will be re-voiced in the timbre of the phrase it
  /// answers.
  bool get clonesVoice => settings.originalVoice;

  /// Whether the worker will be told which character is speaking.
  ///
  /// The converter package is what hears that, so it is loaded for the
  /// fingerprints even when the timbre is not carried over: each character
  /// then keeps a voice of their own. One fixed voice has nobody to tell
  /// apart.
  bool get tracksSpeakers =>
      settings.voiceBank &&
      settings.voiceMode != VoiceMode.chosen &&
      (voiceConverter?.installed ?? false);

  /// Whether the converter is needed at all: to re-voice, or to tell the
  /// characters apart.
  bool get needsVoiceConverter => clonesVoice || tracksSpeakers;

  /// Whether this game's characters are kept between sessions.
  bool get keepsVoiceBank => settings.voiceBank && needsVoiceConverter;

  /// The package for the language being dubbed into, if the catalogue has one.
  ModelInstallState? forTargetLanguage(ModelKind kind) {
    for (final state in models) {
      if (state.model.kind == kind && state.model.language == settings.targetLanguage) {
        return state;
      }
    }
    return null;
  }

  /// The recognition model in use: the one the user picked, or the first the
  /// catalogue lists when the choice is unset or names a model that is gone.
  ModelInstallState? get recognition {
    final chosen = settings.whisperModel;
    for (final state in recognitionModels) {
      if (state.model.id == chosen) return state;
    }
    return recognitionModels.firstOrNull;
  }

  /// Whether the chosen model can turn foreign speech into English itself.
  /// When it cannot, the original has to already be in English.
  bool get recognitionTranslatesSpeech => recognition?.model.translatesSpeech ?? true;

  /// Whether the chosen model and the named original language disagree: a
  /// transcribe-only model handed, say, German would feed German text to an
  /// English-to-Russian translator.
  bool get recognitionNeedsEnglish =>
      !recognitionTranslatesSpeech &&
      !settings.detectSourceLanguage &&
      settings.sourceLanguage != 'en';

  /// Whether a phrase has to be translated before it is read.
  ///
  /// Dubbing into English does not: whisper is asked for English whatever the
  /// game speaks, so the line arrives in it and the translator is left out of
  /// the session entirely rather than run over its own language.
  bool get translates => settings.translates;

  ModelPackage? get speechPackage => forTargetLanguage(ModelKind.speech)?.model;

  /// Every voice that package offers, the catalogue default first.
  List<VoiceOption> get availableVoices => speechPackage?.voices ?? const [];

  /// Whether the voice can follow the original speaker: it needs a man's and
  /// a woman's voice to choose between.
  bool get canFollowSpeaker => speechPackage?.canFollowSpeaker ?? false;

  /// The voice mode that will run. A mode this setup cannot honour -- the
  /// automatic choice with a package of one voice -- is shown as the one
  /// that replaces it.
  VoiceMode get voiceMode => switch (settings.voiceMode) {
    VoiceMode.original => VoiceMode.original,
    VoiceMode.automatic when canFollowSpeaker => VoiceMode.automatic,
    _ => VoiceMode.chosen,
  };

  /// Whether the voice is picked by hand: always with one voice for every
  /// line, and for the original voice too when the package cannot follow the
  /// speaker, since its timbre needs a base to be laid over.
  bool get picksVoiceByHand =>
      voiceMode == VoiceMode.chosen || (voiceMode == VoiceMode.original && !canFollowSpeaker);

  /// Whether it actually will, given what the user asked for. The original
  /// voice builds on the automatic choice: a base of the right gender leaves
  /// the converter less to move.
  bool get followsSpeaker => (settings.automaticVoice || clonesVoice) && canFollowSpeaker;

  /// The voice a fixed choice would use, falling back to the catalogue's.
  String get voice {
    final package = speechPackage;
    if (package == null) return settings.voice;
    final named = settings.voice;
    if (named.isNotEmpty && package.voices.any((option) => option.id == named)) return named;
    return package.speaker ?? '';
  }

  /// Only the pair for the chosen language has to be present, not the whole
  /// catalogue: a player dubbing into Russian owes nothing to the French voice.
  bool get requiredModelsInstalled {
    if (models.isEmpty) return false;
    if (!(recognition?.installed ?? false)) return false;
    final pairInstalled =
        (!translates || (forTargetLanguage(ModelKind.translation)?.installed ?? false)) &&
        (forTargetLanguage(ModelKind.speech)?.installed ?? false);
    return pairInstalled && (!clonesVoice || (voiceConverter?.installed ?? false));
  }

  /// Whether the Screen page translates what it reads: English text, into
  /// a dubbing language that is not English. Text in the dubbing language is
  /// voiced as it is, and no translator is loaded for it.
  bool get screenTranslates => settings.screenTranslates;

  /// What the screen session needs: the voice of the dubbing language, and
  /// the translator where it translates. It reads the screen, so whisper
  /// plays no part, and text on a screen has no audio for the original
  /// voice to follow.
  bool get screenModelsInstalled =>
      models.isNotEmpty &&
      (!screenTranslates || (forTargetLanguage(ModelKind.translation)?.installed ?? false)) &&
      (forTargetLanguage(ModelKind.speech)?.installed ?? false);

  /// What the Screen page offers to read and say, chosen together: every
  /// language whose voice is on disk, read as it is, then English translated
  /// into every one whose translator is on disk as well -- with what is
  /// chosen now kept, so the choice stands on the list once its models are
  /// gone.
  List<ScreenLanguages> get screenLanguages {
    final offered = <ScreenLanguages>[
      for (final pair in languagePairs)
        if (pair.speech?.installed ?? false) (text: pair.language, dubbing: pair.language),
      for (final pair in languagePairs)
        if (pair.language != fallbackSpokenLanguage && pair.installed)
          (text: fallbackSpokenLanguage, dubbing: pair.language),
    ];
    final chosen = (text: settings.textLanguage, dubbing: settings.targetLanguage);
    return [...offered, if (!offered.contains(chosen)) chosen];
  }

  /// Whether a language is ready to dub into: its voice on disk, and its
  /// translator too where it has one. English has none to wait for.
  bool isLanguageReady(String language) {
    var translation = false;
    var speech = false;
    for (final state in models) {
      if (state.model.language != language || !state.installed) continue;
      translation |= state.model.kind == ModelKind.translation;
      speech |= state.model.kind == ModelKind.speech;
    }
    return (translation || language == untranslatedDubbingLanguage) && speech;
  }

  /// Whether live dubbing needs a game window chosen before it can start.
  /// The screen session always needs one: it reads that window.
  bool get requiresProcess => settings.audioCaptureSource == AudioCaptureSource.process;
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'app_settings.dart';
import 'language_pair.dart';
import 'model_package.dart';

export 'language_pair.dart';

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

  /// The original voice is taken from the original's audio, which subtitle
  /// mode never has.
  bool get canUseOriginalVoice => settings.captureMode != CaptureMode.ocr;

  /// Whether each line will be re-voiced in the timbre of the phrase it
  /// answers.
  bool get clonesVoice => settings.originalVoice && canUseOriginalVoice;

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
      settings.captureMode != CaptureMode.ocr &&
      !settings.detectSourceLanguage &&
      settings.sourceLanguage != 'en';

  ModelPackage? get speechPackage => forTargetLanguage(ModelKind.speech)?.model;

  /// Every voice that package offers, the catalogue default first.
  List<VoiceOption> get availableVoices => speechPackage?.voices ?? const [];

  /// Whether the voice can follow the original speaker: it needs a man's and
  /// a woman's voice to choose between, and audio to hear.
  bool get canFollowSpeaker =>
      (speechPackage?.canFollowSpeaker ?? false) && settings.captureMode != CaptureMode.ocr;

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
    final needsWhisper = settings.captureMode != CaptureMode.ocr;
    if (needsWhisper && !(recognition?.installed ?? false)) return false;
    final pairInstalled =
        (forTargetLanguage(ModelKind.translation)?.installed ?? false) &&
        (forTargetLanguage(ModelKind.speech)?.installed ?? false);
    return pairInstalled && (!clonesVoice || (voiceConverter?.installed ?? false));
  }

  /// What the snapshot session needs: the translator and the voice of the
  /// chosen language. It reads the screen, so whisper plays no part, and a
  /// selected line has no audio for the original voice to follow.
  bool get snapshotModelsInstalled =>
      models.isNotEmpty &&
      (forTargetLanguage(ModelKind.translation)?.installed ?? false) &&
      (forTargetLanguage(ModelKind.speech)?.installed ?? false);

  /// Whether both halves of a language's pair are on disk.
  bool isLanguageReady(String language) {
    var translation = false;
    var speech = false;
    for (final state in models) {
      if (state.model.language != language || !state.installed) continue;
      translation |= state.model.kind == ModelKind.translation;
      speech |= state.model.kind == ModelKind.speech;
    }
    return translation && speech;
  }

  /// Whether the pipeline needs a game window chosen before it can start.
  bool get requiresProcess =>
      settings.captureMode == CaptureMode.ocr ||
      settings.audioCaptureSource == AudioCaptureSource.process;
}

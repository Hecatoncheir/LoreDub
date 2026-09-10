// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'app_settings.dart';
import 'model_package.dart';

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

  /// Whether it actually will, given what the user asked for.
  bool get followsSpeaker => settings.automaticVoice && canFollowSpeaker;

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
    return (forTargetLanguage(ModelKind.translation)?.installed ?? false) &&
        (forTargetLanguage(ModelKind.speech)?.installed ?? false);
  }

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

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'LoreDub';

  @override
  String get navLive => 'Live';

  @override
  String get navModels => 'Models';

  @override
  String get navSettings => 'Settings';

  @override
  String get titleLive => 'Game dubbing';

  @override
  String get titleModels => 'Local models';

  @override
  String get titleSettings => 'Signal setup';

  @override
  String get statusIdle => 'Stopped';

  @override
  String get statusStarting => 'Starting…';

  @override
  String get statusListening => 'Listening';

  @override
  String get statusStopping => 'Stopping…';

  @override
  String get statusError => 'Error';

  @override
  String get modelsNeededTitle => 'The first run needs models';

  @override
  String get modelsNeededNote => 'They are downloaded separately and are not part of the setup.';

  @override
  String get modelsNeededAction => 'Open models';

  @override
  String get processLabel => 'Game process';

  @override
  String get processHint => 'Type a process name';

  @override
  String processEntry(String name, int pid) {
    return '$name  ·  PID $pid';
  }

  @override
  String get captureProcessNote => 'Only the selected process is captured';

  @override
  String get captureSystemNote => 'The whole default output is captured, except LoreDub itself';

  @override
  String get sourceSystem => 'All audio';

  @override
  String get sourceProcess => 'Process';

  @override
  String get refreshProcesses => 'Refresh the process list';

  @override
  String get targetLanguageLabel => 'Dubbing language';

  @override
  String languageWithoutModels(String language) {
    return '$language · not downloaded';
  }

  @override
  String get sourceLanguageLabel => 'Original language';

  @override
  String get detectLanguage => 'Detect language';

  @override
  String detectedLanguage(String language) {
    return 'Detected: $language';
  }

  @override
  String get startDubbing => 'Start dubbing';

  @override
  String get stopDubbing => 'Stop';

  @override
  String startingProgress(int percent) {
    return 'Starting $percent%';
  }

  @override
  String get startingPlain => 'Starting';

  @override
  String latencyMs(int value) {
    return '$value ms';
  }

  @override
  String get emptyTranscript => 'Recognized and translated lines will appear here';

  @override
  String pipelineSummary(String language) {
    return 'Whisper → English → Marian → $language → Silero';
  }

  @override
  String get sectionRecognition => 'SPEECH RECOGNITION';

  @override
  String get sectionRecognitionNote =>
      'Whisper turns speech in any language into English text. Recognition needs nothing else.';

  @override
  String get sectionTranslation => 'TEXT TRANSLATION MODELS';

  @override
  String get sectionTranslationNote => 'The English text is translated into the language you pick.';

  @override
  String get sectionSpeech => 'TEXT-TO-SPEECH MODELS';

  @override
  String get sectionSpeechNote => 'The voice has to speak the same language as the translation.';

  @override
  String get modelInstalled => 'Installed';

  @override
  String get modelDownload => 'Download';

  @override
  String get settingsCaptureSource => 'Text source';

  @override
  String get captureAudio => 'Game audio';

  @override
  String get captureOcr => 'Subtitles + OCR';

  @override
  String get settingsOcrRegion => 'Subtitle area';

  @override
  String ocrRegionValue(int percent) {
    return 'Bottom $percent% of the active game window';
  }

  @override
  String get settingsOriginalVolume => 'Original audio';

  @override
  String originalVolumeValue(int percent) {
    return 'Volume of the game process while dubbing: $percent%';
  }

  @override
  String get settingsTtsSpeed => 'Speech rate';

  @override
  String speedValue(String value) {
    return '$value×';
  }

  @override
  String get settingsPerformance => 'Performance';

  @override
  String performanceNote(int cores, int recommended) {
    return 'Recognition takes most of the delay and scales well with threads. Cores available: $cores, recommended $recommended.';
  }

  @override
  String get cpuThreads => 'CPU threads';

  @override
  String get settingsPython => 'Python runtime';

  @override
  String get pythonNote =>
      'Marian and Silero run on the python.exe you pick. The setup ships a ready runtime.';

  @override
  String get pythonFieldLabel => 'Python path or command';

  @override
  String get pythonFieldHelper => 'A full path, or python.exe resolved from PATH.';

  @override
  String get pythonFieldRequired => 'Name a python.exe';

  @override
  String get pythonSearching => 'Searching…';

  @override
  String get pythonFindAutomatically => 'Find automatically';

  @override
  String get pythonBundled => 'Bundled';

  @override
  String get save => 'Save';

  @override
  String get settingsModelDownloads => 'Model downloads';

  @override
  String get proxyNote => 'An optional HTTP or SOCKS5 proxy is used for model downloads only.';

  @override
  String get proxyLabel => 'HTTP / SOCKS5 proxy';

  @override
  String get proxyHelper => 'Format: http://… or socks5://user:password@host:port. Stored locally.';

  @override
  String get settingsModelDirectory => 'Model directory';

  @override
  String get modelDirectoryNote => 'Whisper, Marian and Silero are kept on this machine.';

  @override
  String get openInExplorer => 'Open in Explorer';

  @override
  String get settingsInterfaceLanguage => 'Interface language';

  @override
  String get interfaceLanguageNote => 'Applies immediately, without a restart.';

  @override
  String get modelWhisperTitle => 'Whisper base';

  @override
  String get modelWhisperNote =>
      'Speech recognition and translation of any language into English. Needed once, for every dubbing language.';

  @override
  String get modelTranslationNote => 'Local CPU translator by Helsinki-NLP/Marian, about 300 MB.';

  @override
  String modelTranslationTitle(String language) {
    return 'English → $language';
  }

  @override
  String modelVoiceTitle(String language, String version) {
    return '$language — Silero $version';
  }

  @override
  String modelVoiceNote(String language) {
    return '$language speech, 24 kHz.';
  }

  @override
  String get modelVoiceNoteRu =>
      'Russian speech, 24 kHz; voices xenia, aidar, baya, kseniya and eugene.';

  @override
  String get language_ar => 'Arabic';

  @override
  String get language_cs => 'Czech';

  @override
  String get language_de => 'German';

  @override
  String get language_en => 'English';

  @override
  String get language_es => 'Spanish';

  @override
  String get language_fr => 'French';

  @override
  String get language_it => 'Italian';

  @override
  String get language_ja => 'Japanese';

  @override
  String get language_ko => 'Korean';

  @override
  String get language_nl => 'Dutch';

  @override
  String get language_pl => 'Polish';

  @override
  String get language_pt => 'Portuguese';

  @override
  String get language_ru => 'Russian';

  @override
  String get language_sv => 'Swedish';

  @override
  String get language_tr => 'Turkish';

  @override
  String get language_uk => 'Ukrainian';

  @override
  String get language_zh => 'Chinese';

  @override
  String get translationTarget_ru => 'Russian';

  @override
  String get translationTarget_de => 'German';

  @override
  String get translationTarget_es => 'Spanish';

  @override
  String get translationTarget_fr => 'French';

  @override
  String get translationTarget_uk => 'Ukrainian';

  @override
  String get voiceName_ru => 'Russian voice';

  @override
  String get voiceName_de => 'German voice';

  @override
  String get voiceName_es => 'Spanish voice';

  @override
  String get voiceName_fr => 'French voice';

  @override
  String get voiceName_uk => 'Ukrainian voice';

  @override
  String get voiceSpeech_de => 'German';

  @override
  String get voiceSpeech_es => 'Spanish';

  @override
  String get voiceSpeech_fr => 'French';

  @override
  String get voiceSpeech_uk => 'Ukrainian';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'LoreDub';

  @override
  String get navLive => 'Эфир';

  @override
  String get navModels => 'Модели';

  @override
  String get navSettings => 'Настройки';

  @override
  String get titleLive => 'Перевод игры';

  @override
  String get titleModels => 'Локальные модели';

  @override
  String get titleSettings => 'Настройки потока';

  @override
  String get statusIdle => 'Остановлено';

  @override
  String get statusStarting => 'Запуск…';

  @override
  String get statusListening => 'Слушаю';

  @override
  String get statusStopping => 'Остановка…';

  @override
  String get statusError => 'Ошибка';

  @override
  String get modelsNeededTitle => 'Для первого запуска нужны модели';

  @override
  String get modelsNeededNote => 'Они скачиваются отдельно и не входят в setup.';

  @override
  String get modelsNeededAction => 'Открыть модели';

  @override
  String get processLabel => 'Процесс игры';

  @override
  String get processHint => 'Введите название процесса';

  @override
  String processEntry(String name, int pid) {
    return '$name  ·  PID $pid';
  }

  @override
  String get captureProcessNote => 'Захватывается только звук выбранного процесса';

  @override
  String get captureSystemNote => 'Захватывается весь дефолтный поток, кроме звука LoreDub';

  @override
  String get sourceSystem => 'Весь звук';

  @override
  String get sourceProcess => 'Процесс';

  @override
  String get refreshProcesses => 'Обновить список процессов';

  @override
  String get targetLanguageLabel => 'Язык перевода';

  @override
  String languageWithoutModels(String language) {
    return '$language · нет моделей';
  }

  @override
  String get sourceLanguageLabel => 'Язык оригинала';

  @override
  String get detectLanguage => 'Определять язык';

  @override
  String detectedLanguage(String language) {
    return 'Определён: $language';
  }

  @override
  String get startDubbing => 'Начать перевод';

  @override
  String get stopDubbing => 'Остановить';

  @override
  String startingProgress(int percent) {
    return 'Запуск $percent%';
  }

  @override
  String get startingPlain => 'Запуск';

  @override
  String latencyMs(int value) {
    return '$value мс';
  }

  @override
  String get emptyTranscript => 'Здесь появятся распознанные и переведённые реплики';

  @override
  String pipelineSummary(String language) {
    return 'Whisper → English → Marian → $language → Silero';
  }

  @override
  String get sectionRecognition => 'РАСПОЗНАВАНИЕ РЕЧИ';

  @override
  String get sectionRecognitionNote =>
      'Whisper переводит речь любого языка в английский текст. Больше для распознавания ничего скачивать не нужно.';

  @override
  String get sectionTranslation => 'МОДЕЛИ ДЛЯ ПЕРЕВОДА ТЕКСТА';

  @override
  String get sectionTranslationNote => 'Английский текст переводится на выбранный язык.';

  @override
  String get sectionSpeech => 'МОДЕЛИ ДЛЯ ОЗВУЧИВАНИЯ ТЕКСТА';

  @override
  String get sectionSpeechNote => 'Голос должен быть того же языка, что и перевод.';

  @override
  String get modelInstalled => 'Установлена';

  @override
  String get modelDownload => 'Скачать';

  @override
  String get settingsCaptureSource => 'Источник текста';

  @override
  String get captureAudio => 'Аудио игры';

  @override
  String get captureOcr => 'Субтитры + OCR';

  @override
  String get settingsOcrRegion => 'Область субтитров';

  @override
  String ocrRegionValue(int percent) {
    return 'Нижние $percent% активного окна игры';
  }

  @override
  String get settingsOriginalVolume => 'Оригинальный звук';

  @override
  String originalVolumeValue(int percent) {
    return 'Громкость процесса игры во время перевода: $percent%';
  }

  @override
  String get settingsTtsSpeed => 'Скорость озвучки';

  @override
  String speedValue(String value) {
    return '$value×';
  }

  @override
  String get settingsPerformance => 'Производительность';

  @override
  String performanceNote(int cores, int recommended) {
    return 'Распознавание занимает большую часть задержки и хорошо ускоряется потоками. Доступно ядер: $cores, рекомендуется $recommended.';
  }

  @override
  String get cpuThreads => 'Потоки CPU';

  @override
  String get settingsPython => 'Python runtime';

  @override
  String get pythonNote =>
      'Marian и Silero запускаются выбранным python.exe. Setup включает готовый runtime.';

  @override
  String get pythonFieldLabel => 'Путь или команда Python';

  @override
  String get pythonFieldHelper => 'Можно указать полный путь или python.exe из PATH.';

  @override
  String get pythonFieldRequired => 'Укажите python.exe';

  @override
  String get pythonSearching => 'Идёт поиск…';

  @override
  String get pythonFindAutomatically => 'Найти автоматически';

  @override
  String get pythonBundled => 'Встроенный';

  @override
  String get save => 'Сохранить';

  @override
  String get settingsModelDownloads => 'Загрузка моделей';

  @override
  String get proxyNote =>
      'Необязательный HTTP или SOCKS5 proxy применяется только при скачивании моделей.';

  @override
  String get proxyLabel => 'HTTP / SOCKS5 proxy';

  @override
  String get proxyHelper =>
      'Формат: http://… или socks5://user:password@host:port. Значение хранится локально.';

  @override
  String get settingsModelDirectory => 'Каталог моделей';

  @override
  String get modelDirectoryNote => 'Whisper, Marian и Silero хранятся локально.';

  @override
  String get openInExplorer => 'Открыть в Explorer';

  @override
  String get settingsInterfaceLanguage => 'Язык интерфейса';

  @override
  String get interfaceLanguageNote => 'Меняется сразу, без перезапуска.';

  @override
  String get modelWhisperTitle => 'Whisper base';

  @override
  String get modelWhisperNote =>
      'Распознавание речи и перевод любого языка на английский. Нужна один раз, для всех языков озвучки.';

  @override
  String get modelTranslationNote => 'Локальный CPU-переводчик Helsinki-NLP/Marian, около 300 МБ.';

  @override
  String modelTranslationTitle(String language) {
    return 'Английский → $language';
  }

  @override
  String modelVoiceTitle(String language, String version) {
    return '$language — Silero $version';
  }

  @override
  String modelVoiceNote(String language) {
    return '$language речь, 24 kHz.';
  }

  @override
  String get modelVoiceNoteRu =>
      'Русская речь, 24 kHz; голоса xenia, aidar, baya, kseniya и eugene.';

  @override
  String get language_ar => 'Арабский';

  @override
  String get language_cs => 'Чешский';

  @override
  String get language_de => 'Немецкий';

  @override
  String get language_en => 'Английский';

  @override
  String get language_es => 'Испанский';

  @override
  String get language_fr => 'Французский';

  @override
  String get language_it => 'Итальянский';

  @override
  String get language_ja => 'Японский';

  @override
  String get language_ko => 'Корейский';

  @override
  String get language_nl => 'Нидерландский';

  @override
  String get language_pl => 'Польский';

  @override
  String get language_pt => 'Португальский';

  @override
  String get language_ru => 'Русский';

  @override
  String get language_sv => 'Шведский';

  @override
  String get language_tr => 'Турецкий';

  @override
  String get language_uk => 'Украинский';

  @override
  String get language_zh => 'Китайский';

  @override
  String get translationTarget_ru => 'русский';

  @override
  String get translationTarget_de => 'немецкий';

  @override
  String get translationTarget_es => 'испанский';

  @override
  String get translationTarget_fr => 'французский';

  @override
  String get translationTarget_uk => 'украинский';

  @override
  String get voiceName_ru => 'Русский голос';

  @override
  String get voiceName_de => 'Немецкий голос';

  @override
  String get voiceName_es => 'Испанский голос';

  @override
  String get voiceName_fr => 'Французский голос';

  @override
  String get voiceName_uk => 'Украинский голос';

  @override
  String get voiceSpeech_de => 'Немецкая';

  @override
  String get voiceSpeech_es => 'Испанская';

  @override
  String get voiceSpeech_fr => 'Французская';

  @override
  String get voiceSpeech_uk => 'Украинская';
}

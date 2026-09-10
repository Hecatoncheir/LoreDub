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
  String get transcriptClear => 'Очистить';

  @override
  String get transcriptClearTooltip => 'Убрать все реплики из списка';

  @override
  String pipelineSummary(String language) {
    return 'Whisper → English → Marian → $language → Silero';
  }

  @override
  String get sectionRecognition => 'РАСПОЗНАВАНИЕ РЕЧИ';

  @override
  String get sectionRecognitionNote =>
      'Whisper переводит речь любого языка в английский текст. Нужна одна модель — чем больше, тем точнее и медленнее.';

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
  String get downloadPause => 'Приостановить';

  @override
  String get downloadResume => 'Продолжить';

  @override
  String get downloadCancel => 'Отменить';

  @override
  String get downloadPaused => 'Приостановлено';

  @override
  String get downloadStopping => 'Останавливаю…';

  @override
  String get downloadCancelNotResumable => 'Отменить (продолжить будет нельзя)';

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
  String get settingsVoice => 'Голос озвучки';

  @override
  String get voiceNote =>
      '«Автоматически» подбирает мужской или женский голос под голос оригинала, отдельно для каждой реплики.';

  @override
  String get voiceAutomatic => 'Автоматически';

  @override
  String get voiceFixed => 'Выбрать';

  @override
  String get voiceFieldLabel => 'Голос';

  @override
  String get voiceUnavailable =>
      'В пакете этого языка голоса только одного пола — выбрать можно, но подстраиваться не под что.';

  @override
  String get voiceNeedsAudio =>
      'В режиме субтитров оригинал не слышен, поэтому голос берётся выбранный.';

  @override
  String voiceSpeaking(String name) {
    return 'Сейчас говорит: $name';
  }

  @override
  String get voiceGenderMale => 'мужской';

  @override
  String get voiceGenderFemale => 'женский';

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
  String modelWhisperTitle(String version) {
    return 'Whisper $version';
  }

  @override
  String get modelWhisperNote =>
      'Распознавание речи и перевод любого языка на английский. Одна модель на все языки озвучки.';

  @override
  String get modelWhisperTranscribeOnly =>
      'Не переводит речь: подойдёт, только если оригинал уже на английском.';

  @override
  String get recognitionNeedsEnglish =>
      'Выбранная модель не переводит речь, а язык оригинала указан не английский.';

  @override
  String modelTranslationNote(String size) {
    return 'Локальный переводчик Helsinki-NLP/Marian, $size.';
  }

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

  @override
  String failureWhisperMissing(String detail) {
    return 'Не найден whisper-cli.exe: $detail. Установите LoreDub через setup или подготовьте runtime командой scripts/prepare_windows_runtime.ps1.';
  }

  @override
  String failureWhisperModelMissing(String detail) {
    return 'Не найдена модель Whisper: $detail. Установите её на вкладке «Модели».';
  }

  @override
  String failureWhisperFailed(String detail) {
    return 'whisper.cpp: $detail';
  }

  @override
  String failurePythonMissing(String detail) {
    return 'Не найден Python: $detail. Установите LoreDub через setup или подготовьте runtime командой scripts/prepare_windows_runtime.ps1.';
  }

  @override
  String get failurePythonStoreAlias =>
      'В PATH найден только ярлык Microsoft Store вместо Python. Он не запускает интерпретатор. Выберите встроенный runtime или укажите полный путь к python.exe с установленными torch и transformers.';

  @override
  String get failurePythonSearchEmpty =>
      'Python не найден в PATH и в стандартных каталогах установки. Укажите путь к python.exe вручную или используйте встроенный runtime.';

  @override
  String failurePythonSearchNoDependencies(String detail) {
    return 'Не найден Python с torch и transformers. Проверено: $detail.';
  }

  @override
  String failurePythonSearchFailed(String detail) {
    return 'Не удалось найти Python: $detail';
  }

  @override
  String pythonCandidateWithoutDependencies(String path, String version) {
    return '$path (Python $version, нет torch/transformers)';
  }

  @override
  String pythonCandidateUnusable(String path) {
    return '$path (не запускается)';
  }

  @override
  String failureWorkerExited(int code, String detail) {
    return 'Marian/Silero worker завершился с кодом $code: $detail';
  }

  @override
  String failureWorkerExitedSilently(int code) {
    return 'Marian/Silero worker завершился с кодом $code без вывода. Проверьте выбранный python.exe: в нём должны быть torch и transformers.';
  }

  @override
  String failureWorkerTimeout(String detail) {
    return 'Marian/Silero не ответил за 2 минуты. Последний вывод: $detail';
  }

  @override
  String get failureWorkerTimeoutSilent =>
      'Marian/Silero не ответил за 2 минуты. Вывода процесса нет.';

  @override
  String get failureWorkerNotRunning => 'Marian/Silero worker не запущен';

  @override
  String failureWorkerFailed(String detail) {
    return 'Marian/Silero: $detail';
  }

  @override
  String get failurePipelineStopped => 'Перевод остановлен';

  @override
  String get failureWindowsOnly => 'Локальный pipeline доступен только в Windows';

  @override
  String get failureExplorerUnsupported => 'Открытие каталога поддерживается только в Windows';

  @override
  String failureDownloadRejected(String detail) {
    return 'Сервер вернул $detail';
  }

  @override
  String failureVerificationFailed(String detail) {
    return 'Проверка $detail не пройдена';
  }

  @override
  String get failureSocksLookupFailed => 'Не удалось определить адрес SOCKS5 proxy';

  @override
  String get failureProxyFormat =>
      'Укажите proxy в формате http://host:port или socks5://host:port';

  @override
  String get failureProxyPort => 'Порт proxy должен быть от 1 до 65535';

  @override
  String failureInitializationFailed(String detail) {
    return 'Не удалось инициализировать приложение: $detail';
  }

  @override
  String get settingsComputeDevice => 'Вычислительное устройство';

  @override
  String get computeDeviceNote =>
      '«Автоматически» само определяет видеокарту. Каждую модель можно перевести на другое устройство отдельно.';

  @override
  String get computeDeviceAuto => 'Автоматически';

  @override
  String get computeDeviceGpu => 'GPU';

  @override
  String get computeDeviceCpu => 'CPU';

  @override
  String get computeStageRecognition => 'Whisper';

  @override
  String get computeStageTranslation => 'Перевод';

  @override
  String get computeStageSpeech => 'Озвучка';

  @override
  String get computeBackendCuda => 'CUDA';

  @override
  String get computeBackendVulkan => 'Vulkan';

  @override
  String get computeBackendCpu => 'CPU';

  @override
  String computeAdapterDetected(String name) {
    return 'Видеокарта: $name';
  }

  @override
  String get computeNoAdapter => 'Подходящая видеокарта не найдена — всё считается на процессоре';

  @override
  String get computeBackendUnsupported => 'Не поддерживается этой моделью';

  @override
  String get computeBackendNoHardware => 'Нет подходящей видеокарты или драйвера';

  @override
  String computeRuntimeMissing(String size) {
    return 'Нужен пакет $size';
  }

  @override
  String get computeRuntimeDownload => 'Скачать';

  @override
  String get computeRuntimeRemove => 'Удалить';

  @override
  String get computeRuntimeRemoveTitle => 'Точно удалить?';

  @override
  String computeRuntimeRemoveMessage(String size) {
    return 'Пакет $size будет удалён с диска, и стадия вернётся на процессор. Скачать его заново можно в любой момент.';
  }

  @override
  String get computeRuntimeRemoveConfirm => 'Удалить полностью';

  @override
  String get computeRuntimeRemoveCancel => 'Оставить';

  @override
  String get computeRuntimeInstalling => 'Установка…';

  @override
  String get computeSpeechCpuOnly =>
      'Silero считается на процессоре: перенос на видеокарту стоит дороже самой работы.';

  @override
  String failureRuntimeIncomplete(String detail) {
    return 'В скачанном пакете нет $detail';
  }

  @override
  String failureRuntimeInstallFailed(String detail) {
    return 'Не удалось установить GPU-рантайм: $detail';
  }

  @override
  String updateCurrent(String version) {
    return 'Версия $version';
  }

  @override
  String get updateChecking => 'Проверяю обновления…';

  @override
  String get updateUpToDate => 'Установлена последняя версия';

  @override
  String get updateCheckAgain => 'Проверить обновления';

  @override
  String updateOpenRelease(String version) {
    return 'Открыть страницу версии $version';
  }

  @override
  String get updateFailed => 'Не удалось проверить обновления';

  @override
  String get updateAvailableTitle => 'Вышла новая версия LoreDub';

  @override
  String updateAvailableBody(String version) {
    return 'Доступна версия $version. Нажмите стрелку рядом с номером версии, чтобы открыть страницу релиза.';
  }

  @override
  String failureUpdateCheckFailed(String detail) {
    return 'Не удалось проверить обновления: $detail';
  }

  @override
  String get failureUnknown => 'Неизвестная ошибка';

  @override
  String get stagePython => 'Запуск Python';

  @override
  String get stageTorch => 'Загрузка PyTorch';

  @override
  String get stageTransformers => 'Загрузка Transformers';

  @override
  String get stageTranslator => 'Загрузка переводчика';

  @override
  String get stageSpeech => 'Загрузка синтеза речи';

  @override
  String get stageCapture => 'Запуск захвата';
}

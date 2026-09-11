import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('ru')];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'LoreDub'**
  String get appTitle;

  /// No description provided for @navLive.
  ///
  /// In ru, this message translates to:
  /// **'Эфир'**
  String get navLive;

  /// No description provided for @navModels.
  ///
  /// In ru, this message translates to:
  /// **'Модели'**
  String get navModels;

  /// No description provided for @navSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get navSettings;

  /// No description provided for @titleLive.
  ///
  /// In ru, this message translates to:
  /// **'Перевод игры'**
  String get titleLive;

  /// No description provided for @titleModels.
  ///
  /// In ru, this message translates to:
  /// **'Локальные модели'**
  String get titleModels;

  /// No description provided for @titleSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки потока'**
  String get titleSettings;

  /// No description provided for @statusIdle.
  ///
  /// In ru, this message translates to:
  /// **'Остановлено'**
  String get statusIdle;

  /// No description provided for @statusStarting.
  ///
  /// In ru, this message translates to:
  /// **'Запуск…'**
  String get statusStarting;

  /// No description provided for @statusListening.
  ///
  /// In ru, this message translates to:
  /// **'Слушаю'**
  String get statusListening;

  /// No description provided for @statusStopping.
  ///
  /// In ru, this message translates to:
  /// **'Остановка…'**
  String get statusStopping;

  /// No description provided for @statusError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка'**
  String get statusError;

  /// No description provided for @modelsNeededTitle.
  ///
  /// In ru, this message translates to:
  /// **'Для первого запуска нужны модели'**
  String get modelsNeededTitle;

  /// No description provided for @modelsNeededNote.
  ///
  /// In ru, this message translates to:
  /// **'Они скачиваются отдельно и не входят в setup.'**
  String get modelsNeededNote;

  /// No description provided for @modelsNeededAction.
  ///
  /// In ru, this message translates to:
  /// **'Открыть модели'**
  String get modelsNeededAction;

  /// No description provided for @processLabel.
  ///
  /// In ru, this message translates to:
  /// **'Процесс игры'**
  String get processLabel;

  /// No description provided for @processHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите название процесса'**
  String get processHint;

  /// No description provided for @processEntry.
  ///
  /// In ru, this message translates to:
  /// **'{name}  ·  PID {pid}'**
  String processEntry(String name, int pid);

  /// No description provided for @captureProcessNote.
  ///
  /// In ru, this message translates to:
  /// **'Захватывается только звук выбранного процесса'**
  String get captureProcessNote;

  /// No description provided for @captureSystemNote.
  ///
  /// In ru, this message translates to:
  /// **'Захватывается весь дефолтный поток, кроме звука LoreDub'**
  String get captureSystemNote;

  /// No description provided for @captureOcrNote.
  ///
  /// In ru, this message translates to:
  /// **'Субтитры читаются с окна выбранной игры, пока оно активно'**
  String get captureOcrNote;

  /// No description provided for @sourceSystem.
  ///
  /// In ru, this message translates to:
  /// **'Весь звук'**
  String get sourceSystem;

  /// No description provided for @sourceProcess.
  ///
  /// In ru, this message translates to:
  /// **'Процесс'**
  String get sourceProcess;

  /// No description provided for @refreshProcesses.
  ///
  /// In ru, this message translates to:
  /// **'Обновить список процессов'**
  String get refreshProcesses;

  /// No description provided for @targetLanguageLabel.
  ///
  /// In ru, this message translates to:
  /// **'Язык перевода'**
  String get targetLanguageLabel;

  /// No description provided for @languageWithoutModels.
  ///
  /// In ru, this message translates to:
  /// **'{language} · нет моделей'**
  String languageWithoutModels(String language);

  /// No description provided for @sourceLanguageLabel.
  ///
  /// In ru, this message translates to:
  /// **'Язык оригинала'**
  String get sourceLanguageLabel;

  /// No description provided for @detectLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Определять язык'**
  String get detectLanguage;

  /// No description provided for @detectedLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Определён: {language}'**
  String detectedLanguage(String language);

  /// No description provided for @startDubbing.
  ///
  /// In ru, this message translates to:
  /// **'Начать перевод'**
  String get startDubbing;

  /// No description provided for @stopDubbing.
  ///
  /// In ru, this message translates to:
  /// **'Остановить'**
  String get stopDubbing;

  /// No description provided for @startingProgress.
  ///
  /// In ru, this message translates to:
  /// **'Запуск {percent}%'**
  String startingProgress(int percent);

  /// No description provided for @startingPlain.
  ///
  /// In ru, this message translates to:
  /// **'Запуск'**
  String get startingPlain;

  /// No description provided for @latencyMs.
  ///
  /// In ru, this message translates to:
  /// **'{value} мс'**
  String latencyMs(int value);

  /// No description provided for @emptyTranscript.
  ///
  /// In ru, this message translates to:
  /// **'Здесь появятся распознанные и переведённые реплики'**
  String get emptyTranscript;

  /// No description provided for @transcriptClear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить'**
  String get transcriptClear;

  /// No description provided for @transcriptClearTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Убрать все реплики из списка'**
  String get transcriptClearTooltip;

  /// No description provided for @pipelineSummary.
  ///
  /// In ru, this message translates to:
  /// **'Whisper → English → Marian → {language} → Silero'**
  String pipelineSummary(String language);

  /// No description provided for @pipelineSummaryOcr.
  ///
  /// In ru, this message translates to:
  /// **'Windows OCR → English → Marian → {language} → Silero'**
  String pipelineSummaryOcr(String language);

  /// No description provided for @sectionRecognition.
  ///
  /// In ru, this message translates to:
  /// **'РАСПОЗНАВАНИЕ РЕЧИ'**
  String get sectionRecognition;

  /// No description provided for @sectionRecognitionNote.
  ///
  /// In ru, this message translates to:
  /// **'Whisper переводит речь любого языка в английский текст. Нужна одна модель — чем больше, тем точнее и медленнее.'**
  String get sectionRecognitionNote;

  /// No description provided for @sectionTranslation.
  ///
  /// In ru, this message translates to:
  /// **'МОДЕЛИ ДЛЯ ПЕРЕВОДА ТЕКСТА'**
  String get sectionTranslation;

  /// No description provided for @sectionTranslationNote.
  ///
  /// In ru, this message translates to:
  /// **'Английский текст переводится на выбранный язык.'**
  String get sectionTranslationNote;

  /// No description provided for @sectionSpeech.
  ///
  /// In ru, this message translates to:
  /// **'МОДЕЛИ ДЛЯ ОЗВУЧИВАНИЯ ТЕКСТА'**
  String get sectionSpeech;

  /// No description provided for @sectionSpeechNote.
  ///
  /// In ru, this message translates to:
  /// **'Голос должен быть того же языка, что и перевод.'**
  String get sectionSpeechNote;

  /// No description provided for @modelInstalled.
  ///
  /// In ru, this message translates to:
  /// **'Установлена'**
  String get modelInstalled;

  /// No description provided for @downloadPause.
  ///
  /// In ru, this message translates to:
  /// **'Приостановить'**
  String get downloadPause;

  /// No description provided for @downloadResume.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get downloadResume;

  /// No description provided for @downloadCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отменить'**
  String get downloadCancel;

  /// No description provided for @downloadPaused.
  ///
  /// In ru, this message translates to:
  /// **'Приостановлено'**
  String get downloadPaused;

  /// No description provided for @downloadStopping.
  ///
  /// In ru, this message translates to:
  /// **'Останавливаю…'**
  String get downloadStopping;

  /// No description provided for @downloadCancelNotResumable.
  ///
  /// In ru, this message translates to:
  /// **'Отменить (продолжить будет нельзя)'**
  String get downloadCancelNotResumable;

  /// No description provided for @modelDownload.
  ///
  /// In ru, this message translates to:
  /// **'Скачать'**
  String get modelDownload;

  /// No description provided for @settingsCaptureSource.
  ///
  /// In ru, this message translates to:
  /// **'Источник текста'**
  String get settingsCaptureSource;

  /// No description provided for @captureAudio.
  ///
  /// In ru, this message translates to:
  /// **'Аудио игры'**
  String get captureAudio;

  /// No description provided for @captureOcr.
  ///
  /// In ru, this message translates to:
  /// **'Субтитры + OCR'**
  String get captureOcr;

  /// No description provided for @settingsOcrRegion.
  ///
  /// In ru, this message translates to:
  /// **'Область субтитров'**
  String get settingsOcrRegion;

  /// No description provided for @ocrRegionNote.
  ///
  /// In ru, this message translates to:
  /// **'Обведите мышью место, где игра пишет субтитры. Экран ниже — это окно игры в уменьшенном виде; рамка хранится в долях окна, поэтому подходит к любому разрешению.'**
  String get ocrRegionNote;

  /// No description provided for @ocrRegionValue.
  ///
  /// In ru, this message translates to:
  /// **'Рамка {width} × {height}% окна, отступ {left}% слева и {top}% сверху'**
  String ocrRegionValue(int width, int height, int left, int top);

  /// No description provided for @ocrRegionHelp.
  ///
  /// In ru, this message translates to:
  /// **'Тяните рамку, чтобы сдвинуть её, а углы и стороны — чтобы изменить размер. С клавиатуры стрелки двигают рамку, Shift со стрелками меняет размер.'**
  String get ocrRegionHelp;

  /// No description provided for @ocrRegionReset.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить'**
  String get ocrRegionReset;

  /// No description provided for @settingsOriginalVolume.
  ///
  /// In ru, this message translates to:
  /// **'Оригинальный звук'**
  String get settingsOriginalVolume;

  /// No description provided for @originalVolumeValue.
  ///
  /// In ru, this message translates to:
  /// **'Громкость процесса игры во время перевода: {percent}%'**
  String originalVolumeValue(int percent);

  /// No description provided for @settingsTtsSpeed.
  ///
  /// In ru, this message translates to:
  /// **'Скорость озвучки'**
  String get settingsTtsSpeed;

  /// No description provided for @speedValue.
  ///
  /// In ru, this message translates to:
  /// **'{value}×'**
  String speedValue(String value);

  /// No description provided for @settingsVoice.
  ///
  /// In ru, this message translates to:
  /// **'Голос озвучки'**
  String get settingsVoice;

  /// No description provided for @voiceNote.
  ///
  /// In ru, this message translates to:
  /// **'«Автоматически» подбирает мужской или женский голос под голос оригинала, отдельно для каждой реплики. «Голос оригинала» вдобавок переносит на озвучку тембр говорящего.'**
  String get voiceNote;

  /// No description provided for @voiceAutomatic.
  ///
  /// In ru, this message translates to:
  /// **'Автоматически'**
  String get voiceAutomatic;

  /// No description provided for @voiceFixed.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать'**
  String get voiceFixed;

  /// No description provided for @voiceFieldLabel.
  ///
  /// In ru, this message translates to:
  /// **'Голос'**
  String get voiceFieldLabel;

  /// No description provided for @voiceUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'В пакете этого языка голоса только одного пола — выбрать можно, но подстраиваться не под что.'**
  String get voiceUnavailable;

  /// No description provided for @voiceNeedsAudio.
  ///
  /// In ru, this message translates to:
  /// **'В режиме субтитров оригинал не слышен, поэтому голос берётся выбранный.'**
  String get voiceNeedsAudio;

  /// No description provided for @voiceOriginal.
  ///
  /// In ru, this message translates to:
  /// **'Голос оригинала'**
  String get voiceOriginal;

  /// No description provided for @voiceOriginalNote.
  ///
  /// In ru, this message translates to:
  /// **'Тембр берётся из каждой реплики и накладывается на голос Silero. На процессоре реплика звучит примерно на секунду позже.'**
  String get voiceOriginalNote;

  /// No description provided for @voiceOriginalMissing.
  ///
  /// In ru, this message translates to:
  /// **'Нужен конвертер голоса: скачайте его в разделе «Голос оригинала» на экране «Модели».'**
  String get voiceOriginalMissing;

  /// No description provided for @voiceOriginalSpeaking.
  ///
  /// In ru, this message translates to:
  /// **'Тембр оригинала поверх голоса {name}'**
  String voiceOriginalSpeaking(String name);

  /// No description provided for @sectionVoiceConversion.
  ///
  /// In ru, this message translates to:
  /// **'ГОЛОС ОРИГИНАЛА'**
  String get sectionVoiceConversion;

  /// No description provided for @sectionVoiceConversionNote.
  ///
  /// In ru, this message translates to:
  /// **'Нужен только для режима «Голос оригинала»: переносит на озвучку тембр говорящего. Один конвертер на все языки.'**
  String get sectionVoiceConversionNote;

  /// No description provided for @modelConverterTitle.
  ///
  /// In ru, this message translates to:
  /// **'OpenVoice {version} — конвертер голоса'**
  String modelConverterTitle(String version);

  /// No description provided for @modelConverterNote.
  ///
  /// In ru, this message translates to:
  /// **'Переносит тембр оригинальной реплики на голос Silero, {size}.'**
  String modelConverterNote(String size);

  /// No description provided for @stageConverter.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка конвертера голоса'**
  String get stageConverter;

  /// No description provided for @voiceSpeaking.
  ///
  /// In ru, this message translates to:
  /// **'Сейчас говорит: {name}'**
  String voiceSpeaking(String name);

  /// No description provided for @voiceGenderMale.
  ///
  /// In ru, this message translates to:
  /// **'мужской'**
  String get voiceGenderMale;

  /// No description provided for @voiceGenderFemale.
  ///
  /// In ru, this message translates to:
  /// **'женский'**
  String get voiceGenderFemale;

  /// No description provided for @settingsPerformance.
  ///
  /// In ru, this message translates to:
  /// **'Производительность'**
  String get settingsPerformance;

  /// No description provided for @performanceNote.
  ///
  /// In ru, this message translates to:
  /// **'Распознавание занимает большую часть задержки и хорошо ускоряется потоками. Доступно ядер: {cores}, рекомендуется {recommended}.'**
  String performanceNote(int cores, int recommended);

  /// No description provided for @cpuThreads.
  ///
  /// In ru, this message translates to:
  /// **'Потоки CPU'**
  String get cpuThreads;

  /// No description provided for @settingsPython.
  ///
  /// In ru, this message translates to:
  /// **'Python runtime'**
  String get settingsPython;

  /// No description provided for @pythonNote.
  ///
  /// In ru, this message translates to:
  /// **'Marian и Silero запускаются выбранным python.exe. Setup включает готовый runtime.'**
  String get pythonNote;

  /// No description provided for @pythonFieldLabel.
  ///
  /// In ru, this message translates to:
  /// **'Путь или команда Python'**
  String get pythonFieldLabel;

  /// No description provided for @pythonFieldHelper.
  ///
  /// In ru, this message translates to:
  /// **'Можно указать полный путь или python.exe из PATH.'**
  String get pythonFieldHelper;

  /// No description provided for @pythonFieldRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите python.exe'**
  String get pythonFieldRequired;

  /// No description provided for @pythonSearching.
  ///
  /// In ru, this message translates to:
  /// **'Идёт поиск…'**
  String get pythonSearching;

  /// No description provided for @pythonFindAutomatically.
  ///
  /// In ru, this message translates to:
  /// **'Найти автоматически'**
  String get pythonFindAutomatically;

  /// No description provided for @pythonBundled.
  ///
  /// In ru, this message translates to:
  /// **'Встроенный'**
  String get pythonBundled;

  /// No description provided for @save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// No description provided for @settingsModelDownloads.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка моделей'**
  String get settingsModelDownloads;

  /// No description provided for @proxyNote.
  ///
  /// In ru, this message translates to:
  /// **'Необязательный HTTP или SOCKS5 proxy применяется только при скачивании моделей.'**
  String get proxyNote;

  /// No description provided for @proxyLabel.
  ///
  /// In ru, this message translates to:
  /// **'HTTP / SOCKS5 proxy'**
  String get proxyLabel;

  /// No description provided for @proxyHelper.
  ///
  /// In ru, this message translates to:
  /// **'Формат: http://… или socks5://user:password@host:port. Значение хранится локально.'**
  String get proxyHelper;

  /// No description provided for @settingsModelDirectory.
  ///
  /// In ru, this message translates to:
  /// **'Каталог моделей'**
  String get settingsModelDirectory;

  /// No description provided for @modelDirectoryNote.
  ///
  /// In ru, this message translates to:
  /// **'Whisper, Marian и Silero хранятся локально.'**
  String get modelDirectoryNote;

  /// No description provided for @openInExplorer.
  ///
  /// In ru, this message translates to:
  /// **'Открыть в Explorer'**
  String get openInExplorer;

  /// No description provided for @settingsInterfaceLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Язык интерфейса'**
  String get settingsInterfaceLanguage;

  /// No description provided for @interfaceLanguageNote.
  ///
  /// In ru, this message translates to:
  /// **'Меняется сразу, без перезапуска.'**
  String get interfaceLanguageNote;

  /// No description provided for @modelWhisperTitle.
  ///
  /// In ru, this message translates to:
  /// **'Whisper {version}'**
  String modelWhisperTitle(String version);

  /// No description provided for @modelWhisperNote.
  ///
  /// In ru, this message translates to:
  /// **'Распознавание речи и перевод любого языка на английский. Одна модель на все языки озвучки.'**
  String get modelWhisperNote;

  /// No description provided for @modelWhisperTranscribeOnly.
  ///
  /// In ru, this message translates to:
  /// **'Не переводит речь: подойдёт, только если оригинал уже на английском.'**
  String get modelWhisperTranscribeOnly;

  /// No description provided for @recognitionNeedsEnglish.
  ///
  /// In ru, this message translates to:
  /// **'Выбранная модель не переводит речь, а язык оригинала указан не английский.'**
  String get recognitionNeedsEnglish;

  /// No description provided for @modelTranslationNote.
  ///
  /// In ru, this message translates to:
  /// **'Локальный переводчик Helsinki-NLP/Marian, {size}.'**
  String modelTranslationNote(String size);

  /// No description provided for @modelTranslationTitle.
  ///
  /// In ru, this message translates to:
  /// **'Английский → {language}'**
  String modelTranslationTitle(String language);

  /// No description provided for @modelVoiceTitle.
  ///
  /// In ru, this message translates to:
  /// **'{language} — Silero {version}'**
  String modelVoiceTitle(String language, String version);

  /// No description provided for @modelVoiceNote.
  ///
  /// In ru, this message translates to:
  /// **'{language} речь, 24 kHz.'**
  String modelVoiceNote(String language);

  /// No description provided for @modelVoiceNoteRu.
  ///
  /// In ru, this message translates to:
  /// **'Русская речь, 24 kHz; голоса xenia, aidar, baya, kseniya и eugene.'**
  String get modelVoiceNoteRu;

  /// No description provided for @language_ar.
  ///
  /// In ru, this message translates to:
  /// **'Арабский'**
  String get language_ar;

  /// No description provided for @language_cs.
  ///
  /// In ru, this message translates to:
  /// **'Чешский'**
  String get language_cs;

  /// No description provided for @language_de.
  ///
  /// In ru, this message translates to:
  /// **'Немецкий'**
  String get language_de;

  /// No description provided for @language_en.
  ///
  /// In ru, this message translates to:
  /// **'Английский'**
  String get language_en;

  /// No description provided for @language_es.
  ///
  /// In ru, this message translates to:
  /// **'Испанский'**
  String get language_es;

  /// No description provided for @language_fr.
  ///
  /// In ru, this message translates to:
  /// **'Французский'**
  String get language_fr;

  /// No description provided for @language_it.
  ///
  /// In ru, this message translates to:
  /// **'Итальянский'**
  String get language_it;

  /// No description provided for @language_ja.
  ///
  /// In ru, this message translates to:
  /// **'Японский'**
  String get language_ja;

  /// No description provided for @language_ko.
  ///
  /// In ru, this message translates to:
  /// **'Корейский'**
  String get language_ko;

  /// No description provided for @language_nl.
  ///
  /// In ru, this message translates to:
  /// **'Нидерландский'**
  String get language_nl;

  /// No description provided for @language_pl.
  ///
  /// In ru, this message translates to:
  /// **'Польский'**
  String get language_pl;

  /// No description provided for @language_pt.
  ///
  /// In ru, this message translates to:
  /// **'Португальский'**
  String get language_pt;

  /// No description provided for @language_ru.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get language_ru;

  /// No description provided for @language_sv.
  ///
  /// In ru, this message translates to:
  /// **'Шведский'**
  String get language_sv;

  /// No description provided for @language_tr.
  ///
  /// In ru, this message translates to:
  /// **'Турецкий'**
  String get language_tr;

  /// No description provided for @language_uk.
  ///
  /// In ru, this message translates to:
  /// **'Украинский'**
  String get language_uk;

  /// No description provided for @language_zh.
  ///
  /// In ru, this message translates to:
  /// **'Китайский'**
  String get language_zh;

  /// No description provided for @translationTarget_ru.
  ///
  /// In ru, this message translates to:
  /// **'русский'**
  String get translationTarget_ru;

  /// No description provided for @translationTarget_de.
  ///
  /// In ru, this message translates to:
  /// **'немецкий'**
  String get translationTarget_de;

  /// No description provided for @translationTarget_es.
  ///
  /// In ru, this message translates to:
  /// **'испанский'**
  String get translationTarget_es;

  /// No description provided for @translationTarget_fr.
  ///
  /// In ru, this message translates to:
  /// **'французский'**
  String get translationTarget_fr;

  /// No description provided for @translationTarget_uk.
  ///
  /// In ru, this message translates to:
  /// **'украинский'**
  String get translationTarget_uk;

  /// No description provided for @voiceName_ru.
  ///
  /// In ru, this message translates to:
  /// **'Русский голос'**
  String get voiceName_ru;

  /// No description provided for @voiceName_de.
  ///
  /// In ru, this message translates to:
  /// **'Немецкий голос'**
  String get voiceName_de;

  /// No description provided for @voiceName_es.
  ///
  /// In ru, this message translates to:
  /// **'Испанский голос'**
  String get voiceName_es;

  /// No description provided for @voiceName_fr.
  ///
  /// In ru, this message translates to:
  /// **'Французский голос'**
  String get voiceName_fr;

  /// No description provided for @voiceName_uk.
  ///
  /// In ru, this message translates to:
  /// **'Украинский голос'**
  String get voiceName_uk;

  /// No description provided for @voiceSpeech_de.
  ///
  /// In ru, this message translates to:
  /// **'Немецкая'**
  String get voiceSpeech_de;

  /// No description provided for @voiceSpeech_es.
  ///
  /// In ru, this message translates to:
  /// **'Испанская'**
  String get voiceSpeech_es;

  /// No description provided for @voiceSpeech_fr.
  ///
  /// In ru, this message translates to:
  /// **'Французская'**
  String get voiceSpeech_fr;

  /// No description provided for @voiceSpeech_uk.
  ///
  /// In ru, this message translates to:
  /// **'Украинская'**
  String get voiceSpeech_uk;

  /// No description provided for @failureWhisperMissing.
  ///
  /// In ru, this message translates to:
  /// **'Не найден whisper-cli.exe: {detail}. Установите LoreDub через setup или подготовьте runtime командой scripts/prepare_windows_runtime.ps1.'**
  String failureWhisperMissing(String detail);

  /// No description provided for @failureWhisperModelMissing.
  ///
  /// In ru, this message translates to:
  /// **'Не найдена модель Whisper: {detail}. Установите её на вкладке «Модели».'**
  String failureWhisperModelMissing(String detail);

  /// No description provided for @failureWhisperFailed.
  ///
  /// In ru, this message translates to:
  /// **'whisper.cpp: {detail}'**
  String failureWhisperFailed(String detail);

  /// No description provided for @failurePythonMissing.
  ///
  /// In ru, this message translates to:
  /// **'Не найден Python: {detail}. Установите LoreDub через setup или подготовьте runtime командой scripts/prepare_windows_runtime.ps1.'**
  String failurePythonMissing(String detail);

  /// No description provided for @failurePythonStoreAlias.
  ///
  /// In ru, this message translates to:
  /// **'В PATH найден только ярлык Microsoft Store вместо Python. Он не запускает интерпретатор. Выберите встроенный runtime или укажите полный путь к python.exe с установленными torch и transformers.'**
  String get failurePythonStoreAlias;

  /// No description provided for @failurePythonSearchEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Python не найден в PATH и в стандартных каталогах установки. Укажите путь к python.exe вручную или используйте встроенный runtime.'**
  String get failurePythonSearchEmpty;

  /// No description provided for @failurePythonSearchNoDependencies.
  ///
  /// In ru, this message translates to:
  /// **'Не найден Python с torch и transformers. Проверено: {detail}.'**
  String failurePythonSearchNoDependencies(String detail);

  /// No description provided for @failurePythonSearchFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось найти Python: {detail}'**
  String failurePythonSearchFailed(String detail);

  /// No description provided for @pythonCandidateWithoutDependencies.
  ///
  /// In ru, this message translates to:
  /// **'{path} (Python {version}, нет torch/transformers)'**
  String pythonCandidateWithoutDependencies(String path, String version);

  /// No description provided for @pythonCandidateUnusable.
  ///
  /// In ru, this message translates to:
  /// **'{path} (не запускается)'**
  String pythonCandidateUnusable(String path);

  /// No description provided for @failureWorkerExited.
  ///
  /// In ru, this message translates to:
  /// **'Marian/Silero worker завершился с кодом {code}: {detail}'**
  String failureWorkerExited(int code, String detail);

  /// No description provided for @failureWorkerExitedSilently.
  ///
  /// In ru, this message translates to:
  /// **'Marian/Silero worker завершился с кодом {code} без вывода. Проверьте выбранный python.exe: в нём должны быть torch и transformers.'**
  String failureWorkerExitedSilently(int code);

  /// No description provided for @failureWorkerTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Marian/Silero не ответил за 2 минуты. Последний вывод: {detail}'**
  String failureWorkerTimeout(String detail);

  /// No description provided for @failureWorkerTimeoutSilent.
  ///
  /// In ru, this message translates to:
  /// **'Marian/Silero не ответил за 2 минуты. Вывода процесса нет.'**
  String get failureWorkerTimeoutSilent;

  /// No description provided for @failureWorkerNotRunning.
  ///
  /// In ru, this message translates to:
  /// **'Marian/Silero worker не запущен'**
  String get failureWorkerNotRunning;

  /// No description provided for @failureWorkerFailed.
  ///
  /// In ru, this message translates to:
  /// **'Marian/Silero: {detail}'**
  String failureWorkerFailed(String detail);

  /// No description provided for @failurePipelineStopped.
  ///
  /// In ru, this message translates to:
  /// **'Перевод остановлен'**
  String get failurePipelineStopped;

  /// No description provided for @failureWindowsOnly.
  ///
  /// In ru, this message translates to:
  /// **'Локальный pipeline доступен только в Windows'**
  String get failureWindowsOnly;

  /// No description provided for @failureExplorerUnsupported.
  ///
  /// In ru, this message translates to:
  /// **'Открытие каталога поддерживается только в Windows'**
  String get failureExplorerUnsupported;

  /// No description provided for @failureDownloadRejected.
  ///
  /// In ru, this message translates to:
  /// **'Сервер вернул {detail}'**
  String failureDownloadRejected(String detail);

  /// No description provided for @failureVerificationFailed.
  ///
  /// In ru, this message translates to:
  /// **'Проверка {detail} не пройдена'**
  String failureVerificationFailed(String detail);

  /// No description provided for @failureSocksLookupFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось определить адрес SOCKS5 proxy'**
  String get failureSocksLookupFailed;

  /// No description provided for @failureProxyFormat.
  ///
  /// In ru, this message translates to:
  /// **'Укажите proxy в формате http://host:port или socks5://host:port'**
  String get failureProxyFormat;

  /// No description provided for @failureProxyPort.
  ///
  /// In ru, this message translates to:
  /// **'Порт proxy должен быть от 1 до 65535'**
  String get failureProxyPort;

  /// No description provided for @failureInitializationFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось инициализировать приложение: {detail}'**
  String failureInitializationFailed(String detail);

  /// No description provided for @failureCaptureFailed.
  ///
  /// In ru, this message translates to:
  /// **'Захват прервался: {detail}'**
  String failureCaptureFailed(String detail);

  /// No description provided for @settingsComputeDevice.
  ///
  /// In ru, this message translates to:
  /// **'Вычислительное устройство'**
  String get settingsComputeDevice;

  /// No description provided for @computeDeviceNote.
  ///
  /// In ru, this message translates to:
  /// **'«Автоматически» само определяет видеокарту. Каждую модель можно перевести на другое устройство отдельно.'**
  String get computeDeviceNote;

  /// No description provided for @computeDeviceAuto.
  ///
  /// In ru, this message translates to:
  /// **'Автоматически'**
  String get computeDeviceAuto;

  /// No description provided for @computeDeviceGpu.
  ///
  /// In ru, this message translates to:
  /// **'GPU'**
  String get computeDeviceGpu;

  /// No description provided for @computeDeviceCpu.
  ///
  /// In ru, this message translates to:
  /// **'CPU'**
  String get computeDeviceCpu;

  /// No description provided for @computeStageRecognition.
  ///
  /// In ru, this message translates to:
  /// **'Whisper'**
  String get computeStageRecognition;

  /// No description provided for @computeStageTranslation.
  ///
  /// In ru, this message translates to:
  /// **'Перевод'**
  String get computeStageTranslation;

  /// No description provided for @computeStageSpeech.
  ///
  /// In ru, this message translates to:
  /// **'Озвучка'**
  String get computeStageSpeech;

  /// No description provided for @computeBackendCuda.
  ///
  /// In ru, this message translates to:
  /// **'CUDA'**
  String get computeBackendCuda;

  /// No description provided for @computeBackendVulkan.
  ///
  /// In ru, this message translates to:
  /// **'Vulkan'**
  String get computeBackendVulkan;

  /// No description provided for @computeBackendCpu.
  ///
  /// In ru, this message translates to:
  /// **'CPU'**
  String get computeBackendCpu;

  /// No description provided for @computeAdapterDetected.
  ///
  /// In ru, this message translates to:
  /// **'Видеокарта: {name}'**
  String computeAdapterDetected(String name);

  /// No description provided for @computeNoAdapter.
  ///
  /// In ru, this message translates to:
  /// **'Подходящая видеокарта не найдена — всё считается на процессоре'**
  String get computeNoAdapter;

  /// No description provided for @computeBackendUnsupported.
  ///
  /// In ru, this message translates to:
  /// **'Не поддерживается этой моделью'**
  String get computeBackendUnsupported;

  /// No description provided for @computeBackendNoHardware.
  ///
  /// In ru, this message translates to:
  /// **'Нет подходящей видеокарты или драйвера'**
  String get computeBackendNoHardware;

  /// No description provided for @computeRuntimeMissing.
  ///
  /// In ru, this message translates to:
  /// **'Нужен пакет {size}'**
  String computeRuntimeMissing(String size);

  /// No description provided for @computeRuntimeDownload.
  ///
  /// In ru, this message translates to:
  /// **'Скачать'**
  String get computeRuntimeDownload;

  /// No description provided for @computeRuntimeRemove.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get computeRuntimeRemove;

  /// No description provided for @computeRuntimeRemoveTitle.
  ///
  /// In ru, this message translates to:
  /// **'Точно удалить?'**
  String get computeRuntimeRemoveTitle;

  /// No description provided for @computeRuntimeRemoveMessage.
  ///
  /// In ru, this message translates to:
  /// **'Пакет {size} будет удалён с диска, и стадия вернётся на процессор. Скачать его заново можно в любой момент.'**
  String computeRuntimeRemoveMessage(String size);

  /// No description provided for @computeRuntimeRemoveConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить полностью'**
  String get computeRuntimeRemoveConfirm;

  /// No description provided for @computeRuntimeRemoveCancel.
  ///
  /// In ru, this message translates to:
  /// **'Оставить'**
  String get computeRuntimeRemoveCancel;

  /// No description provided for @computeRuntimeInstalling.
  ///
  /// In ru, this message translates to:
  /// **'Установка…'**
  String get computeRuntimeInstalling;

  /// No description provided for @computeSpeechCpuOnly.
  ///
  /// In ru, this message translates to:
  /// **'Silero считается на процессоре: перенос на видеокарту стоит дороже самой работы.'**
  String get computeSpeechCpuOnly;

  /// No description provided for @failureRuntimeIncomplete.
  ///
  /// In ru, this message translates to:
  /// **'В скачанном пакете нет {detail}'**
  String failureRuntimeIncomplete(String detail);

  /// No description provided for @failureRuntimeInstallFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось установить GPU-рантайм: {detail}'**
  String failureRuntimeInstallFailed(String detail);

  /// No description provided for @updateCurrent.
  ///
  /// In ru, this message translates to:
  /// **'Версия {version}'**
  String updateCurrent(String version);

  /// No description provided for @updateChecking.
  ///
  /// In ru, this message translates to:
  /// **'Проверяю обновления…'**
  String get updateChecking;

  /// No description provided for @updateUpToDate.
  ///
  /// In ru, this message translates to:
  /// **'Установлена последняя версия'**
  String get updateUpToDate;

  /// No description provided for @updateCheckAgain.
  ///
  /// In ru, this message translates to:
  /// **'Проверить обновления'**
  String get updateCheckAgain;

  /// No description provided for @updateOpenRelease.
  ///
  /// In ru, this message translates to:
  /// **'Открыть страницу версии {version}'**
  String updateOpenRelease(String version);

  /// No description provided for @updateFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось проверить обновления'**
  String get updateFailed;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вышла новая версия LoreDub'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableBody.
  ///
  /// In ru, this message translates to:
  /// **'Доступна версия {version}. Нажмите стрелку рядом с номером версии, чтобы открыть страницу релиза.'**
  String updateAvailableBody(String version);

  /// No description provided for @failureUpdateCheckFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось проверить обновления: {detail}'**
  String failureUpdateCheckFailed(String detail);

  /// No description provided for @failureUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Неизвестная ошибка'**
  String get failureUnknown;

  /// No description provided for @stagePython.
  ///
  /// In ru, this message translates to:
  /// **'Запуск Python'**
  String get stagePython;

  /// No description provided for @stageTorch.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка PyTorch'**
  String get stageTorch;

  /// No description provided for @stageTransformers.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка Transformers'**
  String get stageTransformers;

  /// No description provided for @stageTranslator.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка переводчика'**
  String get stageTranslator;

  /// No description provided for @stageSpeech.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка синтеза речи'**
  String get stageSpeech;

  /// No description provided for @stageCapture.
  ///
  /// In ru, this message translates to:
  /// **'Запуск захвата'**
  String get stageCapture;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

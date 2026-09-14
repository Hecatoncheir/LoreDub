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

  /// No description provided for @navGroupDubbing.
  ///
  /// In ru, this message translates to:
  /// **'ПЕРЕВОД'**
  String get navGroupDubbing;

  /// No description provided for @navGroupSetup.
  ///
  /// In ru, this message translates to:
  /// **'ПОДГОТОВКА'**
  String get navGroupSetup;

  /// No description provided for @navLive.
  ///
  /// In ru, this message translates to:
  /// **'Эфир'**
  String get navLive;

  /// No description provided for @navSnapshot.
  ///
  /// In ru, this message translates to:
  /// **'Экран'**
  String get navSnapshot;

  /// No description provided for @navCharacters.
  ///
  /// In ru, this message translates to:
  /// **'Персонажи'**
  String get navCharacters;

  /// No description provided for @titleCharacters.
  ///
  /// In ru, this message translates to:
  /// **'Голоса персонажей'**
  String get titleCharacters;

  /// No description provided for @charactersNote.
  ///
  /// In ru, this message translates to:
  /// **'Карточка запоминает голос персонажа: подойдите к нему в игре, нажмите «Записать голос» и дайте ему поговорить. Персонажи общие для всех игр, и в «Эфире» их реплики озвучиваются закреплённым за ними голосом. Голос можно собрать и из готовых записей: перетащите их на карточку.'**
  String get charactersNote;

  /// No description provided for @voicesOnTheGraph.
  ///
  /// In ru, this message translates to:
  /// **'Какой персонаж будет читать реплику за кого, можно задать на экране «Схема».'**
  String get voicesOnTheGraph;

  /// No description provided for @charactersHowTo.
  ///
  /// In ru, this message translates to:
  /// **'Запустите запись, выберите процесс игры — и записывайте голоса по очереди.'**
  String get charactersHowTo;

  /// No description provided for @charactersNeedsConverter.
  ///
  /// In ru, this message translates to:
  /// **'Нужен конвертер голоса: скачайте его в разделе «Голос оригинала» на экране «Модели».'**
  String get charactersNeedsConverter;

  /// No description provided for @charactersSessionStart.
  ///
  /// In ru, this message translates to:
  /// **'Запустить запись'**
  String get charactersSessionStart;

  /// No description provided for @charactersSessionStop.
  ///
  /// In ru, this message translates to:
  /// **'Остановить запись'**
  String get charactersSessionStop;

  /// No description provided for @charactersAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get charactersAdd;

  /// No description provided for @charactersImport.
  ///
  /// In ru, this message translates to:
  /// **'Импорт'**
  String get charactersImport;

  /// No description provided for @charactersExport.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт'**
  String get charactersExport;

  /// No description provided for @charactersExportHint.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить карточку в файл'**
  String get charactersExportHint;

  /// No description provided for @charactersExportAll.
  ///
  /// In ru, this message translates to:
  /// **'Выгрузить всех'**
  String get charactersExportAll;

  /// No description provided for @charactersNewName.
  ///
  /// In ru, this message translates to:
  /// **'Новый персонаж'**
  String get charactersNewName;

  /// No description provided for @charactersNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Имя персонажа'**
  String get charactersNameLabel;

  /// No description provided for @charactersEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Пока ни одного персонажа. Нажмите «Добавить» и запишите голос.'**
  String get charactersEmpty;

  /// No description provided for @charactersRecord.
  ///
  /// In ru, this message translates to:
  /// **'Записать голос'**
  String get charactersRecord;

  /// No description provided for @charactersPlayClip.
  ///
  /// In ru, this message translates to:
  /// **'Прослушать запись'**
  String get charactersPlayClip;

  /// No description provided for @charactersStopSound.
  ///
  /// In ru, this message translates to:
  /// **'Остановить воспроизведение'**
  String get charactersStopSound;

  /// No description provided for @charactersPreviewVoice.
  ///
  /// In ru, this message translates to:
  /// **'Послушать голос озвучки'**
  String get charactersPreviewVoice;

  /// No description provided for @charactersPreviewPlain.
  ///
  /// In ru, this message translates to:
  /// **'Послушать голос озвучки. Тембр персонажа не переносится: включите «Голос оригинала» на экране «Модели», иначе персонажа читает обычный голос синтеза'**
  String get charactersPreviewPlain;

  /// No description provided for @charactersPreviewLoading.
  ///
  /// In ru, this message translates to:
  /// **'Готовлю голос…'**
  String get charactersPreviewLoading;

  /// No description provided for @charactersPreviewNeedsModel.
  ///
  /// In ru, this message translates to:
  /// **'Нужна модель озвучки: загрузите её на экране «Модели»'**
  String get charactersPreviewNeedsModel;

  /// No description provided for @charactersPlayingClip.
  ///
  /// In ru, this message translates to:
  /// **'Звучит…'**
  String get charactersPlayingClip;

  /// No description provided for @charactersNoClip.
  ///
  /// In ru, this message translates to:
  /// **'Записи нет: карточка пришла из файла, в нём только отпечаток голоса'**
  String get charactersNoClip;

  /// No description provided for @charactersRecordStop.
  ///
  /// In ru, this message translates to:
  /// **'Остановить'**
  String get charactersRecordStop;

  /// No description provided for @charactersRecording.
  ///
  /// In ru, this message translates to:
  /// **'Идёт запись — пусть персонаж говорит'**
  String get charactersRecording;

  /// No description provided for @charactersHeard.
  ///
  /// In ru, this message translates to:
  /// **'Записано {seconds} с'**
  String charactersHeard(String seconds);

  /// No description provided for @charactersNoVoice.
  ///
  /// In ru, this message translates to:
  /// **'Голос ещё не записан'**
  String get charactersNoVoice;

  /// No description provided for @charactersBuilding.
  ///
  /// In ru, this message translates to:
  /// **'Считаю голос из файлов…'**
  String get charactersBuilding;

  /// No description provided for @charactersBuiltFrom.
  ///
  /// In ru, this message translates to:
  /// **'Собран из {files} записей · сходство {agreement}'**
  String charactersBuiltFrom(int files, String agreement);

  /// No description provided for @charactersBuiltFromOne.
  ///
  /// In ru, this message translates to:
  /// **'Собран из одной записи'**
  String get charactersBuiltFromOne;

  /// No description provided for @charactersBuiltApart.
  ///
  /// In ru, this message translates to:
  /// **'Записи звучат как разные голоса'**
  String get charactersBuiltApart;

  /// No description provided for @charactersBuiltSkipped.
  ///
  /// In ru, this message translates to:
  /// **'Без голоса: {files}'**
  String charactersBuiltSkipped(int files);

  /// No description provided for @charactersVoiceKept.
  ///
  /// In ru, this message translates to:
  /// **'Голос записан · {seconds} с · {gender}'**
  String charactersVoiceKept(String seconds, String gender);

  /// No description provided for @charactersGenderUnknown.
  ///
  /// In ru, this message translates to:
  /// **'пол не определён'**
  String get charactersGenderUnknown;

  /// No description provided for @charactersDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить персонажа'**
  String get charactersDelete;

  /// No description provided for @charactersVoicedByHint.
  ///
  /// In ru, this message translates to:
  /// **'Озвучивать голосом другого персонажа'**
  String get charactersVoicedByHint;

  /// No description provided for @charactersOwnVoice.
  ///
  /// In ru, this message translates to:
  /// **'Своим голосом'**
  String get charactersOwnVoice;

  /// No description provided for @charactersDeleteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить персонажа?'**
  String get charactersDeleteTitle;

  /// No description provided for @charactersDeleteMessage.
  ///
  /// In ru, this message translates to:
  /// **'Карточка «{name}» и записанный голос будут удалены.'**
  String charactersDeleteMessage(String name);

  /// No description provided for @charactersDeleteConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get charactersDeleteConfirm;

  /// No description provided for @charactersDeleteCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get charactersDeleteCancel;

  /// No description provided for @charactersImported.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{Ни одного персонажа не добавлено} one{Добавлен {count} персонаж} few{Добавлено {count} персонажа} other{Добавлено {count} персонажей}}'**
  String charactersImported(int count);

  /// No description provided for @charactersInPacks.
  ///
  /// In ru, this message translates to:
  /// **'В пакетах: {packs}'**
  String charactersInPacks(String packs);

  /// No description provided for @packsAdd.
  ///
  /// In ru, this message translates to:
  /// **'Создать пакет'**
  String get packsAdd;

  /// No description provided for @packsNewName.
  ///
  /// In ru, this message translates to:
  /// **'Новый пакет'**
  String get packsNewName;

  /// No description provided for @packsNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Название пакета'**
  String get packsNameLabel;

  /// No description provided for @packsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Пакетов пока нет. Создайте пакет и перетащите в него карточки — так набор персонажей можно передать одним файлом.'**
  String get packsEmpty;

  /// No description provided for @packsDropHint.
  ///
  /// In ru, this message translates to:
  /// **'Перетащите сюда карточки персонажей.'**
  String get packsDropHint;

  /// No description provided for @packsExportHint.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить пакет в файл'**
  String get packsExportHint;

  /// No description provided for @packsDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить пакет'**
  String get packsDelete;

  /// No description provided for @packsRemoveMember.
  ///
  /// In ru, this message translates to:
  /// **'Убрать из пакета'**
  String get packsRemoveMember;

  /// No description provided for @packsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{пусто} one{{count} персонаж} few{{count} персонажа} other{{count} персонажей}}'**
  String packsCount(int count);

  /// No description provided for @packsDeleteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить пакет?'**
  String get packsDeleteTitle;

  /// No description provided for @packsDeleteMessage.
  ///
  /// In ru, this message translates to:
  /// **'Пакет «{name}» будет удалён. Персонажи останутся в общем списке.'**
  String packsDeleteMessage(String name);

  /// No description provided for @packsImported.
  ///
  /// In ru, this message translates to:
  /// **'{packs, plural, one{Добавлен {packs} пакет} few{Добавлено {packs} пакета} other{Добавлено {packs} пакетов}} · {characters, plural, one{{characters} персонаж} few{{characters} персонажа} other{{characters} персонажей}}'**
  String packsImported(int packs, int characters);

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

  /// No description provided for @titleSnapshot.
  ///
  /// In ru, this message translates to:
  /// **'Перевод с экрана'**
  String get titleSnapshot;

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

  /// No description provided for @statusSnapshotReady.
  ///
  /// In ru, this message translates to:
  /// **'Ждёт фрагмента'**
  String get statusSnapshotReady;

  /// No description provided for @statusPaused.
  ///
  /// In ru, this message translates to:
  /// **'Пауза'**
  String get statusPaused;

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

  /// No description provided for @routeNeededTitle.
  ///
  /// In ru, this message translates to:
  /// **'Путь не собран'**
  String get routeNeededTitle;

  /// No description provided for @routeNeededAction.
  ///
  /// In ru, this message translates to:
  /// **'К схеме'**
  String get routeNeededAction;

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

  /// No description provided for @startChecklistTitle.
  ///
  /// In ru, this message translates to:
  /// **'Чтобы начать'**
  String get startChecklistTitle;

  /// No description provided for @startStepGame.
  ///
  /// In ru, this message translates to:
  /// **'Выберите игру в списке процессов'**
  String get startStepGame;

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

  /// No description provided for @settingsAudioSource.
  ///
  /// In ru, this message translates to:
  /// **'Источник звука'**
  String get settingsAudioSource;

  /// No description provided for @sourceSystem.
  ///
  /// In ru, this message translates to:
  /// **'Звук системы'**
  String get sourceSystem;

  /// No description provided for @sourceProcess.
  ///
  /// In ru, this message translates to:
  /// **'Звук игры'**
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

  /// No description provided for @stopHint.
  ///
  /// In ru, this message translates to:
  /// **'Остановить перевод полностью'**
  String get stopHint;

  /// No description provided for @pauseDubbing.
  ///
  /// In ru, this message translates to:
  /// **'Пауза'**
  String get pauseDubbing;

  /// No description provided for @pauseHint.
  ///
  /// In ru, this message translates to:
  /// **'Пауза: модели остаются загруженными, игра звучит в полную громкость'**
  String get pauseHint;

  /// No description provided for @resumeDubbing.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get resumeDubbing;

  /// No description provided for @snapshotHowTo.
  ///
  /// In ru, this message translates to:
  /// **'Удерживайте {hotkey}, обведите мышью текст поверх игры и отпустите клавишу — LoreDub прочитает его, переведёт и озвучит.'**
  String snapshotHowTo(String hotkey);

  /// No description provided for @screenHowTo.
  ///
  /// In ru, this message translates to:
  /// **'Пока сеанс идёт, субтитры в рамке читаются и озвучиваются сами — озвучивается только то, что в них прибавилось.'**
  String get screenHowTo;

  /// No description provided for @silenceWhileReading.
  ///
  /// In ru, this message translates to:
  /// **'Заглушить игру полностью'**
  String get silenceWhileReading;

  /// No description provided for @silenceWhileReadingNote.
  ///
  /// In ru, this message translates to:
  /// **'Здесь звук игры ничего не значит — текст берётся с экрана, и игру можно заглушить совсем, чтобы она не произносила реплику одновременно с озвучкой. Выключено — игра приглушается так же, как в «Эфире».'**
  String get silenceWhileReadingNote;

  /// No description provided for @screenPickGame.
  ///
  /// In ru, this message translates to:
  /// **'Выберите игру, чтобы читать её экран'**
  String get screenPickGame;

  /// No description provided for @snapshotNoHotkey.
  ///
  /// In ru, this message translates to:
  /// **'Клавиша выделения не назначена.'**
  String get snapshotNoHotkey;

  /// No description provided for @snapshotOpenSettings.
  ///
  /// In ru, this message translates to:
  /// **'Назначить в настройках'**
  String get snapshotOpenSettings;

  /// No description provided for @snapshotNote.
  ///
  /// In ru, this message translates to:
  /// **'Загружаются только переводчик и голос ({language}), без распознавания речи. Читается окно выбранной игры, пока оно впереди — игра должна идти в оконном или полноэкранном оконном режиме.'**
  String snapshotNote(String language);

  /// No description provided for @screenSourceWindow.
  ///
  /// In ru, this message translates to:
  /// **'Окно игры'**
  String get screenSourceWindow;

  /// No description provided for @screenSourceScreen.
  ///
  /// In ru, this message translates to:
  /// **'Весь экран'**
  String get screenSourceScreen;

  /// No description provided for @screenWholeNote.
  ///
  /// In ru, this message translates to:
  /// **'Загружаются только переводчик и голос ({language}), без распознавания речи. Читается всё, что на экране, какое бы окно ни было впереди — подходит и для игры без обычного окна. Процесс игры нужен здесь только для того, чтобы её приглушить.'**
  String screenWholeNote(String language);

  /// No description provided for @snapshotStart.
  ///
  /// In ru, this message translates to:
  /// **'Запустить'**
  String get snapshotStart;

  /// No description provided for @snapshotStop.
  ///
  /// In ru, this message translates to:
  /// **'Остановить'**
  String get snapshotStop;

  /// No description provided for @snapshotReading.
  ///
  /// In ru, this message translates to:
  /// **'Читаю и перевожу фрагмент…'**
  String get snapshotReading;

  /// No description provided for @snapshotMissed.
  ///
  /// In ru, this message translates to:
  /// **'В выделенной области текст не найден'**
  String get snapshotMissed;

  /// No description provided for @snapshotInLive.
  ///
  /// In ru, this message translates to:
  /// **'Идёт «Эфир» — клавиша выделения работает и в нём'**
  String get snapshotInLive;

  /// No description provided for @snapshotEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Выделенные фрагменты появятся здесь'**
  String get snapshotEmpty;

  /// No description provided for @snapshotClearTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Убрать фрагменты из списка'**
  String get snapshotClearTooltip;

  /// No description provided for @settingsHotkeys.
  ///
  /// In ru, this message translates to:
  /// **'Горячие клавиши'**
  String get settingsHotkeys;

  /// No description provided for @hotkeysNote.
  ///
  /// In ru, this message translates to:
  /// **'Работают, пока идёт «Эфир» или «Фрагмент», даже когда на экране игра; назначенное сочетание тогда до игры не доходит. Клавишу выделения держат нажатой, пока обводят область мышью.'**
  String get hotkeysNote;

  /// No description provided for @hotkeyPause.
  ///
  /// In ru, this message translates to:
  /// **'Пауза'**
  String get hotkeyPause;

  /// No description provided for @hotkeyResume.
  ///
  /// In ru, this message translates to:
  /// **'Восстановление'**
  String get hotkeyResume;

  /// No description provided for @hotkeySnapshot.
  ///
  /// In ru, this message translates to:
  /// **'Выделение области'**
  String get hotkeySnapshot;

  /// No description provided for @hotkeyFrame.
  ///
  /// In ru, this message translates to:
  /// **'Рамка субтитров'**
  String get hotkeyFrame;

  /// No description provided for @frameHowTo.
  ///
  /// In ru, this message translates to:
  /// **'Во время игры рамку можно обвести заново: удерживайте {hotkey}, выделите место с субтитрами и отпустите — выделение исчезнет, а чтение продолжится в новой рамке.'**
  String frameHowTo(String hotkey);

  /// No description provided for @frameMissed.
  ///
  /// In ru, this message translates to:
  /// **'Выделение не попало в окно игры — рамка осталась прежней'**
  String get frameMissed;

  /// No description provided for @hotkeyUnset.
  ///
  /// In ru, this message translates to:
  /// **'Не назначено'**
  String get hotkeyUnset;

  /// No description provided for @hotkeyListening.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите сочетание… (Esc — отмена)'**
  String get hotkeyListening;

  /// No description provided for @hotkeyClear.
  ///
  /// In ru, this message translates to:
  /// **'Убрать сочетание'**
  String get hotkeyClear;

  /// No description provided for @hotkeyNeedsModifier.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте Ctrl, Alt или Win: одиночная клавиша перестала бы доходить до игры'**
  String get hotkeyNeedsModifier;

  /// No description provided for @hotkeyUnsupported.
  ///
  /// In ru, this message translates to:
  /// **'Эту клавишу назначить нельзя'**
  String get hotkeyUnsupported;

  /// No description provided for @hotkeyDuplicate.
  ///
  /// In ru, this message translates to:
  /// **'Это сочетание уже назначено на «{action}»'**
  String hotkeyDuplicate(String action);

  /// No description provided for @failureHotkeyTaken.
  ///
  /// In ru, this message translates to:
  /// **'Сочетание для «{action}» уже занято другой программой — назначьте другое в настройках.'**
  String failureHotkeyTaken(String action);

  /// No description provided for @failureCharactersSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить персонажей: {detail}'**
  String failureCharactersSaveFailed(String detail);

  /// No description provided for @failureCharactersExportFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выгрузить карточку: {detail}'**
  String failureCharactersExportFailed(String detail);

  /// No description provided for @failureCharactersImportFailed.
  ///
  /// In ru, this message translates to:
  /// **'В файле «{detail}» нет персонажей LoreDub.'**
  String failureCharactersImportFailed(String detail);

  /// No description provided for @sceneVoices.
  ///
  /// In ru, this message translates to:
  /// **'Голоса сцены'**
  String get sceneVoices;

  /// No description provided for @sceneVoicesNote.
  ///
  /// In ru, this message translates to:
  /// **'Кого LoreDub услышал в этом сеансе и чьим голосом он звучит.'**
  String get sceneVoicesNote;

  /// No description provided for @sceneVoicesEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Пока никто не заговорил. Нажмите «Определить голоса» — или запустите перевод, и голоса появятся сами.'**
  String get sceneVoicesEmpty;

  /// No description provided for @sceneVoicesListen.
  ///
  /// In ru, this message translates to:
  /// **'Определить голоса'**
  String get sceneVoicesListen;

  /// No description provided for @sceneVoicesListenStop.
  ///
  /// In ru, this message translates to:
  /// **'Остановить'**
  String get sceneVoicesListenStop;

  /// No description provided for @sceneVoicesListening.
  ///
  /// In ru, this message translates to:
  /// **'Слушаю игру. Голоса появляются здесь, как только персонажи заговорят, — перевод при этом не идёт.'**
  String get sceneVoicesListening;

  /// No description provided for @sceneVoiceHeardFor.
  ///
  /// In ru, this message translates to:
  /// **'Услышано {seconds} с'**
  String sceneVoiceHeardFor(String seconds);

  /// No description provided for @sceneVoicesNeedsConverter.
  ///
  /// In ru, this message translates to:
  /// **'Голоса различаются конвертером голоса: скачайте его на экране «Модели» и включите запоминание персонажей.'**
  String get sceneVoicesNeedsConverter;

  /// No description provided for @sceneVoiceUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Голос {number}'**
  String sceneVoiceUnknown(int number);

  /// No description provided for @sceneVoiceAnonymous.
  ///
  /// In ru, this message translates to:
  /// **'Без опознания'**
  String get sceneVoiceAnonymous;

  /// No description provided for @sceneVoiceLines.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} реплика} few{{count} реплики} other{{count} реплик}}'**
  String sceneVoiceLines(int count);

  /// No description provided for @sceneVoiceReadAs.
  ///
  /// In ru, this message translates to:
  /// **'Озвучивать как'**
  String get sceneVoiceReadAs;

  /// No description provided for @sceneVoiceAsHeard.
  ///
  /// In ru, this message translates to:
  /// **'Как услышано'**
  String get sceneVoiceAsHeard;

  /// No description provided for @sceneVoiceNoCharacters.
  ///
  /// In ru, this message translates to:
  /// **'Запишите персонажей на экране «Персонажи», а на «Схеме» решите, кто кого озвучивает.'**
  String get sceneVoiceNoCharacters;

  /// No description provided for @sceneVoiceReplaced.
  ///
  /// In ru, this message translates to:
  /// **'Звучит как «{name}»'**
  String sceneVoiceReplaced(String name);

  /// No description provided for @failureOcrLanguageMissing.
  ///
  /// In ru, this message translates to:
  /// **'В Windows не установлено распознавание текста для языка «{language}». Добавьте язык: Параметры → Время и язык → Язык и регион → Добавить язык.'**
  String failureOcrLanguageMissing(String language);

  /// No description provided for @textLanguageLabel.
  ///
  /// In ru, this message translates to:
  /// **'Язык текста'**
  String get textLanguageLabel;

  /// No description provided for @textLanguageNote.
  ///
  /// In ru, this message translates to:
  /// **'Текст на языке озвучки озвучивается без перевода'**
  String get textLanguageNote;

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

  /// No description provided for @sectionLanguages.
  ///
  /// In ru, this message translates to:
  /// **'ЯЗЫКИ ОЗВУЧКИ'**
  String get sectionLanguages;

  /// No description provided for @sectionLanguagesNote.
  ///
  /// In ru, this message translates to:
  /// **'Переводчик и голос одного языка скачиваются, выбираются и удаляются вместе. Нужен только тот язык, на который вы играете.'**
  String get sectionLanguagesNote;

  /// No description provided for @modelPartTranslation.
  ///
  /// In ru, this message translates to:
  /// **'перевод'**
  String get modelPartTranslation;

  /// No description provided for @modelPartVoice.
  ///
  /// In ru, this message translates to:
  /// **'голос'**
  String get modelPartVoice;

  /// No description provided for @modelPartConverter.
  ///
  /// In ru, this message translates to:
  /// **'конвертер голоса'**
  String get modelPartConverter;

  /// No description provided for @languageHintSelect.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите, чтобы озвучивать на этом языке'**
  String get languageHintSelect;

  /// No description provided for @languageHintSelected.
  ///
  /// In ru, this message translates to:
  /// **'Озвучка идёт на этом языке'**
  String get languageHintSelected;

  /// No description provided for @languageHintLocked.
  ///
  /// In ru, this message translates to:
  /// **'Язык можно сменить, когда озвучка остановлена'**
  String get languageHintLocked;

  /// No description provided for @languageRemoveTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить язык?'**
  String get languageRemoveTitle;

  /// No description provided for @languageRemoveMessage.
  ///
  /// In ru, this message translates to:
  /// **'Переводчик и голос языка «{language}» ({size}) будут удалены с диска. Скачать их заново можно в любой момент.'**
  String languageRemoveMessage(String language, String size);

  /// No description provided for @converterHintInUse.
  ///
  /// In ru, this message translates to:
  /// **'Работает в режиме «Голос оригинала»'**
  String get converterHintInUse;

  /// No description provided for @converterHintIdle.
  ///
  /// In ru, this message translates to:
  /// **'Нужен только для режима «Голос оригинала»'**
  String get converterHintIdle;

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

  /// No description provided for @ocrRegionOfScreen.
  ///
  /// In ru, this message translates to:
  /// **'Рамка {width} × {height}% экрана, отступ {left}% слева и {top}% сверху'**
  String ocrRegionOfScreen(int width, int height, int left, int top);

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

  /// No description provided for @duckWhileSpeaking.
  ///
  /// In ru, this message translates to:
  /// **'Приглушать только под перевод'**
  String get duckWhileSpeaking;

  /// No description provided for @duckWhileSpeakingNote.
  ///
  /// In ru, this message translates to:
  /// **'Игра играет в полную громкость, пока LoreDub молчит, и приглушается на время каждой озвученной реплики. Выключено — игра приглушена весь сеанс. Реплику, которую игра начнёт посреди озвучки, распознавание услышит такой же тихой, как при постоянном приглушении.'**
  String get duckWhileSpeakingNote;

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

  /// No description provided for @hurryWhenQueued.
  ///
  /// In ru, this message translates to:
  /// **'Ускорять озвучку, когда реплики ждут очереди'**
  String get hurryWhenQueued;

  /// No description provided for @hurryWhenQueuedNote.
  ///
  /// In ru, this message translates to:
  /// **'Пока голос свободен, реплика читается с выбранной скоростью. Начиная с третьей ожидающей каждая добавляет десятую долю, но не быстрее чем в полтора раза от выбранной. Если отстаёт распознавание, а не голос, скорость не меняется: там очередь держит не озвучка.'**
  String get hurryWhenQueuedNote;

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
  /// **'«Автоматически» подбирает мужской или женский голос под оригинал, а с запоминанием персонажей закрепляет за каждым свой голос. «Голос оригинала» вдобавок переносит на озвучку тембр самого говорящего.'**
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

  /// No description provided for @voiceOriginal.
  ///
  /// In ru, this message translates to:
  /// **'Голос оригинала'**
  String get voiceOriginal;

  /// No description provided for @voiceOriginalNote.
  ///
  /// In ru, this message translates to:
  /// **'Тембр оригинала накладывается на голос Silero. На процессоре реплика звучит примерно на секунду позже, на видеокарте — без заметной задержки: устройство выбирается в строке OpenVoice раздела «Устройство».'**
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

  /// No description provided for @voiceOverlap.
  ///
  /// In ru, this message translates to:
  /// **'Накладывать реплики разных персонажей'**
  String get voiceOverlap;

  /// No description provided for @voiceOverlapNote.
  ///
  /// In ru, this message translates to:
  /// **'Реплика другого персонажа начинается сразу, не дожидаясь конца текущей; одновременно звучат не больше двух голосов. Без запоминания персонажей они различаются только по полу голоса.'**
  String get voiceOverlapNote;

  /// No description provided for @voiceBank.
  ///
  /// In ru, this message translates to:
  /// **'Запоминать голоса персонажей'**
  String get voiceBank;

  /// No description provided for @voiceBankOnNote.
  ///
  /// In ru, this message translates to:
  /// **'Каждый новый персонаж запоминается по голосу и получает свой голос Silero, а в режиме «Голос оригинала» — ещё и свой тембр. Следующие его реплики звучат так же, в том числе после перезапуска. У каждой игры свой банк голосов.'**
  String get voiceBankOnNote;

  /// No description provided for @voiceBankOffNote.
  ///
  /// In ru, this message translates to:
  /// **'Персонажи не запоминаются: голос подбирается по полу каждой реплики заново, а тембр берётся из неё же и нигде не сохраняется.'**
  String get voiceBankOffNote;

  /// No description provided for @voiceBankCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{Сохранённых голосов нет} one{Сохранён {count} голос} few{Сохранено {count} голоса} other{Сохранено {count} голосов}}'**
  String voiceBankCount(int count);

  /// No description provided for @voiceBankClear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить'**
  String get voiceBankClear;

  /// No description provided for @voiceBankClearTitle.
  ///
  /// In ru, this message translates to:
  /// **'Очистить банк голосов?'**
  String get voiceBankClearTitle;

  /// No description provided for @voiceBankClearMessage.
  ///
  /// In ru, this message translates to:
  /// **'Сохранённые голоса всех игр будут удалены. Персонажи получат тембр заново по своим следующим репликам.'**
  String get voiceBankClearMessage;

  /// No description provided for @voiceBankClearCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get voiceBankClearCancel;

  /// No description provided for @voiceBankClearConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Очистить'**
  String get voiceBankClearConfirm;

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

  /// No description provided for @settingsGroupInterface.
  ///
  /// In ru, this message translates to:
  /// **'ИНТЕРФЕЙС'**
  String get settingsGroupInterface;

  /// No description provided for @settingsGroupDubbing.
  ///
  /// In ru, this message translates to:
  /// **'ОЗВУЧКА'**
  String get settingsGroupDubbing;

  /// No description provided for @settingsGroupCompute.
  ///
  /// In ru, this message translates to:
  /// **'ВЫЧИСЛЕНИЯ'**
  String get settingsGroupCompute;

  /// No description provided for @settingsGroupAdvanced.
  ///
  /// In ru, this message translates to:
  /// **'ДОПОЛНИТЕЛЬНО'**
  String get settingsGroupAdvanced;

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

  /// No description provided for @whisperAxisSize.
  ///
  /// In ru, this message translates to:
  /// **'Размер'**
  String get whisperAxisSize;

  /// No description provided for @whisperAxisQuality.
  ///
  /// In ru, this message translates to:
  /// **'Качество'**
  String get whisperAxisQuality;

  /// No description provided for @whisperQualityFair.
  ///
  /// In ru, this message translates to:
  /// **'нормально'**
  String get whisperQualityFair;

  /// No description provided for @whisperQualityGood.
  ///
  /// In ru, this message translates to:
  /// **'хорошо'**
  String get whisperQualityGood;

  /// No description provided for @whisperQualityExcellent.
  ///
  /// In ru, this message translates to:
  /// **'отлично'**
  String get whisperQualityExcellent;

  /// No description provided for @whisperLegendMissing.
  ///
  /// In ru, this message translates to:
  /// **'не скачана'**
  String get whisperLegendMissing;

  /// No description provided for @whisperLegendInstalled.
  ///
  /// In ru, this message translates to:
  /// **'скачана'**
  String get whisperLegendInstalled;

  /// No description provided for @whisperLegendSelected.
  ///
  /// In ru, this message translates to:
  /// **'выбрана'**
  String get whisperLegendSelected;

  /// No description provided for @whisperLegendDownloading.
  ///
  /// In ru, this message translates to:
  /// **'скачивается'**
  String get whisperLegendDownloading;

  /// No description provided for @whisperNoTranslation.
  ///
  /// In ru, this message translates to:
  /// **'без перевода'**
  String get whisperNoTranslation;

  /// No description provided for @whisperHintDownload.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите, чтобы скачать ({size})'**
  String whisperHintDownload(String size);

  /// No description provided for @whisperHintSelect.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите, чтобы выбрать'**
  String get whisperHintSelect;

  /// No description provided for @whisperHintSelected.
  ///
  /// In ru, this message translates to:
  /// **'Выбрана для распознавания'**
  String get whisperHintSelected;

  /// No description provided for @whisperHintLocked.
  ///
  /// In ru, this message translates to:
  /// **'Модель можно сменить, когда озвучка остановлена'**
  String get whisperHintLocked;

  /// No description provided for @whisperDownloadProgress.
  ///
  /// In ru, this message translates to:
  /// **'{percent}% · {done} из {total}'**
  String whisperDownloadProgress(int percent, String done, String total);

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

  /// No description provided for @failureAudioNotDecoded.
  ///
  /// In ru, this message translates to:
  /// **'Windows не смог прочитать ни один из этих файлов как звук'**
  String get failureAudioNotDecoded;

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

  /// No description provided for @failureDownloadStalled.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка {detail} встала: данные перестали приходить и после нескольких переподключений. Нажмите «Скачать» ещё раз — уже скачанное сохранится.'**
  String failureDownloadStalled(String detail);

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

  /// No description provided for @failureModelRemoveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось удалить модель: {detail}'**
  String failureModelRemoveFailed(String detail);

  /// No description provided for @modelRemove.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get modelRemove;

  /// No description provided for @modelRemoveInUse.
  ///
  /// In ru, this message translates to:
  /// **'Выбранную модель нельзя удалить, пока идёт озвучка'**
  String get modelRemoveInUse;

  /// No description provided for @modelRemoveTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить модель?'**
  String get modelRemoveTitle;

  /// No description provided for @modelRemoveMessage.
  ///
  /// In ru, this message translates to:
  /// **'{name} ({size}) будет удалена с диска. Скачать её заново можно в любой момент.'**
  String modelRemoveMessage(String name, String size);

  /// No description provided for @modelRemoveConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get modelRemoveConfirm;

  /// No description provided for @modelRemoveCancel.
  ///
  /// In ru, this message translates to:
  /// **'Оставить'**
  String get modelRemoveCancel;

  /// No description provided for @failureVoiceBankClearFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось очистить банк голосов: {detail}'**
  String failureVoiceBankClearFailed(String detail);

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

  /// No description provided for @computeStageVoiceConversion.
  ///
  /// In ru, this message translates to:
  /// **'OpenVoice'**
  String get computeStageVoiceConversion;

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

  /// No description provided for @computeRuntimesTitle.
  ///
  /// In ru, this message translates to:
  /// **'ПАКЕТЫ ДЛЯ ВИДЕОКАРТЫ'**
  String get computeRuntimesTitle;

  /// No description provided for @runtimeWhisperCuda.
  ///
  /// In ru, this message translates to:
  /// **'CUDA · Whisper'**
  String get runtimeWhisperCuda;

  /// No description provided for @runtimeTorchCuda.
  ///
  /// In ru, this message translates to:
  /// **'CUDA · перевод'**
  String get runtimeTorchCuda;

  /// No description provided for @runtimeServesWhisper.
  ///
  /// In ru, this message translates to:
  /// **'распознавание'**
  String get runtimeServesWhisper;

  /// No description provided for @runtimeServesTorch.
  ///
  /// In ru, this message translates to:
  /// **'перевод и OpenVoice'**
  String get runtimeServesTorch;

  /// No description provided for @runtimeHintInUse.
  ///
  /// In ru, this message translates to:
  /// **'Сейчас используется'**
  String get runtimeHintInUse;

  /// No description provided for @runtimeHintIdle.
  ///
  /// In ru, this message translates to:
  /// **'Скачан, но сейчас ни одна стадия его не использует'**
  String get runtimeHintIdle;

  /// No description provided for @runtimeRemoveLocked.
  ///
  /// In ru, this message translates to:
  /// **'Пакет можно удалить, когда озвучка остановлена'**
  String get runtimeRemoveLocked;

  /// No description provided for @computeRuntimeDownloading.
  ///
  /// In ru, this message translates to:
  /// **'Пакет {size} скачивается — пауза и отмена на его плитке ниже'**
  String computeRuntimeDownloading(String size);

  /// No description provided for @computeCellHintDownload.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите, чтобы скачать'**
  String get computeCellHintDownload;

  /// No description provided for @computeCellSelect.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите, чтобы считать эту стадию здесь'**
  String get computeCellSelect;

  /// No description provided for @computeCellSelected.
  ///
  /// In ru, this message translates to:
  /// **'Стадия считается здесь'**
  String get computeCellSelected;

  /// No description provided for @computeCellLocked.
  ///
  /// In ru, this message translates to:
  /// **'Устройство можно сменить, когда озвучка остановлена'**
  String get computeCellLocked;

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

  /// No description provided for @updateFromTo.
  ///
  /// In ru, this message translates to:
  /// **'Текущая версия v{current} → v{latest}'**
  String updateFromTo(String current, String latest);

  /// No description provided for @updateInstallHint.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите, чтобы скачать и установить обновление'**
  String get updateInstallHint;

  /// No description provided for @updateDownloading.
  ///
  /// In ru, this message translates to:
  /// **'Скачиваю обновление…'**
  String get updateDownloading;

  /// No description provided for @updateInstalled.
  ///
  /// In ru, this message translates to:
  /// **'Обновлено'**
  String get updateInstalled;

  /// No description provided for @updateRestart.
  ///
  /// In ru, this message translates to:
  /// **'Перезапустить'**
  String get updateRestart;

  /// No description provided for @updateRestartHint.
  ///
  /// In ru, this message translates to:
  /// **'LoreDub закроется, за несколько секунд установит новую версию и откроется снова'**
  String get updateRestartHint;

  /// No description provided for @failureUpdateInstallFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось установить обновление: {detail}'**
  String failureUpdateInstallFailed(String detail);

  /// No description provided for @updateAvailableBody.
  ///
  /// In ru, this message translates to:
  /// **'Доступна версия {version}. Нажмите на строку с версиями внизу слева, чтобы обновиться.'**
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

  /// No description provided for @navPipeline.
  ///
  /// In ru, this message translates to:
  /// **'Схема'**
  String get navPipeline;

  /// No description provided for @titlePipeline.
  ///
  /// In ru, this message translates to:
  /// **'Схема конвейера'**
  String get titlePipeline;

  /// No description provided for @pipelineGraphHint.
  ///
  /// In ru, this message translates to:
  /// **'Тяните от кружка к кружку, чтобы проложить путь. Колесо мыши — масштаб, пустое место — перетащить холст. Shift с нажатием выбирает несколько нод, Ctrl с протяжкой — область; выбранные ноды двигаются вместе.'**
  String get pipelineGraphHint;

  /// No description provided for @failurePipelinesSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить схемы: {detail}'**
  String failurePipelinesSaveFailed(String detail);

  /// No description provided for @failurePipelinesExportFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выгрузить схему: {detail}'**
  String failurePipelinesExportFailed(String detail);

  /// No description provided for @failurePipelinesImportFailed.
  ///
  /// In ru, this message translates to:
  /// **'В файле «{detail}» нет схемы LoreDub.'**
  String failurePipelinesImportFailed(String detail);

  /// No description provided for @pipelineSchemes.
  ///
  /// In ru, this message translates to:
  /// **'Сохранённые схемы'**
  String get pipelineSchemes;

  /// No description provided for @pipelineSaveScheme.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить схему'**
  String get pipelineSaveScheme;

  /// No description provided for @pipelineSchemeName.
  ///
  /// In ru, this message translates to:
  /// **'Название схемы'**
  String get pipelineSchemeName;

  /// No description provided for @pipelineSchemeNew.
  ///
  /// In ru, this message translates to:
  /// **'Новая схема'**
  String get pipelineSchemeNew;

  /// No description provided for @pipelineSchemesEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Сохранённых схем пока нет. «Сохранить схему» запомнит нынешнюю — маршрут, расположение нод и расстановку персонажей, — чтобы к ней можно было вернуться.'**
  String get pipelineSchemesEmpty;

  /// No description provided for @pipelineSchemeApply.
  ///
  /// In ru, this message translates to:
  /// **'Загрузить схему'**
  String get pipelineSchemeApply;

  /// No description provided for @pipelineSchemeExport.
  ///
  /// In ru, this message translates to:
  /// **'Выгрузить схему в файл'**
  String get pipelineSchemeExport;

  /// No description provided for @pipelineSchemeImport.
  ///
  /// In ru, this message translates to:
  /// **'Загрузить схему из файла'**
  String get pipelineSchemeImport;

  /// No description provided for @pipelineSchemeDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить схему'**
  String get pipelineSchemeDelete;

  /// No description provided for @pipelineSchemeRename.
  ///
  /// In ru, this message translates to:
  /// **'Переименовать'**
  String get pipelineSchemeRename;

  /// No description provided for @pipelineSchemeCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get pipelineSchemeCancel;

  /// No description provided for @pipelineSchemeAudio.
  ///
  /// In ru, this message translates to:
  /// **'Маршрут собран'**
  String get pipelineSchemeAudio;

  /// No description provided for @pipelineSchemeUnrouted.
  ///
  /// In ru, this message translates to:
  /// **'Без входа'**
  String get pipelineSchemeUnrouted;

  /// No description provided for @pipelineSchemeCast.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} персонаж} few{{count} персонажа} other{{count} персонажей}}'**
  String pipelineSchemeCast(int count);

  /// No description provided for @pipelineResetLayout.
  ///
  /// In ru, this message translates to:
  /// **'Разложить заново'**
  String get pipelineResetLayout;

  /// No description provided for @pipelineUndo.
  ///
  /// In ru, this message translates to:
  /// **'Отменить'**
  String get pipelineUndo;

  /// No description provided for @pipelineRedo.
  ///
  /// In ru, this message translates to:
  /// **'Вернуть'**
  String get pipelineRedo;

  /// No description provided for @pipelineAddCharacter.
  ///
  /// In ru, this message translates to:
  /// **'Добавить персонажа на схему'**
  String get pipelineAddCharacter;

  /// No description provided for @pipelineNoCharacters.
  ///
  /// In ru, this message translates to:
  /// **'Персонажей пока нет — запишите их на экране «Персонажи»'**
  String get pipelineNoCharacters;

  /// No description provided for @pipelineSelected.
  ///
  /// In ru, this message translates to:
  /// **'Выбрано'**
  String get pipelineSelected;

  /// No description provided for @pipelineCloseInspector.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть панель'**
  String get pipelineCloseInspector;

  /// No description provided for @pipelineRemoveNode.
  ///
  /// In ru, this message translates to:
  /// **'Убрать со схемы'**
  String get pipelineRemoveNode;

  /// No description provided for @pipelineCutLink.
  ///
  /// In ru, this message translates to:
  /// **'Вернуть свой голос'**
  String get pipelineCutLink;

  /// No description provided for @pipelineCutRoute.
  ///
  /// In ru, this message translates to:
  /// **'Отсоединить оригинальный поток'**
  String get pipelineCutRoute;

  /// No description provided for @pipelineCutCast.
  ///
  /// In ru, this message translates to:
  /// **'Убрать персонажей из сведения'**
  String get pipelineCutCast;

  /// No description provided for @pipelineCutHeard.
  ///
  /// In ru, this message translates to:
  /// **'Не слышать этого персонажа в игре'**
  String get pipelineCutHeard;

  /// No description provided for @pipelineNodeSource.
  ///
  /// In ru, this message translates to:
  /// **'Оригинальный поток'**
  String get pipelineNodeSource;

  /// No description provided for @pipelineNodeRecognition.
  ///
  /// In ru, this message translates to:
  /// **'Whisper'**
  String get pipelineNodeRecognition;

  /// No description provided for @pipelineNodeTranslation.
  ///
  /// In ru, this message translates to:
  /// **'Перевод'**
  String get pipelineNodeTranslation;

  /// No description provided for @pipelineNodeVoice.
  ///
  /// In ru, this message translates to:
  /// **'Голос'**
  String get pipelineNodeVoice;

  /// No description provided for @pipelineNodeOutput.
  ///
  /// In ru, this message translates to:
  /// **'Поток'**
  String get pipelineNodeOutput;

  /// No description provided for @pipelineSocketGameAudio.
  ///
  /// In ru, this message translates to:
  /// **'Звук'**
  String get pipelineSocketGameAudio;

  /// No description provided for @pipelineSocketScreenText.
  ///
  /// In ru, this message translates to:
  /// **'Текст с экрана'**
  String get pipelineSocketScreenText;

  /// No description provided for @pipelineSocketSpeech.
  ///
  /// In ru, this message translates to:
  /// **'Речь'**
  String get pipelineSocketSpeech;

  /// No description provided for @pipelineSocketText.
  ///
  /// In ru, this message translates to:
  /// **'Текст'**
  String get pipelineSocketText;

  /// No description provided for @pipelineSocketAudio.
  ///
  /// In ru, this message translates to:
  /// **'Аудио'**
  String get pipelineSocketAudio;

  /// No description provided for @pipelineSocketCast.
  ///
  /// In ru, this message translates to:
  /// **'Персонажи'**
  String get pipelineSocketCast;

  /// No description provided for @pipelineSocketCharacter.
  ///
  /// In ru, this message translates to:
  /// **'Персонаж'**
  String get pipelineSocketCharacter;

  /// No description provided for @pipelineSocketVoice.
  ///
  /// In ru, this message translates to:
  /// **'Голос'**
  String get pipelineSocketVoice;

  /// No description provided for @pipelineUnrouted.
  ///
  /// In ru, this message translates to:
  /// **'не подключено'**
  String get pipelineUnrouted;

  /// No description provided for @pipelineNoProcess.
  ///
  /// In ru, this message translates to:
  /// **'Игра не выбрана'**
  String get pipelineNoProcess;

  /// No description provided for @pipelineNoModel.
  ///
  /// In ru, this message translates to:
  /// **'Модель не выбрана'**
  String get pipelineNoModel;

  /// No description provided for @pipelineOutputDefault.
  ///
  /// In ru, this message translates to:
  /// **'Устройство по умолчанию'**
  String get pipelineOutputDefault;

  /// No description provided for @pipelineMixOverlapping.
  ///
  /// In ru, this message translates to:
  /// **'внахлёст'**
  String get pipelineMixOverlapping;

  /// No description provided for @pipelineMixInTurn.
  ///
  /// In ru, this message translates to:
  /// **'по очереди'**
  String get pipelineMixInTurn;

  /// No description provided for @pipelineReadBy.
  ///
  /// In ru, this message translates to:
  /// **'Голосом «{name}»'**
  String pipelineReadBy(String name);

  /// No description provided for @pipelineChained.
  ///
  /// In ru, this message translates to:
  /// **'Этот голос сам отдан другому: замена идёт на один шаг и дальше не передаётся.'**
  String get pipelineChained;

  /// No description provided for @pipelineCharacterNeedsOriginal.
  ///
  /// In ru, this message translates to:
  /// **'нужен голос оригинала'**
  String get pipelineCharacterNeedsOriginal;

  /// No description provided for @pipelineLockedNote.
  ///
  /// In ru, this message translates to:
  /// **'Сессия запущена: маршрут и модели закреплены до остановки.'**
  String get pipelineLockedNote;

  /// No description provided for @pipelineModelLabel.
  ///
  /// In ru, this message translates to:
  /// **'Модель распознавания'**
  String get pipelineModelLabel;

  /// No description provided for @pipelineRefusalSignal.
  ///
  /// In ru, this message translates to:
  /// **'Сюда идёт другой сигнал.'**
  String get pipelineRefusalSignal;

  /// No description provided for @pipelineRefusalDirection.
  ///
  /// In ru, this message translates to:
  /// **'Связь идёт от выхода ко входу.'**
  String get pipelineRefusalDirection;

  /// No description provided for @pipelineRefusalSameNode.
  ///
  /// In ru, this message translates to:
  /// **'Нода не соединяется сама с собой.'**
  String get pipelineRefusalSameNode;

  /// No description provided for @pipelineRefusalUnsupported.
  ///
  /// In ru, this message translates to:
  /// **'Такого маршрута у движка нет.'**
  String get pipelineRefusalUnsupported;

  /// No description provided for @pipelineRefusalLoop.
  ///
  /// In ru, this message translates to:
  /// **'Тогда персонажи озвучивали бы друг друга.'**
  String get pipelineRefusalLoop;

  /// No description provided for @pipelineRefusalLocked.
  ///
  /// In ru, this message translates to:
  /// **'Пока идёт сессия, маршрут менять нельзя.'**
  String get pipelineRefusalLocked;

  /// No description provided for @failurePipelineLayoutSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить схему: {detail}'**
  String failurePipelineLayoutSaveFailed(String detail);

  /// No description provided for @pipelineNodeMix.
  ///
  /// In ru, this message translates to:
  /// **'Сведение'**
  String get pipelineNodeMix;

  /// No description provided for @pipelineMixVoices.
  ///
  /// In ru, this message translates to:
  /// **'До {count} голосов сразу'**
  String pipelineMixVoices(int count);

  /// No description provided for @pipelineMixOneVoice.
  ///
  /// In ru, this message translates to:
  /// **'Один голос за раз'**
  String get pipelineMixOneVoice;

  /// No description provided for @pipelineMixNote.
  ///
  /// In ru, this message translates to:
  /// **'Через сведение проходит всё, что озвучено, — и общий голос, и реплики персонажей. Одновременно звучит не больше {count} голосов, а один персонаж никогда не перебивает сам себя.'**
  String pipelineMixNote(int count);

  /// No description provided for @pipelineOutputOriginal.
  ///
  /// In ru, this message translates to:
  /// **'оригинал {percent}%'**
  String pipelineOutputOriginal(int percent);

  /// No description provided for @pipelineOutputNote.
  ///
  /// In ru, this message translates to:
  /// **'Озвучка уходит на устройство вывода Windows по умолчанию.'**
  String get pipelineOutputNote;
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

# TODO — инженерный план LoreDub

Составлен 2026-09-18 по аудиту версии 0.22.0 (коммит `c55211a`). Продуктовые
планы (Piper, оверлей субтитров, сборка с Vulkan) живут в `README.md`, раздел
«Планы»; здесь только качество кода и архитектура.

Обозначения: **P0** — первым, блокирует остальное · **P1** — основная работа ·
**P2** — после P1 · **P3** — когда дойдут руки.

---

## 1. Оценка

### Что сделано хорошо

- **Чистый домен.** `lib/src/domain` без Flutter, решения — чистые функции с
  тестами (`buildPipelineGraph`, `resolveComputeBackend`, `freshOcrText`,
  `hurriedSpeed`). Пороги измерены и записаны рядом с кодом, а не подобраны.
- **Узкая граница с нативным кодом.** Крошечный C ABI, всё через UTF-8 JSON,
  Native Assets вместо ручной `.dll`.
- **Область перерисовки — под тестом.** `rebuild_scope_test.dart` считает
  перестроения, `graph_bench.dart` меряет кадр холста. Редкая дисциплина.
- **Ошибки кодами, слова — на границе интерфейса.** `LoreDubFailure(FailureCode)`
  → `describeFailure`. Локализация полная: захардкоженных строк в виджетах
  нет (проверено поиском).
- **Bloc графа сделан правильно:** sealed-события, undo/redo через memento,
  граф — чистая функция настроек и состава.
- **Загрузчик:** докачка, SHA-256, обнаружение зависания, пауза/отмена как
  исход, а не исключение.
- **Строгий анализатор** (`strict-casts/inference/raw-types`, `--fatal-infos`),
  релизный конвейер сверяет тег, версию и changelog.
- **Material-темы компонентов** (кнопки, поля, состояния переключателя)
  настроены централизованно и тщательно — база темы правильная.
- **Скриншоты документации рисуются из настоящих виджетов** как golden-файлы.
- **Чистая база:** на момент аудита `flutter analyze --fatal-infos` — без
  замечаний, формат — без расхождений, 629 тестов зелёные, покрытие 79,6 %.

### Что мешает

1. **`dashboard_view.dart` — файл-бог:** 5429 строк, 62 приватных виджета,
   суммарная когнитивная сложность 533.
2. **79 % виджетов приватные** (90 из 114) плюс 7 приватных `CustomPainter` и
   65 методов, возвращающих `Widget`. У `CharacterTile` 19 параметров
   конструктора.
3. **Нет `BlocProvider`.** Мешок `DashboardCubits` протянут параметром через
   ~200 мест; пять приватных `_XBuilder` с функцией `watch` заново изобретают
   `BlocSelector`. Любой виджет видит всё состояние приложения, и по его
   конструктору не понять, от чего он зависит.
4. **Решения принимаются в `build`.** `_CharacterCast.build` — сложность 76:
   доступность каждой кнопки плитки вычисляется вложенными тернарниками
   прямо в дереве виджетов, в цикле.
5. **Связность слоя состояния:** блоки получают друг друга в конструкторах
   (`PipelineCubit(settings, downloads)`, `PipelineGraphBloc(settings,
   characters, pipeline)`), поздние колбэки (`releaseWorker`, `beforeRestart`,
   `interfaceLanguage`), состояния без сравнения по значению, события движка —
   `Map<String, Object?>` со строковым `type`, скрытые изменяемые поля вне
   состояния (`_heard`, `_recordingSince`…), тестовые лазейки `seed()` в
   боевых классах, `ShellCubit` импортирует `flutter/widgets` и l10n,
   `PipelineCubit.close()` уничтожает `AppRepository`, которым пользуются ещё
   четыре кубита.
6. **Тема обходится стороной.** Виджеты привязаны к статической палитре
   (264 обращения к `LoreDubPalette.` в 12 файлах), 111 `TextStyle(...)` по
   месту, ~250 радиусов/отступов/кеглей цифрами, `ThemeExtension` — ноль,
   тёмной темы нет. `buildLoreDubPanelTheme` повторяет `buildLoreDubTheme`
   на 170 строк и **строится заново на каждый `build` инспектора** — то есть
   на каждый кадр перетаскивания при открытой панели. `theme.dart`
   импортирует `dashboard/node_paint.dart` — общий слой знает про фичу.
7. **Запись настроек:** `SettingsService.save` делает около 40 вызовов `setX`, а
   `shared_preferences_windows` на каждый синхронно переписывает весь файл
   (`writeAsStringSync`). Слайдеры зовут `update()` на каждый тик — это
   тысячи синхронных записей на UI-изоляте за одно перетаскивание.
8. **`AppRepository` — фасад на ~50 методов:** настройки, сессии движка,
   процессы, банк голосов, состав, словарь, схемы, раскладка графа, поиск
   Python, проба видеокарт.

### Базовые цифры (измерено скриптом аудита, методика SonarSource)

| Метрика | Значение |
| --- | --- |
| Файлов / функций в `lib/` (без генерации) | 86 / 1395 |
| Когнитивная сложность > 10 / > 15 / > 25 | 59 / 27 / 10 |
| Максимум | 76 — `_CharacterCast.build` |
| Функций длиннее 50 / 80 / 150 строк | 79 / 33 / 5 |
| Приватных виджетов / всего виджетов | 90 / 114 |
| Методов, возвращающих `Widget` | 65 |
| `LoreDubPalette.` в виджетах | 264 |
| `BlocProvider` / `context.read` / `BlocSelector` | 0 |

Самые сложные функции:

| CC | Строк | Где |
| ---: | ---: | --- |
| 76 | 108 | `dashboard_view.dart` `_CharacterCast.build` |
| 36 | 110 | `compute_matrix.dart` `BackendCell.build` |
| 35 | 172 | `dashboard_view.dart` `_ComputeDeviceCard._build` |
| 33 | 82 | `domain/ocr_text_delta.dart` `freshOcrText` |
| 33 | 132 | `domain/pipeline_graph.dart` `buildPipelineGraph` |
| 30 | 160 | `local_inference_service.dart` `LocalInferenceService.start` |
| 30 | 78 | `model_visuals.dart` `modelActions` |
| 29 | 123 | `dashboard_view.dart` `_VoiceCard._build` |
| 26 | 86 | `whisper_model_chart.dart` `_ModelBarState._content` |
| 26 | 102 | `model_tiles.dart` `ModelTile.build` |
| 25 | 58 | `pipeline_canvas.dart` `_DotFieldPainter.paint` |
| 24 | 120 | `dashboard_view.dart` `_ModelsPanel._build` |

---

## 1а. Найденные дефекты — чинить сразу (P0)

Закрыто в `main` после аудита (2026-09-18/19):

- [x] **Поиск в «Словаре» сужал только фразы** — `b25ea13`, `feefb3a`
      (имена и слова сужаются тоже; пустой список говорит, что он сужен, а
      не пуст).
- [x] **Остановка во время запуска вешала `start()` на пять минут и затем
      гасила чужую сессию** — `4bfdf5a`, `52743d1`, `e84483c`, `5fbdbdf`,
      `25e6440`: completer завершается при `stop()`, у запусков есть номер
      сессии (`_sessions`), сверяемый после каждого ожидания
      (`_throwIfSuperseded`), неудавшийся запуск гасит только свою сессию,
      файлы для карточки не уходят в воркер, который забрал «Эфир».
- [x] **Умерший воркер не заканчивал сессию** — `4bfdf5a` (`onWorkerLost`).
- [x] **Релиз выходил и с упавшими тестами** — `e728528` (`Invoke-Native`
      в обоих скриптах сборки).

Осталось:

- [x] **Занятая клавиша рамки выдаётся за клавишу паузы.** Натив шлёт
      `hotkeyTaken` с `action: "frame"` (`lore_dub_native.cpp:522`), а
      `failure_messages.dart:57–61` знает только `resume` и `snapshot` и
      остальное называет паузой. Правка: `enum HotkeyAction` в домене,
      исчерпывающий `switch`.
- [x] **Проба `dubbed_in_latin` идёт через словарь игрока.**
      `inference_worker.py:1124` зовёт `translate("Open the door.")`, а тот
      сначала спрашивает `glossary.said` и память. Фраза «Open the door.»,
      записанная в словарь как «не озвучивать», вернёт `""` — и немецкая
      сессия решит, что язык не латинский, и начнёт транслитерировать каждую
      реплику в кириллицу; чтение с латиницей в русской сессии, наоборот,
      выключит транслитерацию на всю сессию. Правка: пробовать
      `translated_sentences(["Open the door."])` напрямую.
- [x] Старые `*.exe.part` в `<app support>/updates/` не удаляются никогда
      (`update_installer.dart:93–104` метёт только `.exe`).

---

## 2. Правила, которые план вводит

Это определение «готово» для любой задачи ниже и для нового кода.

1. **Когнитивная сложность функции ≤ 15 — потолок, цель ≤ 10.** `build` не
   длиннее 60 строк, файл не длиннее ~400 (кроме каталогов данных).
2. **Один публичный виджет — один файл.** Приватных виджетов нет.
   `State<T>` остаётся приватным в файле своего виджета: это не виджет, а его
   реализация, так устроен сам Flutter, и линт
   `library_private_types_in_public_api` ждёт именно этого. `CustomPainter` —
   публичный, в своём файле (его можно проверять golden-тестом отдельно).
3. **Методов, возвращающих `Widget`, нет** — вместо них виджеты (const,
   своя область перестроения, своё место в инспекторе).
4. **В `build` нет решений.** Условие сложнее одного операнда — геттер
   состояния или view-model; дерево виджетов только отображает.
5. **Bloc по умолчанию.** Cubit — только для тривиального синхронного
   состояния без подписок и без `async` (навигация, баннер).
6. **Блоки не знают друг о друге.** Общее — через репозитории со стримами.
7. **Блоки не импортируют Flutter.**
8. **Виджеты не импортируют палитру.** Цвет и стиль — только через
   `Theme.of(context)` / `context.colors`.
9. **Состояния и события сравнимы по значению.**

---

## 3. Этап 0 — страховка и измерение (P0)

Прежде чем двигать код, сделать так, чтобы регресс был виден сразу.

- [x] **Когнитивная сложность в CI.** Штатный анализатор её не считает.
      Первым попробовать пакет `cognitive_complexity` 0.2.4 (kevmoo, методика
      SonarSource, понимает switch-выражения, guard'ы и `if`/`for` в
      коллекциях, Dart ≥ 3.12): у него есть храповик по git-diff
      (`diff-base`, `fail-threshold`) и аннотации для GitHub Actions — то
      есть «новый код не сложнее 15, старый не растёт» из коробки. При аудите
      он не запускался; если не подойдёт — запасной путь: скрипт аудита
      (~300 строк на `package:analyzer`, цифры раздела 1 получены им) кладётся
      в `tool/complexity.dart` с базой `tool/complexity_baseline.json`,
      которую можно только уменьшать.
- [x] **Правила 2 и 3 — линтером, а не глазами.** `dart_code_linter` 4.3.0
      (живой форк dart_code_metrics; на этом SDK отработал, проверено при
      аудите) содержит `prefer-single-widget-per-file` — приватные виджеты
      он считает по умолчанию, опция `ignore-private-widgets` выключена — и
      `avoid-returning-widgets`. Там же `avoid-nested-conditional-expressions`
      (правило 4), `number-of-parameters`, `maximum-nesting-level`,
      `cyclomatic-complexity`. Сначала — CLI-шагом
      (`dart run dart_code_linter:metrics analyze lib`) со счётчиком-храповиком:
      плагином анализатора он сразу дал бы сотни замечаний, а CI идёт с
      `--fatal-infos`. Плагином — когда счётчик дойдёт до нуля.
- [x] Храповик на `LoreDubPalette.` / `Color(0x` / `TextStyle(` вне
      `lib/src/ui/theme/` — десять строк в `tool/`, готового правила нет.
- [x] Эти проверки и `dart format --set-exit-if-changed` — в
      `.github/workflows/windows.yml` (сейчас формат проверяет только GitLab).
- [x] `flutter test test/screenshots.dart` **без** `--update-goldens` —
      отдельным шагом CI: перенос виджетов не должен сдвинуть ни пикселя.
      Это главная страховка этапа 2.
- [ ] Линты — см. этап 7.

---

## 4. Этап 1 — провайдеры вместо `DashboardCubits` (P0)

Делается до разбора файла: иначе каждый вынесенный виджет унесёт с собой
параметр `cubits`, и все 114 файлов придётся трогать второй раз.

- [x] `DashboardView` оборачивает поддерево в `MultiBlocProvider` из
      `BlocProvider.value(...)` по уже созданным кубитам. Тесты, которые
      строят `DashboardView(cubits: ...)`, не меняются.
- [x] Экран за экраном: `cubits.x` → `context.read<X>()`;
      `_PipelineBuilder(watch: ...)` → `BlocSelector<PipelineCubit,
      LivePipelineState, T>`; `_DownloadsBuilder(onlyWhatIsInstalled: true)` →
      `BlocSelector` по `installedModelIds`. `rebuild_scope_test.dart` должен
      оставаться зелёным после каждого экрана.
      *Сделано так:* `BlocSelector` там, где виджет рисует только выбранное;
      где тело ещё читает состояние целиком (`_build(context, pipeline…)`) —
      `BlocBuilder` с `buildWhen: whenChanged(...)`. Такие места переходят на
      `BlocSelector` при разборе на виджеты (этап 2), когда у каждого
      виджета останется своё узкое поле.
- [x] Удалить `_ShellBuilder`, `_PipelineBuilder`, `_SettingsBuilder`,
      `_DownloadsBuilder`, `_CharactersBuilder` и параметр `cubits` у всех
      виджетов.
- [x] Состояниям — сравнение по значению (`equatable` либо вручную; кодогенерации
      в проекте нет, и ради этого заводить `freezed` не стоит). После этого
      `watch`, склеивающий строку
      (`'${installedModelIds.join()}|${installedRuntimes.join()}'`), заменяется
      записью из двух множеств. *Сделано:* все семь состояний — `Equatable`
      (`equatable` 3); вместо склеенной строки — `InstalledPackages` со
      сравнением множеств.
- [x] Репозитории — через `MultiRepositoryProvider` в `app.dart`, с
      `dispose:`; `PipelineCubit.close()` перестаёт трогать `AppRepository`.
      *Сделано так:* репозитории создаёт и отдаёт через
      `RepositoryProvider.value` состояние `LoreDubBootstrap`, оно же гасит
      `AppRepository` после того, как закрылись все кубиты (`dispose:` у
      провайдера сработал бы раньше них).
- [ ] Пирамида из четырёх билдеров в `_PipelinePanel.build` (собирает
      `PipelineFacts` из четырёх источников) → одно производное состояние:
      `PipelineFacts` считает блок графа (или отдельный `PipelineFactsBloc`
      поверх стримов репозиториев), экран его только читает. Ограничения по
      кадру из `CLAUDE.md` сохраняются: граф слушается innermost, у тулбара
      свой `buildWhen`.
      *Отложено до этапа 4:* без `Stream<AppSettings>` и прочих стримов у
      репозиториев производное состояние пришлось бы собирать подписками
      блоков друг на друга — ровно то, что запрещает правило 6. Делается
      вместе с развязкой блоков.

---

## 5. Этап 2 — разбор `dashboard_view.dart`, ни одного приватного виджета (P1)

### Целевая раскладка (feature-first)

```
lib/src/ui/
  app/            LoreDubApp, InterfaceScale (бывший _Scaled)
  theme/          см. этап 3
  common/         ModuleLabel, AreaHeading, SettingCard, SectionNote,
                  ErrorBanner, StatusChip, ClearListButton, LanguageRow,
                  EmptyState, ConfirmDialog, PackArea<T>
  shell/          DashboardView, SideNavigation, NavigationGroup,
                  NavigationItem, BottomNavigation, DashboardHeader,
                  VersionButton, UpdateRow            + bloc/
  live/           LivePanel, SourceControls, StartButton, SessionButtons,
                  LanguageControls, TargetLanguagePicker, StartChecklist,
                  StartStepRow, ModelsNeededNotice, TranscriptCard,
                  TranscriptBubble, BubbleTailPainter, LatencyBadge,
                  CorrectLineButton, CorrectLineDialog, EmptyTranscript,
                  SceneVoicesCard                     + bloc/
  screen_text/    SnapshotPanel, ScreenCaptureCard, SubtitleFrameCard,
                  SubtitleList, SnapshotControls, SnapshotStartButton,
                  SnapshotHistory, EmptySnapshots, TextLanguagePicker,
                  OcrRegionPicker
  characters/     CharactersPanel, CharacterSessionControls, CharacterCast,
                  CharacterPacks, EmptyCast, CharacterTile…  + bloc/
  glossary/       GlossaryPanel…                      + bloc/
  graph/          PipelinePanel, InspectorSlot, GraphToolbar,
                  canvas/, inspector/, shelf/         + bloc/
  models/         ModelsPanel, DownloadControls, ModelCard, WhisperModelChart,
                  ModelTile, LanguagePairTile…        + bloc/
  settings/       SettingsPanel, InterfaceSettingsGroup, ScaleCard,
                  HotkeysCard, HotkeyRow, DubbingSettingsGroup, VoiceCard,
                  VoiceBankControls, ComputeDeviceCard, BackendCell,
                  RuntimeTile, ProxyCard, PythonCard, PythonActions,
                  ModelDirectoryCard                  + bloc/
```

### Порядок

Каждый шаг — отдельный коммит «перенос без изменения поведения»; после
каждого: `flutter analyze`, `flutter test`, goldens без обновления.

- [x] **Атомы в `common/`:** `_ModuleLabel`, `_AreaHeading`, `_SettingCard`,
      `_SectionNote`, `_ErrorBanner`, `_StatusChip`, `_ClearListButton`,
      `_LanguageRow`. От них зависят все экраны.
- [x] **`shell/`:** `_Navigation`, `_NavigationGroup`, `_NavigationItem`,
      `_BottomNavigation`, `_Header`, `_VersionButton`, `_UpdateRow`;
      `_sectionMark` → расширение над `DashboardSection` в `shell/`.
- [x] **`live/`**, затем **`screen_text/`**, **`characters/`**, **`models/`**.
- [x] **`settings/`:** `_SettingsPanelState` (650 строк, ~20 методов
      `Widget _x(...)`) распадается на `InterfaceSettingsGroup`, `ScaleCard`,
      `HotkeysCard`, `DubbingSettingsGroup`, `ProxyCard`, `PythonCard`,
      `ModelDirectoryCard`. Контроллеры и ключи форм уезжают в карточки,
      которым принадлежат; `_hotkeyProblem` → `domain/hotkey.dart`;
      `_threadOptions` → домен.
- [x] **`graph/`:** `_PipelinePanel`, `_InspectorSlot`, `_GraphToolbar`.
      `dashboard_view.dart` переехал в `shell/` и держит только
      `DashboardView` с провайдерами; каркас экрана — `DashboardScaffold`.
- [x] Контрольные точки вёрстки (`900`, `860`, `880`, `1000`, `920 + 320`…),
      разбросанные приватными константами, → `theme/tokens/breakpoints.dart`.
      *Сделано иначе:* не одним файлом в `theme/`, а классом на экран рядом
      с его виджетами (`ShellLayout`, `LiveLayout`, `ScreenLayout`,
      `CharactersLayout`, `SettingsLayout`) — каждая точка задокументирована
      тем, что ломалось без неё, и это описание живёт рядом с тем, что оно
      описывает. От темы они не зависят. Файлы `dashboard/`, которые ещё не
      разобраны (словарь, холст, график), держат свои пока при себе.
- [x] `app.dart`: `_Scaled` → `app/interface_scale.dart`.

### Снижение сложности по ходу переноса

Храповик `cognitive_complexity` сопоставляет функции по файлу и имени, так
что перенесённая функция для него — новая. Функцию сложнее 15 поэтому нельзя
перенести как есть: её упрощают в том же коммите, где она переезжает.

- [x] `_CharacterCast.build` (CC 76): правила доступности действий
      (`onPlay`, `onPreview`, `onRecord`, `onFilesDropped`) → методы
      `CharactersState` (`canPlayClip(id)`, `canPreview(id)`,
      `recordAction(id)`), которые собирают `CharacterTileModel`. Плитка
      делится на контейнер и отображение: `CharacterTileContainer` берёт
      модель одной карточки через `BlocSelector` и шлёт события, а
      `CharacterTile` остаётся чистым листом — `CharacterTileModel` плюс
      связка колбэков `CharacterTileActions` вместо 19 параметров. Заодно
      тик записи перестраивает одну плитку, а не весь состав.
      *Сделано частично:* правила — `canPlayClip`, `canPreview`,
      `recordActionFor` (`RecordAction`), `takesFiles` в `CharactersState`
      с тестами; карточку собирает `CastCard`, сетку — `CastDropArea`.
      Плитка берёт `CharacterTileModel` и `CharacterTileActions` вместо 19
      параметров, тексты — `CharacterTileTexts` с тестами. Подписка одной
      плитки через `BlocSelector` — впереди.
- [x] `_ComputeDeviceCard._build` (35), `_cell` (17), `BackendCell.build`
      (36): состояние ячейки — sealed `BackendCellState` (`ready` /
      `needsRuntime(install)` / `downloading(progress)` / `noHardware` /
      `notBuiltIn`), вычисляется в `DownloadsState`; виджет — `switch` по
      нему, по виджету на вариант.
      *Сделано для таблицы настроек:* sealed `StageBackendStatus` +
      `stageBackendStatus()` с тестами, ячейку рисует `StageBackendCell`.
      `BackendCell.build` (36) разобран на `BackendCellLook` (вид из
      состояния) и `BackendCellLabel`; файл уехал в `settings/`.
- [x] `_VoiceCard._build` (29), `_ModelsPanel._build` (24),
      `_ModelCard.build` (21), `modelActions` (30), `ModelTile.build` (26),
      `_ModelBarState._content` (26): тот же приём — sealed-состояние
      «что сейчас с пакетом» (`missing` / `downloading` / `paused` /
      `installed` / `inUse` / `failed`) один раз в домене вместо пяти
      разных `if`-лесенок в пяти виджетах.
      *Сделано:* `PackageTransfer` в домене (что качается, стоит, отсутствует;
      что возобновлять и что отменять) с тестами — на нём `modelActions`
      распался на две простые функции; `ModelTile` — на `ModelTileLook`,
      `ModelTileBody`, `ModelTileHeading`. Столбик Whisper (`_ModelBar`) —
      впереди, вместе с `whisper_model_chart.dart`.
- [x] Диалог подтверждения удаления написан четырежды
      (`model_visuals.dart:261`, `dashboard_view.dart:3484`, `:3661`, `:4983`),
      а удаление пака словаря (`glossary_screen.dart:751`) не спрашивает
      вовсе → один `ConfirmDialog` в `common/`, и спрашивать везде.
- [x] `CharacterPackArea` (`character_tiles.dart:536–686`) и
      `_GlossaryPackArea` (`glossary_screen.dart:769–965`) — один и тот же
      виджет; отличаются переключателем активности и подсказкой поиска →
      `PackArea<D>` + `PackChip<D>` + `DragFeedbackChip`, полки → `PackShelf`.
      *Сделано:* `common/pack_area.dart` (`PackArea<D>`: имя, счёт, кнопки
      в строке имени или ряд `controls` под ней, `active`), `PackChip<D>`,
      `PackHint`; `CharacterPackArea` и `GlossaryPackArea` — тонкие обёртки.
      Полки не объединены: у состава `Card` с `AreaHeading`, у словаря —
      колонка со своим заголовком и радиусом 16; это решение дизайна, а не
      рефакторинг.

### Остальные файлы интерфейса

В них ещё 34 приватных виджета и painter'а и ~31 метод, возвращающий
`Widget`. Кроме того, `character_tiles.dart` (5), `model_tiles.dart` (4) и
`model_visuals.dart` (4) держат по нескольку **публичных** виджетов в файле —
по правилу 2 они тоже делятся.

- [x] **`pipeline_canvas.dart` (1687 строк)** → каталог `graph/canvas/`:

      | Файл | Что в нём |
      | --- | --- |
      | `node_metrics.dart` | `NodeMetrics` + новый `boundsOfAll` |
      | `pipeline_facts.dart` | `PipelineFacts` с дешёвым `==` на `identical` |
      | `graph_hit_tester.dart` | чистые `portNear` / `portOn` / `accepts` / `caughtBy` / `fitted` |
      | `canvas_gesture_controller.dart` | `ChangeNotifier`: `_over`, `_dragging`, рамка выбора; клавиши-модификаторы внедряются |
      | `scheme_motion.dart` | контроллер появления + чистый `SchemeDiff.between(was, now)` |
      | `node_layer_cache.dart` | публичные `NodeInputs`, `NodeLayerCache`, `BadgeCache` |
      | `connection_messages.dart` | `describeConnectionRefusal`, `describeLinkCut` |
      | виджеты | `node_card.dart`, `node_card_header.dart`, `node_card_summary.dart`, `port_row.dart`, `port_dot.dart`, `link_cut_badge.dart`, `selection_band.dart`, `appearing.dart`, `hovering.dart` |
      | painter'ы | `link_painter.dart` + `link_geometry.dart`; `dot_field_painter.dart` + чистый `dot_field.dart` |

      Что нельзя сломать (кадр измерен, см. `CLAUDE.md`): кеш обязан отдавать
      **те же экземпляры** виджетов (`pipeline_canvas_test.dart:167–204`
      проверяет идентичность); `repaint:` на анимации и `RepaintBoundary` на
      карточку остаются; контроллер жестов уведомляет только там, где сегодня
      стоит `setState`, — кадры перетаскивания идут только через блок.
      Сделать `NodeLayer` принимающим ровно `NodeInputs`: правило «всё, из
      чего рисуется карточка, лежит в `_NodeInputs`» из соглашения превратится
      в ошибку компиляции. После каждого шага — `flutter test
      test/graph_bench.dart`.
      *Сделано:* файл ужался до ~600 строк состояния холста; вынесены
      `NodeMetrics` (+`boundsOfAll`, общий с полкой схем), `PipelineFacts`,
      чистые `GraphHitTester` (с `fitted`), `SchemeDiff`, `LinkCut`,
      `LinkGeometry`, `DotField`, painter'ы `LinkPainter` /
      `DotFieldPainter` ниже порога 15, `NodeLabels`, `NodeInputs` и
      виджеты карточки. Кадр в `graph_bench.dart` не вырос (≈25 мс
      перетаскивание, ≈21 мс панорама), goldens совпали. Контроллер жестов
      отдельным `ChangeNotifier` и `NodeLayer`, принимающий ровно
      `NodeInputs`, — ещё не сделаны.
- [x] `_NodeCard` (297 строк): ~100 строк вывода текста (`:1552–1647`) →
      чистая `NodeLabels.of(l10n, node, facts, availability)`; `switch` в
      `_rows` → const-таблица.
- [x] `_cutButtons` (`:782–855`, шесть булевых и `switch` по пятёрке)
      заново выводит то, что уже отвечает `proposeDisconnect`
      (`pipeline_graph.dart:994–1030`) → `switch` по его sealed-результату в
      `describeLinkCut`, виджет — `LinkCutBadge`.
- [x] Дубли геометрии: `_onCanvas` (`:313`) ≡ `_toCanvas` (`:338`);
      `_caughtBy` повторяет `NodeMetrics.boundsOf`; `_fitted` повторяет
      `_SchemePainter._bounds` (`pipeline_shelf.dart:453`).
- [x] **`PipelineInspector`** — один виджет на 449 строк с девятью
      методами-строителями → `NodeInspectorPanel`, `NodeInspectorHeader`, по
      виджету `<Kind>NodeFields` на вид узла, `StageDevicePicker`. Чтения
      `cubits.pipeline.state` (`:180`) и `cubits.downloads.state` (`:456`)
      в `build` без подписки — сейчас спасает то, что перестраивается
      родитель; после этапа 1 это `BlocSelector`.
- [x] **`glossary_screen.dart`:** `build` на 159 строк → `GlossaryToolbar`,
      `GlossaryPresetChips`, `GlossaryLists` по `GlossaryKind.values`
      (это же закрывает дефект из 1а: три секции перестают быть копипастой).
      `_matches` / `_listed` / `_of` → чистая `GlossaryView.of(glossary,
      filter)` с `Set` ключей, лежащих в паках: сейчас на каждое нажатие
      клавиши идёт `List.contains` на запись на пак.
      *Сделано:* каталог `ui/glossary/`, чистые `GlossaryFilter` /
      `GlossaryView` в `domain/glossary_view.dart` с тестами; область пака
      без состояния, из `GlossaryPackControls` и `GlossaryPackMembers`.
      Значок номера — общий `ModuleNumber` (им же рисуют `ModuleLabel` и
      полка схем).
- [x] Поле имени «сохранить при потере фокуса» написано четырежды
      (`character_tiles.dart:182–207`, `:563–583`,
      `glossary_screen.dart:807–827`, `pipeline_inspector.dart:496–527`) →
      `CommittedTextField`; три хозяина из четырёх станут `StatelessWidget`.
- [ ] `_ModelBar` (`whisper_model_chart.dart:276`) заново реализует
      `ModelTile`; `CharacterTileGrid` ≡ `ModelTileGrid`; помощник наведения
      существует в трёх видах (`HoverGrow`, `_Hovering`, по месту в
      `whisper_model_chart.dart:389`); подсказка «прогресс или пояснение»
      собирается в четырёх местах → по одному общему виджету.
- [x] `WhisperModelChart._chart`: 35 строк арифметики вёрстки → чистый
      `WhisperChartLayout`; `_content` собирает детей через `children.add` и
      строит шкалу дважды (`:422`, `:436`).
- [x] Диалоги выбора файла живут в состоянии виджетов, и ведут себя
      по-разному: импорт состава показывает SnackBar
      (`dashboard_view.dart:3640`), импорт словаря — ничего → один шов
      `FileDialogs`, результат импорта — событие блока.
      *Сделано:* `common/file_dialogs.dart` (`openJson`, `saveJson`),
      отдаётся `RepositoryProvider` из `LoreDubBootstrap`; все пять экранов
      берут его с контекста, тест подставляет свой. Импорт словаря
      возвращает, сколько прочитал, и говорит это SnackBar'ом, как состав.
      Событием блока результат станет вместе с этапом 4.
- [ ] Мелочи: `CharacterTile.soundFiles/soundAmong` → `domain/`;
      `_SchemeCard` пересобирает граф на каждый `build`, а у `PipelineGraph`
      нет `==`, так что миниатюра перерисовывается всегда
      (`pipeline_shelf.dart:227`, `:520`); карточка паков словаря рисует
      радиус 16 против документированных 12 (`glossary_screen.dart:686`).
      *Миниатюра схемы — сделано:* `SchemePainter` берёт схему и состав и
      строит граф только при рисовании; полка разобрана в `graph/shelf/`.
      *Звуковые файлы — сделано:* `domain/sound_files.dart`.

### Доступность (P2)

- [x] `PopupMenuButton(tooltip: '')` (`character_tiles.dart:467`,
      `pipeline_shelf.dart:331`) оставляет кнопки-иконки без имени.
      *Сделано:* `charactersCardMenu`, `pipelineSchemeMenu`.
- [ ] Холст — только для указателя: карточки (`pipeline_canvas.dart:1387`) и
      гнёзда (`:758`) — голые `GestureDetector` без фокуса и `Semantics`.
- [ ] В пак можно положить только перетаскиванием → пункт меню
      «Добавить в пак…» у карточки и у записи словаря.
- [x] Цели 26–34 px (`pipeline_canvas.dart:823`, `:1460`,
      `glossary_screen.dart:1024`, `model_visuals.dart:125`) против 44–48 px,
      обещанных в `docs/UI_DESIGN.md`. Как минимум — токен, а не цифра.
      *Сделано — токен:* `LoreDubTargets` (`comfortable`, `dense`, `compact`,
      `cross`) в `theme.dart`, отступление записано в `UI_DESIGN.md`. Сами
      цели не выросли: это меняет плотность плиток и остаётся за дизайном.
- [x] `MediaQuery.disableAnimationsOf` не читается в
      `glossary_screen.dart:842`, `character_tiles.dart:595` и у заливок на
      300 мс. *Сделано:* `common/ease.dart` — `ease(context, ms)` для всех
      неявных анимаций (бывший `canvasEase`), с тестом.
- [x] Литералы в обход l10n: `'…%'` (`pipeline_inspector.dart:373`) вместо
      `l10n.originalVolumeValue`; `Colors.white` (`model_visuals.dart:283`).
      *Проверено:* подпись поля уже идёт через `originalVolumeValue`, а
      `'$percent%'` осталось только в бегунке ползунка, как и на экране
      настроек; `Colors.white` в плитках моделей больше нет. Остальные
      `Colors.white` уйдут вместе с токенами темы (этап 3).

---

## 6. Этап 3 — тема (P1)

### Ответы на вопросы

**Хорошо ли сделана тема?** Наполовину. Material-часть (`ThemeData`, темы
кнопок, полей, переключателей) — хорошо. Собственные виджеты тему обходят:
берут цвета из статического `LoreDubPalette`, стили пишут по месту. Проект
уже упёрся в это сам: панель узла пришлось красить отдельной второй темой на
170 строк, и в `CLAUDE.md` записано правило «всё в панели читает цвета из
темы» — потому что статическая палитра не перекрашивается.

**Отдельно от виджетов или рядом?** И так, и так — по слоям:

- *Токены и сборка `ThemeData`* — отдельно, в `lib/src/ui/theme/`. Они
  сквозные, это единственное место, где виден весь облик; парный документ —
  `docs/UI_DESIGN.md`.
- *Тема компонента* (только у сложных собственных виджетов) — рядом с
  виджетом: меняется вместе с ним. Значения по умолчанию она выводит из
  семантических токенов, поэтому общий слой о ней не знает.

**Класс темы на каждый виджет с реализациями Light/Dark?** Нет. Тема — это
значения, а не поведение, полиморфизм ей не нужен. Схема «абстрактный класс +
`LightX`/`DarkX`» даёт N виджетов × M тем классов, не умеет `lerp` (нет
плавной смены темы), не умеет `copyWith` (нет локального переопределения) и
дублирует цвета вместо того, чтобы выводить их из общих ролей. У самого
Flutter на компонент один неизменяемый класс данных (`CardThemeData`), а
светлая и тёмная — это два **экземпляра**, и умолчания считаются из
`ColorScheme`. `NodePaint` в проекте уже сделан именно так — класс данных и
четыре экземпляра; ему не хватает только доставки через `Theme`.

**Как лучше всего во Flutter.** Три слоя токенов:

1. **Примитивы** — сырая палитра. Приватна для слоя темы, виджетам
   недоступна физически.
2. **Семантические роли** — `ThemeExtension`: `LoreDubColors` (canvas, panel,
   raised, ink, mutedInk, outline, accent, onAccent, accentStrong, signal,
   onSignal, success, warning, danger), `LoreDubTextStyles` (moduleNumber,
   moduleLabel, cardTitle, note, badge, latency…). Светлая и тёмная — два
   экземпляра. Отступы, радиусы и контрольные точки от темы не зависят — им
   достаточно `const`-классов (`Insets`, `Radii`, `Breakpoints`), в
   `ThemeExtension` их тащить незачем.
3. **Темы компонентов** — `ThemeExtension` только там, где у виджета много
   красящихся частей, не ложащихся на роли 1:1: грани узла (`NodeFaces`:
   plain / ends / heard / cast), пузырь транскрипта, столбик модели.
   Остальные виджеты читают роли напрямую.

Material-виджеты по-прежнему стилизуются штатными темами компонентов в
`ThemeData` — это уже сделано.

```dart
// lib/src/ui/theme/tokens/lore_dub_colors.dart
@immutable
class LoreDubColors extends ThemeExtension<LoreDubColors> {
  const LoreDubColors({required this.canvas, required this.panel, /* … */});

  static const light = LoreDubColors(canvas: _Palette.canvas, /* … */);
  static const dark = LoreDubColors(canvas: _Palette.graphite, /* … */);

  final Color canvas;
  final Color panel;
  // …

  @override
  LoreDubColors copyWith({Color? canvas, Color? panel /* … */}) => /* … */;

  @override
  LoreDubColors lerp(LoreDubColors? other, double t) => other == null
      ? this
      : LoreDubColors(canvas: Color.lerp(canvas, other.canvas, t)!, /* … */);
}

// lib/src/ui/theme/theme_context.dart
extension LoreDubThemeContext on BuildContext {
  LoreDubColors get colors => Theme.of(this).extension<LoreDubColors>()!;
  LoreDubTextStyles get textStyles => Theme.of(this).extension<LoreDubTextStyles>()!;
}

// lib/src/ui/theme/app_theme.dart
abstract final class AppTheme {
  static final light = build(LoreDubColors.light, Brightness.light);
  static final dark = build(LoreDubColors.dark, Brightness.dark);

  /// Одна сборка и для окна, и для панели узла: различаются только токены.
  static ThemeData build(LoreDubColors c, Brightness brightness) => ThemeData(
    brightness: brightness,
    colorScheme: ColorScheme(brightness: brightness, primary: c.accent, /* … */),
    extensions: [c, LoreDubTextStyles.from(c)],
    filledButtonTheme: /* читает только c.* */,
    // …
  );
}
```

Виджет после этого: `color: context.colors.mutedInk`,
`style: context.textStyles.moduleLabel`.

### Задачи

- [ ] `theme/tokens/`: `_Palette` (приватная), `LoreDubColors`,
      `LoreDubTextStyles`, `Insets`, `Radii`, `Breakpoints`.
- [ ] `AppTheme.build(LoreDubColors, Brightness)` — **одна** функция вместо
      пары `buildLoreDubTheme` / `buildLoreDubPanelTheme`. Панель узла:
      `AppTheme.build(face.asColors(), …)`, результат мемоизируется по грани
      (их четыре) — сейчас две `ThemeData` строятся на каждый кадр.
      Замерить в `graph_bench.dart` с открытым инспектором до и после.
- [ ] `NodePaint` → `NodeFaces` (`ThemeExtension`, рядом с холстом в
      `graph/`); `theme/` перестаёт импортировать `dashboard/`.
- [ ] Перевести виджеты с `LoreDubPalette.x` на `context.colors.x` — по
      экранам, в том же порядке, что этап 2 (264 места). `CustomPainter`
      получает готовые значения через конструктор и сравнивает их в
      `shouldRepaint`.
- [ ] 111 `TextStyle(...)` по месту → роли. Цвет в роль не зашивать там, где
      текст стоит на разных гранях (панель узла) — его даёт
      `DefaultTextStyle`. В базовой `TextTheme` сейчас нет `bodySmall`,
      `labelSmall` и `titleSmall` — отсюда и стили по месту; завести их
      первыми.
- [ ] Повторяющиеся рецепты → роли и общие виджеты:
  - значок номера модуля (28×22, оранжевый, радиус 4, моно 10 w700) — слово
    в слово в `dashboard_view.dart:2414`, `glossary_screen.dart:603`,
    `pipeline_shelf.dart:170` → один `ModuleLabel`;
  - приглушённая заметка 12–13 `mutedInk` — ~25 мест → `bodySmall`;
  - моно-подпись 11 и моно-маркировка прописными (`character_tiles.dart:368`,
    `pipeline_canvas.dart:1475`, `pipeline_inspector.dart:123`…) → роли
    `monoCaption`, `monoMarking`;
  - кромка плитки (`marked ? orange : hovered ? ink : outline`, 2/1, радиус
    12) — `model_tiles.dart:113`, `whisper_model_chart.dart:316`,
    `character_tiles.dart:275`, `compute_matrix.dart:99` → `TileEdge`;
  - заливка загрузки — `model_tiles.dart:131`, `whisper_model_chart.dart:336`,
    `compute_matrix.dart:113` → `DownloadFill`;
  - компактная кнопка-иконка 26/30/34 — пять мест → `CompactIconButton`;
  - сырые цвета с альфой (`0x22171717` дважды, `0xAAF7F5F0` четырежды) →
    токены `shadow`, `inkOnDarkMuted`.
- [ ] Ловушка при переезде на тему: значки разреза связи на холсте
      запоминают цвета в момент создания и лежат в кеше
      (`pipeline_canvas.dart:840–841`). Когда цвета пойдут из темы,
      `LinkCutBadge` должен брать их в собственном `build`, иначе смена темы
      системы оставит старые значки. Комментарий на `:246–249` обещает, что
      `didChangeDependencies` сбрасывает кеши, — проверить тестом.
- [ ] `MaterialApp(theme: AppTheme.light, darkTheme: AppTheme.dark,
      themeMode: …)`, `AppSettings.themeMode` (system / light / dark),
      переключатель в «Настройках». `test/screenshots.dart` рисует обе темы.
- [ ] Обновить `docs/UI_DESIGN.md`: таблица токенов = поля `LoreDubColors`.

---

## 7. Этап 4 — Bloc (P1–P2)

### Где Bloc, где Cubit

| Сейчас | Станет | Почему |
| --- | --- | --- |
| `PipelineCubit` (748 строк, состояние из 15 полей с шестью флагами `clearX`) | `SessionBloc` + `TranscriptBloc` + `GameProcessBloc` | По природе событийный: `_handleEvent` со `switch` по строке — это вручную написанная таблица `on<Event>`. Намерения игрока спорят с событиями движка; нужен журнал переходов (`BlocObserver`) и `emit.forEach` вместо ручной подписки с проверками `isClosed`. Три `toggle*` — один и тот же скелет трижды. |
| `CharactersCubit` (769 строк, скрытые поля `_heard*`, `_recordingSince`, таймер) | `CastBloc` (карточки, паки, импорт/экспорт, `voicedBy`, `asHeard`) + `VoiceCaptureBloc` (сессия записи, дубль, сборка из файлов, предпрослушивание) | Две ответственности. Пять взаимоисключающих `xxxId` → sealed `CaptureActivity` (`idle` / `recording(id, since)` / `building(id)` / `playing(id)` / `previewing(id)`): невозможные состояния перестают быть представимыми. |
| `DownloadsCubit` | `DownloadsBloc` | Долгие отменяемые процессы, несколько сразу. `installModel` / `installRuntime` — дубли; адресация по индексу, снятому до `await`, хрупкая → по id. |
| `SettingsCubit` | `SettingsBloc` | Запись на диск — через `debounce`-трансформер и строго последовательно, состояние — сразу. Лечит п. 7 оценки. |
| `ShellCubit` | `NavigationCubit` + `FailureCubit` + `UpdateBloc` | Раздел и баннер — тривиальное синхронное состояние, здесь Cubit уместен: Bloc добавил бы по классу события на сеттер и ничего не дал. Проверка → загрузка → перезапуск — процесс с прогрессом, это Bloc. Текст тоста уходит из блока в слой представления (`BlocListener`), вместе с импортом `flutter/widgets`. |
| `GlossaryCubit` (167 строк) | `GlossaryBloc` | Самый чистый из кубитов; переводить последним, ради единообразия и журнала. |
| `PipelineGraphBloc` | остаётся | Уже Bloc. Убрать зависимость от трёх кубитов (см. ниже). |

Оговорка про двойной щелчок: `droppable()` не заменяет `_pressedTwice`
один к одному — кнопка запуска она же отменяет запуск, идущий минуты, и
отбрасывать все нажатия на это время нельзя. Правило «стоп в первые 800 мс
после старта — хвост двойного щелчка» остаётся, но переезжает из полей
кубита в трансформер события остановки.

### Задачи

- [ ] **Типизированные события движка.** `NativeEngineService` один раз, на
      границе, превращает JSON в sealed `EngineEvent` (`SessionStateChanged`,
      `LineDubbed`, `SceneVoiceHeard`, `SnapshotRead`, `SubtitleFrameMoved`,
      `StartupProgressed`, `LanguageDetected`, `BackendSettled`,
      `HotkeyPressed`, `CharacterVoiceMeasured`, `EngineFailed`…). Блоки
      сопоставляют типы, а не строки; `event['x'] as String? ?? ''` исчезает.
- [ ] **Развязать блоки.** `SettingsRepository` отдаёт `Stream<AppSettings>`
      и текущее значение; то же для установленных моделей и состава. Правило
      «один движок — одна сессия» (сейчас это колбэк `releaseWorker`,
      связанный в `DashboardCubits`) становится доменным сервисом
      `SessionCoordinator`. `DashboardCubits` после этого удаляется;
      первичная загрузка — `BlocProvider(lazy: false, create: … ..add(const
      XStarted()))`.
- [ ] Разрезать `AppRepository` по контекстам: `SettingsRepository`,
      `SessionRepository`, `CastRepository`, `GlossaryRepository`,
      `SchemeRepository`, `VoiceBankRepository`, `SystemRepository`
      (процессы, видеокарты, поиск Python).
- [ ] `bloc_test` + `mocktail` в `dev_dependencies`; `seed()` и
      `PipelineGraphSeeded` удаляются — виджет-тесты получают
      `MockBloc` + `whenListen` через `BlocProvider.value`.
- [ ] `bloc_concurrency`: `sequential()` для событий движка, `droppable()`
      для запросов запуска, `restartable()` + debounce для записи настроек.
- [ ] `BlocObserver`, пишущий `event → state` в отладочный журнал: у конвейера
      тринадцать видов событий, и разбирать жалобу игрока по такому журналу
      на порядок проще.
- [ ] Инъекция часов везде, где есть `DateTime.now()` (`CharactersCubit`,
      `GlossaryCubit._newId`, `PipelineGraphBloc._onSchemeSaved`) — в
      `PipelineCubit` это уже сделано.
- [ ] `AGENTS.md` / `CLAUDE.md`: «service → repository → Cubit» → «… → Bloc».

---

## 8. Этап 5 — слой данных и домен (P1–P2)

- [ ] **`NativeEngineService` (1134 строки) — класс-бог с шестью
      скопированными жизненными циклами.** Шесть `start*` (`:120–182`,
      `:191–241`, `:247–271`, `:276–298`, `:376–409`, `:417–452`) повторяют
      одно и то же: распаковку конфига, создание каталога захвата (3 копии),
      блок `ld_start` / `catch` → `_inference.stop()` / `malloc.free`
      (4 копии), таймер опроса (6 копий). Одиннадцать изменяемых полей
      сбрасываются вручную и непоследовательно. Разложить:
  - `NativeBridge` (интерфейс + FFI-реализация): все `ld_*`, malloc/free,
    `_throwIfError`, `readNativeUtf8String`. Это же шов для тестов: сейчас
    на 1970 строк двух сервисов — 218 строк тестов, и те по свободным функциям.
  - `EngineSession`: объект на один запуск — вид сессии, типизированный
    конфиг и все поля выше. `identical(session, _current)` — тот самый
    токен, что чинит зависание из 1а и не даёт фразе старой сессии
    приземлиться в новую.
  - `PhraseProcessor` (`:745–968`), `VoiceTakeRecorder` (`:307–353`,
    `:465–502`, `:754–777`), `GameDucker` (`:981–991` + политика из
    `app_repository.dart:291–294`, `:468–492` — сейчас приглушение размазано
    по двум слоям).
  - В сервисе остаётся один шаблон `_startSession(config, {capture})`, опрос
    и маршрутизация. `_pollEvents()` (`:643`) без `try/catch` зовётся из
    `stop()` до очистки → остаток `stop()` в `finally`.
- [ ] **`LocalInferenceService`: протокол запроса написан девять раз**
      (`:500–531`, `:539–563`, `:567–598`, `:603–628`, `:635–660`,
      `:673–694`, `:696–722`, `:729–755`, `:761–811`, по ~20 одинаковых
      строк) → `WorkerChannel.request(body, {timeout})`. Отдельно
      `WorkerProcess` (запуск, рукопожатие, выход, остановка), `WhisperRunner`
      (`:426–496`) и чистый `WorkerArguments.toCommandLine()`: у `start()`
      25 именованных параметров, пять из них булевы, сложность 30. Регресс с
      вложенным `--glossary`, описанный в комментарии на `:312–316`, — ровно
      то, что ловит тест чистой функции аргументов.
- [ ] **Строковые карты вместо типов.** `AppRepository` собирает конфиги
      руками (`:168–210`, `:243–270`, `:309–318`, `:343–352`, `:369–375`,
      `:412–424`), сервис распаковывает их приведениями
      (`config['cpuThreads']! as int`). → `sealed class SessionConfig`
      (`LiveSession`, `ScreenSession`, `SceneSession`, `CharactersSession`,
      `PreviewSession`, `VoiceFilesSession`) с `toNativeJson()`;
      16 параметров `AppRepository.start` → один `SessionPlan`, который домен
      строит из `ModelSelection`. Вместе с `EngineEvent` из этапа 4.
- [ ] **Четыре JSON-хранилища — один класс, написанный четырежды**
      (`glossary_service`, `character_service`, `pipeline_library_service`,
      `pipeline_graph_service`: одинаковые `file/load/save/exportTo/readFiles`
      и пять одинаковых `*RootProvider`) → `JsonFileStore<T>({fileName,
      decode, encode, empty, saveFailure})` + `exportJson` /
      `importJsonFiles<T>`; ~455 строк → ~220. В нём же один раз починить:
  - записи не сериализованы — имя временного файла фиксировано
    (`'$destination.tmp'`), а `PipelineGraphBloc._persist` пускает
    сохранения без ожидания, так что переименования могут наложиться;
  - ловить и `TypeError`: приведения `as` в `fromJson`
    (`pipeline_graph.dart:541`, `:547`; `character.dart:22–31`;
    `glossary.dart:168–174`; `saved_pipeline.dart:62–76`) ломают обещанное
    «повреждённый файл читается как пустой».
- [ ] **`AppSettings`: 35 полей, каждое записано в шести местах**
      (конструктор, поле, параметр и тело `copyWith`, `load`, `save`);
      умолчания продублированы литералами в `settings_service.dart:78–110`;
      `==` нет; `showOverlay` сохраняется и никем не читается. Разбить на
      `DuckingSettings`, `VoiceSettings`, `RecognitionSettings`,
      `ScreenSettings`, `InterfaceSettings`, `ComputeSettings`,
      `HotkeySettings`. Закрепления стадий — `Map<ComputeStage,
      ComputeBackend>` (уходят `switch` на `:269–291` и четыре тернарника на
      `:392–401`); клавиши — `Map<HotkeyAction, Hotkey?>` (уходят четыре
      флага `clear*Hotkey`). `toJson/fromJson` — в домене, на диск — **одним
      блобом** с однократным чтением старых ключей: сейчас одно `update()` —
      это около 40 полных синхронных перезаписей файла.
- [ ] **`pipeline_graph.dart` — четыре файла в одном (1030 строк):** модель
      (`:17–292`), раскладка и JSON (`:294–607`), построитель (`:609–825`),
      правила соединений (`:827–1030`) → `pipeline_graph_model.dart`,
      `pipeline_layout.dart`, `pipeline_graph_builder.dart`,
      `pipeline_connections.dart`, прежний файл — баррель.
      `buildPipelineGraph` (CC 33, 132 строки) пересобирает узлы вторым
      проходом поле за полем (`:665–678`) → сначала позиции, `sends`,
      `carrying`, потом узлы один раз. `proposeDisconnect` (`:994–1030`) —
      лесенка `if`, зеркалящая `switch` по записи в `proposeConnection`;
      комментарий на `:998–1000` уже уехал не на ту ветку.
- [ ] **`AppRepository`:** ~35 из ~50 членов — однострочные пересылки.
      Настоящая ценность — сборка конфига, страж «старт или стоп»,
      приглушение и предложение встроенных паков. Шесть копий
      `try / catch(_) / stop / rethrow` → один `_orStop()`. Деление — см.
      этап 4. `GlossaryService.withBuiltIn` пишет файл-метку **до** того, как
      `app_repository.dart:73` сохранит словарь: сорвавшееся сохранение теряет
      встроенный пак навсегда → загрузка, слияние, сохранение и метка одним
      методом.
- [ ] **Подпроцессы без присмотра:** `Process.run` для whisper
      (`local_inference_service.dart:459`) без таймаута, и `stop()` не может
      его убить; `_runPip` отменяет сторожевой таймер вне `finally`
      (`runtime_storage_service.dart:320–322`).
- [ ] **Сырые исключения мимо контракта ошибок:** `NativeEngineException`
      (`native_engine_service.dart:32`, `:1057`), `TimeoutException`
      (`local_inference_service.dart:333`), `FormatException` (`:1130`)
      доходят до `describeFailure` и печатаются как есть → оборачивать в
      `LoreDubFailure`.
- [ ] **Слои.** Девять импортов `ui → data/services` тянут константы и
      значения, живущие в файлах сервисов (`exitDetailSeparator`,
      `overlappingVoices`, `isNewerRelease`, `RejectedPython`, id рантаймов) →
      в домен. `domain/runtime_paths.dart:4` импортирует `dart:io` и щупает
      диск — ему место в `data/`. `modelCatalog` и `runtimeCatalog` —
      глобальные изменяемые списки → неизменяемые.
- [ ] **Композиция:** сборка зависимостей размазана по `app.dart:79–84`,
      `app_repository.dart:32–37`, `update_repository.dart:15`,
      `native_engine_service.dart:50`; `_inference` не внедряется, статические
      `LocalInferenceService.*` зовутся восемь раз → один `composition.dart` с
      обязательными именованными зависимостями. Фреймворк DI не нужен.
- [ ] **Мелкие дубли домена:** `GlossaryPack` ≈ `CharacterPack`; «вставка с
      сохранением места» написана четырежды (`character.dart:124`, `:217`;
      `glossary.dart:292`, `:369`) → расширение `List.upserting`; правило
      `translates` живёт в трёх местах (`model_selection.dart:123`,
      `pipeline_graph.dart:625`, `native_engine_service.dart:856`) →
      `AppSettings.translates`; открытие/закрытие клиента загрузки — пять раз
      → `withDownloadClient`; `ProcessStarter` объявлен дважды и по-разному.
- [ ] `freshOcrText` (CC 33): замыкание меняет три захваченные переменные →
      `_lcsTable`, `_unmatched`, `_runs`.
- [ ] Кодогенерация: домену `equatable` не нужен — равенств, написанных
      руками, всего восемь, и `PipelineNode ==` стоит на пути кадра холста.
      Настоящая цена — `copyWith` с 15 флагами `clear*`. Сначала дробление
      `AppSettings` (зависимостей не требует); если флаги останутся болью —
      `freezed` только для настроек и состояний: сгенерированное и так
      коммитится (ffigen, l10n).
- [ ] Уехавшие комментарии: `native_engine_service.dart:454–464`,
      `:525–531`; `local_inference_service.dart:662–672`;
      `app_repository.dart:59–67`; `app_settings.dart:70–72`;
      `character.dart:51–53`; `glossary.dart:6`. `CLAUDE.md` всё ещё называет
      `_processing` — теперь это `PhraseQueue`.

---

## 9. Этап 6 — Python-воркер и C++ (P2)

### `inference_worker.py` (1506 строк)

- [ ] **`main()` — 605 строк** (`:898–1502`): 21 аргумент, загрузка моделей,
      десять замыканий, делящих состояние через `nonlocal` (`:1233`,
      `:1268`), и цикл запросов на 212 строк из восьми блоков
      `if request.get(...)` / `continue`. Проверки непоследовательны: где-то
      истинность, где-то `is not None`, поэтому `{"fingerprint": ""}`
      проваливается в путь текста. Разложить:
  - `parse_arguments()`, `load_models(args) -> Models`;
  - `class Casting`: `identify`, `read_as`, `voice_for`, `timbre_for`,
    текущие голос и тембр, `as_heard`;
  - `class Session` с таблицей `HANDLERS = {"fingerprint": …, "voiceFrom": …,
    "voicedBy": …, "glossary": …, "asHeard": …, "listen": …, "preview": …,
    "diarize": …}`, диспетчеризация по наличию ключа, `dub` — по умолчанию;
  - декоратор `@needs("converter")` вместо трёх копий «converter is not
    loaded» (`:1307`, `:1325`, `:1362`).
- [ ] **Дубли:** страж чтения WAV — пять раз (`:211`, `:597`, `:1193`,
      `:1371`, `:1422`); `embed(...).flatten().float().cpu().numpy()` — пять;
      `nearest` — дважды (`:778–788`, `:855–866`); цепочка синтез → конверсия
      → темп → запись WAV — дважды (`:1387–1414`, `:1457–1479`). На каждую
      реплику WAV читается и `median_f0` считается дважды (`identify` на
      `:1194–1201` и снова через `voice_for` на `:1251`). → dataclass'ы
      `Clip(samples, rate)`, `Speaker(kind, index)`, `Card` (уходят шесть
      аксессоров на `:868–895`), `ToneConverter.fingerprint()`, `speak()`,
      `write_wave()`.
- [ ] **Разбить на модули:** `text.py` (предложения, транслитерация,
      `readable`, `Glossary`, `TranslationMemory` — без numpy и torch),
      `audio.py`, `voices.py`, `models.py`, `protocol.py`, тонкая точка входа.
      Цена модуля сейчас — строка в `pubspec.yaml`, вызов `_extractScript` и
      фикстура теста; сделать её постоянной — ассет-каталог `assets/runtime/`
      и перечисление через `AssetManifest`. `sys.path.insert` с `:1057`
      поднять в начало: `._pth` встроенного интерпретатора отключает
      автоматический каталог скрипта.
- [ ] **Тестов на Python нет вообще.** Порядок: `sentences` (сокращения,
      «I was... afraid.», реплика про вертолёт) → `Glossary` (общая с Dart
      фикстура для `_key` ↔ `normalizedGlossaryKey` — `CLAUDE.md` требует
      менять их вместе, а проверить это нечем; `""` против `None`) →
      `transliterated` / `readable` с подставным `translate` →
      `TranslationMemory` → `speaker_cuts`, `quietest_moment`, `median_f0`,
      `change_speed`. `pytest` + `ruff` — шагом CI.
- [ ] **Протокол делит `sys.stdout` с любым `print` библиотек.** Целые
      мусорные строки Dart терпит, вывод без перевода строки портит следующий
      ответ → `PROTOCOL = sys.stdout; sys.stdout = sys.stderr` в самом начале,
      `traceback` на `:1501` — в stderr.
- [ ] `json.loads`, вернувший список, число или `null`, бросает непойманный
      `TypeError` и убивает воркер (`:1297–1302`) → `isinstance(request,
      dict)`. То же на старте для JSON неверной формы (`:481–486`,
      `:834–850`) → общий `load_json(path, default)`.
- [ ] **Пакет Silero — единственный исполняемый артефакт без дайджеста:**
      `torch.package…load_pickle` исполняет упакованный код, а у записей
      `_silero` в каталоге есть `byteSize`, но нет `hash`
      (`model_catalog.dart:208–231`) → SHA-256 для всех семи.
- [ ] Числа без имени: ограничение темпа (дважды, `:166` и `:959`),
      `rate // 2` (`:1200`), `max_decoding_length=160` (`:1090`), `> 2`
      (`:443`). `build_voice` (80 строк, два вложенных помощника) →
      `measure_clips`, `without_strangers`, `voice_report`. Аннотаций типов
      нет нигде. Диаризация эмбеддит окна по одному (`:685–689`) → батчем.

### `native/`

- [ ] **`lore_dub_native.cpp` — файл-бог:** 881 строка, 15 глобалов, 43
      условных директивы; ABI, очередь событий, JSON, UTF-8, список
      процессов, проба DXGI, громкость сессий, горячие клавиши и waveOut в
      одном месте. → `event_queue.{h,cpp}` со строителем `EventJson` (вместо
      ~15 склеек строк руками), `flat_json.h`, `text_encoding.h` (сейчас три
      разных конвертера UTF-8: `:100`, `process_loopback_capture.cpp:92`,
      `ocr_capture.cpp:154`), `process_list.cpp`, `graphics_probe.cpp`,
      `session_volume.cpp`, `hotkeys.cpp` (`class HotkeyThread`),
      `wave_player.cpp`; в исходном файле остаётся только ABI. `ld_start`
      (`:728–804`) → `ParseStartConfig` + `StartOcrSession` +
      `StartAudioSession`. Каждый файл — строка в `hook/build.dart:15–21`.
- [ ] **Конфиг через границу не плоский, вопреки `CLAUDE.md`.** Натив ищет
      ключ первой подстрокой по всему документу (`:121–170`), а Dart шлёт
      весь конфиг с вложенными объектами (`app_repository.dart:191`,
      `native_engine_service.dart:168–169`). Работает, пока `jsonEncode` не
      ставит пробелов и ключи не совпали. `\uXXXX` декодируется неверно
      (`:146`); `std::stod` и `std::to_string(double)` зависят от локали C.
      → Dart шлёт `_nativeConfig` только с нативными ключами; натив — один
      проход `FlatJson::Parse -> map`, числа через `from_chars` / `to_chars`.
      Тащить nlohmann/json незачем: вход — свои же плоские скаляры, выход —
      восемь форм событий; ~70 строк `flat_json.h` с тестами закрывают риск.
- [ ] **`CaptureThread` — 157 строк** (`process_loopback_capture.cpp:189–345`):
      активация, инициализация, VAD, концовка фразы, удержанный дубль и
      запись файла вместе; одна и та же очистка дескрипторов трижды. →
      `ActivateLoopbackClient()`, чистый `PhraseSegmenter` (`Feed`, `Finish`),
      RAII `UniqueHandle` / `RoApartment`.
- [ ] Проглоченные HRESULT у `GetNextPacketSize` / `GetBuffer` (`:275`,
      `:279`): захват с отвалившимся клиентом остаётся «слушающим» и не
      слышит ничего → `on_error(WindowsError(hr))` и выход из цикла.
- [ ] `VisitSessions` (`lore_dub_native.cpp:278–343`) пропускает
      `CoUninitialize` на четырёх ранних выходах, флаг `restore` меняет
      поведение в четырёх местах, `changed` никем не читается → RAII
      `ComApartment`, `ForEachRenderSession(fn)`, раздельные `DuckProcess` /
      `RestoreDuckedSessions`.
- [ ] Поток клавиш читает глобальный `ocr_capture` (`:501`); безопасность
      держится на порядке `join` в `ld_stop` и на том, что Dart зовёт
      `setHotkeys` только после старта, а сам ABI этого не требует →
      `std::shared_ptr<OcrCapture>` в `HotkeyConfig`, `ld_set_hotkeys`
      отказывает без сессии.
- [ ] **Единственный флаг компилятора — `/EHsc`** (`hook/build.dart:25`) →
      `/W4 /permissive- /utf-8 /sdl`, определения `NOMINMAX`, `UNICODE`,
      `WIN32_LEAN_AND_MEAN`; `/analyze` или clang-tidy в CI. Уйдут пять
      `#define NOMINMAX` по файлам и обход `(std::max)`.
- [ ] ~70 строк под `#ifdef _WIN32` существуют только ради Linux-задачи
      GitLab → `native/stub.cpp`, где все `ld_*` возвращают −2, выбор по
      `targetOS` в хуке; боевые исходники остаются без заборов.
- [ ] `ld_hold_take(0)` обещает дубль короче 0,35 с, который
      `process_loopback_capture.cpp:331` затем выбрасывает, а Dart ждёт его
      90 секунд (`native_engine_service.dart:475–485`) → возвращать 0 ниже
      `kMinimumSpeechSamples`. Ожидание `WHDR_DONE` (`:694`) не ограничено.
- [ ] Нативных тестов нет. `flat_json`, `PhraseSegmenter`, `StableText`
      (дебаунс OCR с безымянными 2, 6 и 13×50 на `ocr_capture.cpp:393–430`),
      `RegionWithin` — простым исполняемым файлом на `assert`; clang в
      GitLab-задаче уже стоит.

---

## 10. Этап 7 — тесты, линты, CI (P1, параллельно остальному)

### Тесты

- [ ] `test/widget_test.dart` — 188 тестов и групп в одном файле почти на
      4000 строк → по файлу на экран (`test/src/ui/live/…_test.dart` и т. д.)
      с общей постановкой в `test/support/` (сейчас там один помощник):
      `pumpDashboard(tester, …)`, фабрики состояний, общие фейки.
- [ ] Фейки наследуют **конкретные** репозитории
      (`_CastRepository extends AppRepository`,
      `_GraphRepository extends AppRepository`,
      `_SlowStartRepository extends AppRepository`; `_FixedModelRepository`
      написан дважды) — всё, что не переопределено, остаётся боевым кодом.
      После разреза `AppRepository` (этап 4) у репозиториев появляются
      интерфейсы, фейки переезжают в `test/support/fakes/`, по одному на
      интерфейс.
- [ ] `bloc_test` 10 + `mocktail`: переходы — `blocTest(build:, seed:, act:,
      expect:)`, виджет-тесты — `MockBloc` + `whenListen`. В тестах 98 мест
      с `seed()` / `PipelineGraphSeeded` / `DashboardView(cubits:)`, поэтому
      делается вместе с разбиением файла, экран за экраном.
- [ ] Тесты на то, чего сейчас нет: `NativeEngineService` и
      `LocalInferenceService` (после `NativeBridge` / `WorkerChannel`),
      Python (`pytest`), натив (исполняемый файл на `assert`).

Состояние на момент аудита: 629 тестов, все зелёные, 111 с; goldens
`test/screenshots.dart` совпадают с закоммиченными (18 из 18) — то есть
страховка для этапа 2 уже рабочая. Покрытие строк (без сгенерированного):

| Область | Покрыто | % |
| --- | ---: | ---: |
| Всего `lib/` | 8041 / 10101 | 79,6 |
| `domain/` | 1093 / 1179 | 92,7 |
| `ui/dashboard/` без кубитов | 4458 / 5097 | 87,5 |
| `ui/dashboard/cubits/` | 1055 / 1313 | 80,4 |
| `data/services/` | 995 / 1875 | 53,1 |
| `data/repositories/` | 48 / 228 | 21,1 |

Хуже всего — ровно там, где нашлись дефекты из 1а:
`local_inference_service.dart` 12,3 % (284 строки без тестов),
`native_engine_service.dart` 17,5 % (428), `app_repository.dart` 18,2 % (157);
дальше `glossary_cubit.dart` 50 % и `downloads_cubit.dart` 55,5 %.

- [ ] Покрытие — шагом CI (`flutter test --coverage`) с храповиком по
      `data/`: сначала не ниже текущего, после этапа 5 — цель 80 %.

### Линты

- [ ] `bloc_lint` 0.4.2 — официальный линтер библиотеки bloc. Девять правил:
      из рекомендованных — `avoid_flutter_imports`, `avoid_public_fields`,
      `avoid_public_bloc_methods`, `prefer_void_public_cubit_methods`,
      `prefer_file_naming_conventions`; сверх них включить `prefer_bloc` —
      это и есть «Bloc по умолчанию» из раздела 2, проверяемый машиной (два
      оставленных кубита получают явный `// ignore`, чтобы исключение было
      видно в коде).
      Работает не через `flutter analyze`, а своей командой: `dart pub global
      activate bloc_tools`, затем `bloc lint .` отдельным шагом CI (и через
      расширение в IDE).
- [ ] Встроенные, которых нет в `flutter_lints`: `unawaited_futures`,
      `discarded_futures`, `cancel_subscriptions`, `close_sinks`,
      `avoid_dynamic_calls`, `prefer_final_locals`, `only_throw_errors`,
      `avoid_void_async`. Включать по одному, каждый — отдельным коммитом с
      исправлениями: CI идёт с `--fatal-infos`.
- [ ] Когнитивная сложность, «один виджет — один файл» и «нет методов,
      возвращающих `Widget`» — `cognitive_complexity` и `dart_code_linter`,
      см. этап 0.

### CI

- [x] `windows.yml`: проверка формата; `git diff --exit-code` после
      `ffigen` и `flutter gen-l10n` (сейчас устаревший сгенерированный файл
      ловится, только если ломает анализ); `concurrency:` с отменой
      устаревших прогонов; закреплённая версия Flutter вместо голого
      `channel: stable`; храповики из этапа 0; goldens.
- [ ] `release.yml`: после починки кодов возврата (1а) — SHA-256 установщика
      в заметках к релизу.
- [ ] Python: `ruff` + `pytest`. C++: `/W4` и clang-tidy (этап 6).
- [ ] Dependabot для `pub` и `github-actions`.

---

## 11. Документация (P3)

- [ ] `CLAUDE.md` вырос до ~600 строк повествования с историей замеров. Он
      грузится в контекст каждой сессии агента и уже отстаёт от кода
      (называет `_processing`, которого больше нет). Решения с цифрами —
      в `docs/adr/NNNN-*.md`, по одному на файл (флаги whisper, перевод по
      предложениям, три вида записей словаря, порог речи под приглушением,
      усреднение голоса карточки…); в `CLAUDE.md` остаются команды, карта
      архитектуры, инварианты и ссылки на ADR.
- [ ] `CLAUDE.md` и `AGENTS.md` «не должны расходиться» вручную → в
      `CLAUDE.md` первой строкой импорт `@AGENTS.md`, ниже — только то, чего
      в `AGENTS.md` нет.
- [ ] После этапов 2–4 обновить «Структура проекта» в `README.md` /
      `README.en.md` и раздел Architecture.

---

## 12. Порядок работ

Этапы зависят друг от друга так:

```
1а дефекты ──┐
Этап 0 ──────┼─► Этап 1 (провайдеры) ─► Этап 2 (виджеты) ─► Этап 3 (тема)
             │                                   │
             │                                   └─► Этап 4 (Bloc) ─► Этап 5 (данные)
             └─► Этап 7 (тесты, CI) — параллельно всему
Этап 6 (Python, C++) — независим, в любой момент после 1а
```

1. **1а и этап 0** — малые и сразу окупаются: дефекты закрыты, регресс
   по сложности и приватным виджетам больше не пройдёт незамеченным.
2. **Этап 1** — один большой, но механический шаг внутри одного файла.
3. **Этап 2** — самый объёмный (114 виджетов), зато каждый коммит — чистый
   перенос под защитой goldens. Порядок экранов — от простых к сложным;
   холст графа последним, под `graph_bench.dart`.
4. **Этап 3** идёт по тем же экранам вторым проходом: сначала токены и
   одна сборка `ThemeData`, потом виджеты с палитры на роли, в конце —
   тёмная тема как проверка, что ничего не забыто.
5. **Этапы 4 и 5** делаются вместе по срезам: `EngineEvent` + `SessionConfig`
   → `SessionBloc`; `JsonFileStore` → `CastBloc` / `GlossaryBloc`; блоб
   настроек → `SettingsBloc`.

Чего **не** делать: не переписывать всё разом в отдельной ветке на месяц —
каждый шаг должен вливаться в `main` зелёным; не вводить DI-фреймворк,
роутер или кодогенерацию «заодно» — ни одна задача плана их не требует.


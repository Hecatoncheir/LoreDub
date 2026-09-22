# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

LoreDub is a Windows-only Flutter desktop app that dubs game audio in real time,
fully on the local machine: capture -> ASR/translation -> TTS -> default
output. Recognition and translation can run on the CPU or the GPU.
See `README.md` for the user-facing pipeline description and release process,
and `docs/UI_DESIGN.md` for the UI tokens and information architecture.

## Commands

```powershell
flutter pub get
dart run tool/ffigen.dart          # regenerate lib/src/native/*.g.dart (committed)
flutter gen-l10n                   # after editing lib/l10n/*.arb (output is committed)
flutter test test/screenshots.dart --update-goldens   # redraw docs/screenshots/
flutter test test/graph_bench.dart  # what a frame of the graph screen costs
dart format --output=none --set-exit-if-changed lib test tool hook
flutter analyze --fatal-infos      # CI is --fatal-infos; infos must be zero
flutter test
python -m unittest discover -s test/runtime   # the worker's text half, any Python
```

Single test:

```powershell
flutter test test/src/data/services/settings_service_test.dart --plain-name "substring of test name"
```

Run the app locally (the Python/whisper runtime must sit beside the executable,
otherwise the pipeline fails at start):

```powershell
flutter build windows --debug
powershell -ExecutionPolicy Bypass -File scripts/prepare_windows_runtime.ps1 -Destination build/windows/x64/runner/Debug/runtime -SkipVulkan
flutter run -d windows
```

Full installer (`dist/LoreDub-<version>-windows-x64-setup.exe`); it re-runs
ffigen, analyze, and tests itself:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_setup.ps1
```

Subtitle mode can be tried without a game: `scripts/ocr_test_window.ps1` opens
`LoreDubOcrTest.exe`, a window drawing dialogue and a quest objective the way
a game does — its own executable, so it shows up in the process list under a
name of its own — and `scripts/check_ocr_region.ps1` drives the native OCR
capture against it and compares what Windows OCR read with what each frame
covers. Build the native library first, and leave the test window in front.

## Architecture

Four processes cooperate; changing the pipeline usually means touching more
than one of them.

1. **Flutter/Dart UI** — `lib/src/ui/`, a folder per screen (`live/`,
   `screen_text/`, `characters/`, `models/`, `settings/`, `graph/`), `shell/`
   for the frame around them (`DashboardScaffold`, `DashboardProviders`,
   navigation, header) and
   `common/` for what every screen uses; one public widget per file and no
   private ones. `dashboard/` still holds the Blocs and the files not yet
   taken apart (`TODO.md`, stage 2). State lives in `dashboard/cubits/`:
   three cubits for what is a setter and nothing more -- `FailureCubit`
   (the banner, and the `FailureSink` every bloc reports to),
   `NavigationCubit` (the section and the half of Эфир) and `StartupCubit`
   (whether the first load is back) -- and the Blocs for the rest, the
   update check (`UpdateBloc`: check, download, restart) among them.
   `UpdateAnnouncer` (`ui/shell/`) is where the two meet without either
   reading the other: it asks for the check once `StartupCubit` says the
   load is back, and words the toast when the bloc says a startup check
   found news (`UpdateState.announce`), since the wording is the
   interface's. `SettingsBloc` writes the settings
   through `SettingsRepository` and follows them back; what is made of the
   settings as they stand -- a language, a device, a pinned stage -- is an
   event of its own, built when answered from the repository rather than
   from a copy a widget held. `DownloadsBloc`
   is the models and the GPU runtimes with what is arriving laid over what
   is on disk: every download is a handler of its own, running side by
   side, and emits its ticks from inside itself; a pause or a cancel is an
   event answered while the download it stops still waits. The characters
   screen has two: `CastBloc`, the cards and the packs, and
   `VoiceCaptureBloc`, the session a voice is recorded through, the take,
   a card measured from files, a sample and a clip played back. Neither
   reads the other; both read `CastRepository`, which is where a take's
   fingerprint is written and where the cards come back from.
   `GlossaryBloc` is the glossary. `SessionBloc` is the dubbing screens' session: the player's
   requests (`LiveToggled`, `ScreenToggled`, `SceneToggled`,
   `SessionStopped`, `SessionPaused`, `SessionResumed`) and the engine's
   answers are events of one kind, where `PipelineCubit` before it kept
   the second as a table written by hand. What that session said is
   `TranscriptBloc`'s (the lines, the voices of the scene, the snippets),
   and the game the player names, with the monitors, is `SourcesBloc`'s --
   both taken out of it. `PipelineGraphBloc` is the node canvas,
   event-driven because a gesture there is a sequence (grab, move, drop)
   rather than a call, and `PipelineFactsBloc` what the scheme's nodes
   write on themselves.
   No Bloc reads another Bloc. What more than one screen needs lives in a
   repository that owns it and publishes it: `SettingsRepository`
   (`AppSettings`), `InstallRepository` (what is on disk, what the machine
   can run it on, where the runtimes are), `CastRepository` (the cards
   and the packs) and `SourcesRepository` (the processes running, the game
   named out of them and where the monitors stand -- `CaptureSources`). Each has the value as it stands and a `changes` stream
   beside it, and each publishes **synchronously** -- a screen that writes
   to a repository also listens to it, and delivered a microtask later its
   own echo arrived after it had moved on and put the older value back. The
   repository is the only writer: a cubit that also emitted what it wrote
   was a second one. The stream does not replay the current value, because
   cancelling a subscription to a generator that yields it first never
   completes inside a widget test's zone. `SettingsRepository.load()` reads
   the file once whoever asks first, so nothing depends on being started in
   a particular order. `SettingsRepository.save` publishes at once and
   writes one value at a time, only the newest of whatever arrived while
   a write was under way: a slider saves on every tick. The write in
   progress holds the next one back, not a timer, so no test has to pump
   for it. What it writes is one JSON object under one preference
   (`SettingsService`, parsed in `domain/app_settings_json.dart`, every
   default the constructor's), where it used to be forty preferences and so
   forty rewrites of the file on the interface's isolate; its keys are the
   old preferences' names, which is how the settings an older build left
   are read on the first start. The one rule that is not a value is
   `SessionCoordinator` (`domain/`): one engine, one session, and each
   screen registers its own half of it. It also publishes what the engine
   is doing (`EngineActivity`) the way a repository publishes, each screen
   reporting its half from `onChange` -- so the canvas knows whether the
   route is locked, and on what a stage runs, without reading either
   screen's cubit.
   Nothing holds the Blocs together. `DashboardProviders`
   (`ui/shell/`) makes each one in its own `BlocProvider.create`, out of
   the repositories `LoreDubBootstrap` provides above it, and starts its
   own first read there (none is lazy); the first load a start waits for
   -- the settings, what is installed and the machine's adapters -- is
   `StartupCubit.start`, and every other read is its screen's own. The
   arguments are read off the context by type, which the compiler cannot
   check, so a test pumps the whole application and reads each one back
   (`builds every screen out of the repositories above it`). The providers
   stand above `MaterialApp`, so a dialog reads the same states as the page
   that opened it. Errors from any of them go to the banner through
   `FailureSink`. Anything
   derived from settings *and* packages together is `ModelSelection`
   (`domain/model_selection.dart`), so neither cubit owns it; widgets read it
   as `context.selection` (`dashboard_context.dart`). A widget reads what
   it uses off the context
   (`context.read<X>()`, taken before any `await`). A widget that draws only
   a field or two subscribes through `BlocSelector`, or through `BlocBuilder`
   with `buildWhen: whenChanged((state) => ...)` where it still reads the
   whole state -- `(downloads) => downloads.installed` (`InstalledPackages`,
   equal through every download tick) for whatever cares only what is on
   disk -- or a download tick will redraw the screen.
   `test/src/ui/dashboard/rebuild_scope_test.dart` counts that and fails if
   it does. There is no DI framework: `AppComposition` (`lib/src/composition.dart`)
   constructs services -> repositories, handing each repository what it
   stands on and one service per file to everything that reads or writes
   it -- a file's writes are put in order by its service, so two services
   over one file would keep two orders -- and `LoreDubBootstrap`
   (`lib/src/app.dart`) provides them; the providers build the Blocs. The
   widget tests build them by hand instead (`test/support/staged_dashboard.dart`,
   `StagedDashboard`), to seed each one without anything being read, and
   put them on the screen with `provide`.
   The repositories are cut by what they hold rather than kept in one.
   `SessionRepository` is the engine and its sessions -- the starts, the
   stop, the rest, what a running worker is told, what is played.
   `SystemRepository` is what the machine has (the processes, the
   monitors, the adapters, an interpreter), `VoiceBankRepository` the
   voices each game's dubbing met, `SchemeRepository` the canvas's own
   files (the arrangement and the shelf of schemes), `GlossaryRepository`
   the glossary with its built-in packs, and `CastRepository` the cards
   with the clips and files beside them. A start still writes three paths
   into its config -- the glossary it translates with, the cast it
   recognizes, the cards cut out of the mix -- and reads them off the
   services themselves, which are only where the files are, so the
   session depends on no other repository. They were one `AppRepository`,
   which every screen was handed whole to reach one corner of it.
   The four files the player's own work is kept in -- the cast, the
   glossary, the shelf of schemes and the canvas's arrangement -- are one
   `JsonFileStore<T>` each (`data/services/json_file_store.dart`): read as
   empty when missing or damaged, JSON of the wrong shape included (the
   `TypeError` of a `fromJson` cast), written whole through a temporary
   file and one write at a time, since the canvas saves on every drop
   without waiting and two writes through one temporary file renamed over
   each other. `importJsonFiles` is the player naming a file, so a file of
   the wrong shape is refused by name there rather than read as empty.
2. **Native C++ bridge** — `native/*.cpp`, loaded through Dart Native Assets
   (`hook/build.dart` compiles it with `CBuilder`; there is no `.dll` to ship
   manually). The C ABI in `native/lore_dub_native.h` is intentionally tiny:
   `ld_start(config_json)`, `ld_stop`, `ld_poll_event_json`, process and monitor listing,
   per-process volume, WAV playback, `ld_set_paused` (capture drops what it
   finishes while set) and `ld_set_hotkeys` (RegisterHotKey on a thread with
   its own message loop, presses queued as `hotkey` events; `ld_stop` drops
   them, and joins that thread before it lets go of the capture, which the
   frame key reaches into). Everything crosses the boundary as UTF-8
   JSON. The native side hand-rolls its JSON parsing/escaping (`JsonString`,
   `EscapeJson`) — keep config keys flat and string/number valued. What a
   session is started with is `SessionConfig` (`domain/session_config.dart`),
   sealed by kind (`LiveSessionConfig`, `ScreenSessionConfig`,
   `SceneSessionConfig`, `CharactersSessionConfig`,
   `VoiceFilesSessionConfig`, `PreviewSessionConfig`) over three parts: the
   `WorkerPlan` the worker is started with, the `CapturePlan` `ld_start`
   takes, and the `LineRules` a line is read by. Only the capture crosses
   the boundary, through `CapturePlan.toNativeJson`. The blocs build the
   `WorkerPlan` (`WorkerPlan.under(settings, ...)`, `StageBackends.resolved`)
   and `SessionRepository` adds to it only what it alone knows the place
   of -- the session's glossary file, the cast and the cut off the canvas --
   and builds the capture and the line rules from the settings. The worker's models
   used to travel into the native parser as a nested object it had no use
   for, and a key the map lost on the way was found only by the native side
   refusing to start (the screen session's `processId`, gone from v0.23.0
   to v0.24.0).
   `NativeEngineService` polls `ld_poll_event_json` every 80 ms and turns
   what it finds into a `Stream<EngineEvent>`. That is the boundary: JSON is
   read in `fromNativeEvent` and nowhere above it, and what leaves is one of
   the sealed kinds in `domain/engine_event.dart` -- `SessionStateChanged`,
   `LineDubbed`, `SceneVoiceHeard`, `SnapshotRead`, `SubtitleFrameMoved`,
   `StartupProgressed`, `BackendSettled`, `HotkeyPressed`,
   `CharacterVoiceMeasured`, `EngineFailed` and the rest -- so a screen
   matches types rather than strings and the analyzer names a kind nobody
   answered. A kind this build has nothing to do with comes back null rather
   than travelling as a map with an unknown key in it.
   Which session it started is one `PipelineSession` field rather
   than a flag per session, and it is written onto every state and startup
   event on the
   way out: one engine serves the dubbing screens and the characters screen
   in turn, and the same stream reaches `SessionBloc` and `VoiceCaptureBloc`
   both, so unnamed, a start on one screen was read as a start on the other.
   A `SessionStateChanged` carrying no session is `ld_stop` coming to rest and ends
   what every screen was showing -- which is what `concerns` answers, in one
   place rather than in each cubit. Native capture runs on its own threads (`ProcessLoopbackCapture`
   WASAPI process loopback + energy VAD writing 16 kHz WAV chunks;
   `OcrCapture` GDI + Windows OCR over `AppSettings.ocrRegion`, a frame the
   player draws in Settings and stored as fractions of the foreground game
   window's client area).
3. **whisper.cpp** — invoked per audio segment as a one-shot subprocess with
   `-tr` (translate to English) and `-sns` (suppress non-speech tokens, so
   music and noise do not come back as "(soft music)" or "[Music]" captions
   that would be translated and voiced; every build ships v1.8.2, which has
   the flag). The flag does not catch everything, so what it recognizes goes
   through `withoutSoundCaptions` (`domain/sound_captions.dart`) as well —
   as does text read off the screen — and a phrase left without words is
   dropped. Which build runs is the compute setting:
   bundled `runtime/whisper/` (CPU) or `runtime/whisper-vulkan/`, or the
   downloaded `<app support>/runtime/whisper-cuda/`. OCR mode skips it.
   Recognition was the larger half of the delay before a line is heard -- 1.33 s
   of a 1.5 s chain on twelve CPU threads, against 0.06 for translation and
   0.07 for the Silero voice of the time; Vosk, which replaced it, takes about
   1 s a line of its own -- and nearly all of recognition is the encoder, which works over a
   fixed window whatever the phrase is worth. `AppSettings.roughRecognition`
   shortens that window with `-ac`: measured over nine clips, 1000 took 897 ms
   rather than 1329 and said the same words on all nine, two differing only by
   a comma. It is off by default and the number is not to be lowered without
   measuring again -- 768 turned "struggling to reconcile" into "struggling the
   reconciled", and 512 had whisper repeating a phrase back to itself, which
   would then be translated and voiced. Two flags that look like they belong
   here do nothing: `-fa` measured 1536 ms against 1328 over five runs, and the
   resident `whisper-server` that ships in the same archive answered in
   1301-1358 ms against the one-shot `whisper-cli`'s 1319-1348, spending the
   model load it saves on its own upload.
4. **Python inference worker** — `assets/runtime/inference_worker.py`, bundled
   as a Flutter asset, extracted to the app-support `work/` directory and run
   by `LocalInferenceService` as a persistent subprocess speaking
   line-delimited JSON (`{"id","text"}` in, `{"id","translated","wave"}` or
   `{"id","error"}` out, plus one `{"type":"ready"}` handshake). It keeps
   Marian and the session's voice loaded, which is why the first start takes
   minutes.
   Startup uses the bundled embedded Python (`runtime/python/python.exe`,
   see `resolvePythonExecutable`), which `scripts/prepare_windows_runtime.ps1`
   fills with torch, transformers, sentencepiece, sacremoses and ctranslate2 —
   sacremoses is what the Marian tokenizer normalizes punctuation with, and
   transformers prints a recommendation on every start without it — and with
   misaki, spacy, `en_core_web_sm` and g2p_en, which are what the English
   voice reads with.
   Translation runs under **CTranslate2** rather than transformers: the same
   Marian weights in int8 read a line in about half the time (262 ms to 107 ms
   over twelve lines) and load in 0.3 s rather than 4.1 s, and transformers is
   left holding the tokenizer alone. `translation_device` is therefore the
   worker's own answer for where translation runs — it starts where torch did
   and falls back to the processor on its own — and it is what the `ready`
   line reports as `device`. `python_discovery.dart` asks an interpreter for
   ctranslate2 along with torch and transformers, and for misaki and g2p_en
   beside them, since one without any of these would start and then fail on
   the first line that needed it — the first to translate, or the first to
   dub into English.

A line is translated a sentence at a time. Marian was trained on single
sentences and answers a reply of several with one of them, dropping the rest --
"Get to the chopper! Now! Go, go, go!" came back as "Давай, давай, давай", and five of
nine multi-sentence lines measured lost a sentence. `sentences`
(`inference_worker.py`) cuts the line where one ends and the next begins -- a
full stop before a small letter being a line thinking aloud rather than an end,
and one closing a title or an initial no end either -- and the pieces go to
CTranslate2 as a single batch, which decodes them side by side: 100 ms against
116 for the same lines whole. `TranslationMemory` keeps the last 512 sentences,
so a game repeating itself costs nothing and one shout is never rendered two
ways in the same fight. What the translator leaves in Latin script is written
out by `transliterated` rather than translated a second time. The voice reads
no Latin: `vosk_voice.py` drops whatever its phoneme map lacks -- Latin and
digits -- rather than raise on it (the Silero it replaced dropped the word
too, measured, and raised on a line that was Latin end to end), so the name
written out is the name spoken at all. None of this runs for a session
dubbing into English: `dubbed_in_latin` is true the moment there is no
translator, and the English voice reads Latin and nothing else. A letter standing on its own is
dropped the same way and is named rather than spelt: "Press F to pay respects"
is "Нажмите эф", since one letter of Cyrillic is worth as little to the
voice as one of Latin (2.07 s against the 1.98 s of the line without it, and
2.22 s named). `LATIN_RUN` stays the Latin *word*, which is what says whether
the line was translated at all; `LATIN_TEXT` is any Latin at all, which is
what has to be written over. The second pass all this replaces answered
"Rapture" with "восторг" and "Megaton" with "мегатонну", names it had no
business translating -- and only where the dubbing language is not written in
Latin itself, which `dubbed_in_latin` asks the translator once at startup: a
German line is Latin from end to end, so every one of them used to go through
the model twice for an answer that was thrown away. More than two Latin words
left behind is a line passed through rather than translated, and that is the one
case where the second pass earns the time it costs.

Segments are processed strictly sequentially — `PhraseQueue` hands them to
`PhraseProcessor` (`data/services/phrase_processor.dart`) one at a time — so a small CPU is never asked to run two inferences at
once. Preserve that when adding stages.

A start is minutes long and can be stopped anywhere in them — the button that
starts a session also cancels a start in progress. That is why the three
start events of `SessionBloc` (`SessionToggle`) are answered concurrently
rather than `droppable()`, and why the one thing their transformer drops is
the second press of a double-click: a press within `doubleClickGrace` of
the start, while it is still starting. `LocalInferenceService`
counts starts and stops in `_generation`: `start()` takes its number before
the first wait and asks after every wait whether it is still the one wanted
(`_throwIfSuperseded`), keeping what it waited for in locals until then —
never `_worker!` or `_workerReady!` after an await. Overtaken once the
interpreter is spawned, it kills that process itself, the stop having found no
worker to end; `stop()` fails a pending handshake with `pipelineStopped`, which
is what ends the wait at once rather than after `startupLimit`. A worker that
never says `ready` inside that limit is ended and reported as
`workerStartTimeout`. `SessionRepository._sessions` is the same counter a layer
up: a failed start clears the engine only while the session is still its own,
and otherwise ends as `pipelineStopped`, which the Blocs pass over
(`isPipelineStopped`) — a stop that was asked for is not an error. Its
starts write their config out before calling the engine (the session's
glossary, the cast, the cut read off the graph), so each builds the map
first and asks `_throwIfSuperseded` before the engine call and after every
wait that follows — the engine start, the duck — rather than letting a stop
landing there start a worker for nobody, or register hotkeys `ld_stop` had
just dropped. Thrown inside the start's `try`, it reaches `_endFailedStart`,
which leaves the engine to the stop or the newer start. A worker
that dies under a running session lets go of `_worker`, so the next phrase is
told there is none rather than written into a dead pipe, and calls
`onWorkerLost`, on which `NativeEngineService` reports why and stops the
session. The seams for all of this are `WorkerPreparation` and
`ProcessLauncher` (`startWorker`), with a fake `Process` (`test/support/fake_worker.dart`)
in the service's test.

`NativeEngineService._starts` is that counter once more, for the moments on
either side of the worker's minutes: the stale audio cleared before it is
asked for, and the capture directory made once it is up. A stop landing in
the first found no start to cancel, and the start went on to bring a worker
up and call `ld_start` for a session already stopped — with `_session`
cleared, so `_ofSession` named nobody and every screen took its events for
its own. One landing in the second ended the worker and left the start to
begin a capture with nothing behind it, every phrase failing as
`workerNotRunning`; a worker dying there did the same through
`_onWorkerLost`. Every start method therefore runs through `_startSession`,
which numbers the start and names the session before anything is waited for,
and each step it is made of — `_removeStaleAudio`, `_bringUpWorker`,
`_reportWorkerUp`, `_captureDirectory`, `_beginCapture`,
`_listenWithoutCapture` — asks `_throwIfSuperseded` as it begins and after
every wait of its own, so a step added to a start takes the number and asks
the same way. `stop()` and `dispose()` bump the counter before anything
else. A start that fails after its worker came up — stopped, replaced, or
refused by `ld_start` — ends that worker in `_startSession`'s one `catch`,
and only while `_workerOf` still names it: stopped, the worker is gone
already, and replaced, a later start may hold the inference service by then,
where a blind `_inference.stop()` would end a worker that was never this
start's. The engine's seams are its constructor's: `inference`, `native`
(`NativeBridge`, `data/services/native_bridge.dart` — every `ld_*` call in
Dart's own types, the one place a pointer is made and freed; a test
extends it and overrides what it needs) and `workDirectory`, which the engine's test holds back so that a
stop can land inside either wait.

Playback is not sequential in the same way. Every worker reply carries a
`speaker` key (`timbre:<n>` from the voice fingerprints with the converter,
`voice:<voice name>` without it, absent when unknown), and
`PlaybackScheduler` (`data/services/playback_scheduler.dart`) plays lines of
different speakers side by side, up to `overlappingVoices` (2) with
`AppSettings.overlapVoices`, while one speaker's lines stay in order and a
line of unknown speaker plays alone. `ld_play_wave` therefore uses its own
waveOut stream per call and blocks until the clip ends; do not go back to
`PlaySound`, which holds one sound per process and cuts off the other.

How far the game is turned down while it is dubbed is `AppSettings`' business
rather than the slider's, because Windows takes the process-loopback tap
*after* the session volume `ld_set_process_volume` sets: turning the game
down turns the capture down with it. Measured against a tone of raw peak
2614, half volume gave 1308, 18% gave 472, and zero gave nothing at all — not
one segment in eight seconds. `duckedVolume` therefore holds `originalVolume`
to `audibleDuck` (0.1), the game's own sound being what the pipeline listens
to; both volume sliders — the settings screen and the output node — read
`audibleDuck`/`loudestDuck`/`duckDivisions`, so a number set on one can be
set again on the other. The screen session turns the game down the same
way, though it has no ear in it: a switch that silenced it outright was
offered there and is gone, nothing but that page could reach it. The pace sliders pair the same way over
`slowestSpeech`/`fastestSpeech`/`speechDivisions`, with `chosenSpeed` holding
a stored value inside them. `AppSettings.duckWhileSpeaking` replaces the
session-long duck with one that lasts a line: `PlaybackScheduler.onSpeaking`
reports the edges of the dubbing's own speech — consecutive lines are one
stretch, so the game is not lifted between two lines of a scene — and
`GameDucker` (`data/services/game_ducker.dart`) turns the game down and back.
It is the one place either duck is decided -- the session's, again on a
resume, and the line's -- which were spread over the repository and the
engine until a stopped session left the game quiet for good. It is on
by default, which the compensated speech threshold below is what makes safe.

Whatever turns the game down tells the capture, because the threshold that
decides what counts as speech is measured on the ducked signal:
`ld_set_process_volume` hands `ProcessLoopbackCapture::SetSpeechAttenuation`
the factor it applied, and the loop compares against `kSpeechRms` times that
factor. Fixed, the threshold grew stricter the quieter the game was put — a
tone giving three segments per window at full volume gave none at 18%, and
gives three again with the threshold following — so a player who turned the
game down was quietly turning recognition down with it. It is also what makes
`duckWhileSpeaking` safe: the drop lands in the middle of a captured phrase,
and a fixed threshold would read it as the phrase ending.

A line is read at the player's pace until lines start queueing for the voice.
With `AppSettings.hurryWhenQueued` (on by default), `hurriedSpeed`
(`domain/speech_pace.dart`) adds a tenth per waiting line past two, to no
more than half again, and the pace travels with the request —
`{"speed": n}`, which the worker's `request_speed` clamps and hands to
`change_speed` — so it retimes that one line rather than the session. It
counts only `PlaybackScheduler.waiting`: reading faster empties the lines
waiting to be spoken, while lines waiting to be recognized are not held up by
the voice at all, and hurrying for them would rush a dubbing that is late for
another reason.

The six screens are listed in the order the work is done in — Эфир,
Экран, Персонажи, Словарь, Модели, Настройки — which is the
order of `DashboardSection` itself: the compact navigation indexes into
`DashboardSection.values`, and `_sectionMark` numbers the header off
`section.index`, so a screen put between two others renumbers the rest by
itself rather than by hand.

The Glossary screen ("Словарь", `DashboardSection.glossary`, `GlossaryBloc`,
`glossary_screen.dart`) is where the player writes down what no better model
would know. `GlossaryService` keeps it in one `<app support>/glossary.json`
for every game, like the cast and unlike the per-game bank, and every session
that translates is handed the path (`--glossary`). Three kinds, kept apart
because they reach a line at different moments and none can do another's
work. A `GlossaryKind.phrase` is a whole sentence with the player's own
translation, answered before the model is asked: the model is not wrong about
"Fire in the hole!" so much as ignorant of the game. A `GlossaryKind.name`
replaces what the translator left in Latin script, inside `readable`, and
nowhere else -- measured, the model transliterates and correctly declines the
names it does render ("The people of Megaton" comes back as "Жители
Мегатона", "Talk to the mayor of Megaton" as "с мэром Мегатона"), so a
nominative laid over the whole line would break the grammar it had already
found. Two ways of reaching further were measured and do not work: a
placeholder put in the source so the name could be substituted afterwards is
transliterated like any other Latin ("Zorvax" survived one sentence of eight,
and a short one like "Qqq" was dropped outright, taking the name with it), and
`target_prefix` only holds the start of the line -- forced "Мегатон", the
decoder wrote "Мегатонн" anyway. `suppress_sequences` looked promising on the
first two lines tried and does not survive forty-two: forbidding a rendering
puts the model's *second* choice in its place, so where the first was right
the answer gets worse -- "Добро пожаловать в Мегатон" became "в Мегафон",
"Уайтран ушел" became "Уайтрун ушла", "Жители Мегатона" became "Жители
Мегатонна". It helps only where the first choice was already broken
("из Рапта" became "из Раптуры"), and telling a broken form from a
declined one is the morphology this has none of. Do not reach for it again.
What those forty-two lines did show is a larger thing nothing here fixes: the
model translates a name it reads as a word, and differently from line to line
-- "Vault" is "Убежище" in one line and "Хранилище" in the next,
"Rapture" runs "Восторг", "Восхищение", "в восторге", and "Whiterun"
reaches "Жители Белгорода". No Latin is left to hook onto, so the only
lever the player has over it is a phrase entry on the line itself. A `GlossaryKind.word` is the third and the only one matched on the dubbing
language rather than on English: it replaces a word of what was said, after
the translation and whether or not there was one, which is how the screen's
own text is reached as well. It exists for the case nothing else can touch --
the model's rendering wandering between lines -- and that case is rarer than
one small sample suggested: over eight frames "Vault" came back as "Убежище"
seven times, declined correctly each time, and "Хранилище" once; "Whiterun"
ran seven to one the same way. The whole word is replaced and nothing less.
Swapping a stem and carrying the match's ending onto it was measured and
rejected: it turns "Восхищение сгорит" into "Восторге сгорит" and
"Ворота Восхищения" into "Ворота Восторгя", two words that mean the
same thing not having to decline the same way. Passing a declined form by
leaves the line as the model said it; inventing one puts a word that does not
exist into the player's ears. Matching ignores case and spacing on all three,
and a word entry carries the capital it was found under.
Export and import are `file_selector` dialogs over that same
file, so a glossary of a game is passed on whole and read back merged by what
an entry is filed under -- the same file imported twice leaves one of each,
and a file that disagrees wins, the player having chosen it just now. A file
holding no entries is reported by name rather than passed over, which is the
difference between an import and a start: one is the player naming a file,
the other the application opening its own. An entry is usually written from
the transcript rather than
on this screen: a line is only known to have gone wrong the moment it is
heard, and `CorrectLineButton` beside its latency badge on Эфир opens on
what was said with `TranscriptEntry.english` as the source, so the screen is
the list of what was collected rather than a place to remember to visit. It
is offered only where that English is there to file the correction under.
`GlossaryRepository.save` writes the file and then tells a running worker
(`{"glossary": {...}}`, the same shape the file holds, so the worker has one
parser): the player writes an entry down because they just heard the line go
wrong, and mean the next one to be said their way rather than the next
session.

The built-in packs are offered only where `AppSettings.targetLanguage` is
`builtInGlossaryLanguage`: their readings are Russian, and a session dubbing
into German would be handed Cyrillic for a voice that cannot read it.
Nothing is marked as offered until it has been, so a player who switches to
Russian later is offered them then.

`GlossaryEntry.silent` is a phrase the player would rather not hear: the
worker files it with an empty reading, `said()` answers the empty string
rather than None, and the sentence leaves the line where the pieces are
joined. A line left with nothing at all is answered `{"silenced": true}` with
no wave, so `InferenceResult.wavePath` is null, nothing is queued for the
voice, and the transcript shows the line as passed over rather than as one
that arrived empty. It is matched as any phrase is -- a whole sentence, so
"Reloading!" is silenced while "We are reloading the truck." is not, and one
sentence of a line may go while the rest is voiced. Only a phrase can be
silenced (`GlossaryEntry.silences`); a name and a word stand inside a line
rather than being one.

`glossary_catalog.dart` is the two packs LoreDub brings with it -- the
general one and the lines a player knows by heart, where being literally
right is not enough and a fresh translation lands wrong however correct it
is -- laid over the file once by `GlossaryService.withBuiltIn` and marked by a
`glossary.builtin` file beside it, so a pack the player threw away does not
come back. It carries phrases and nothing else, and that is measured rather
than chosen: every line in it was put through the same Marian the pipeline
runs and kept only where the answer was wrong, while a name entry was tried
against sixteen proper nouns in two frames each and fired **none** -- the
model renders every one of them and leaves no Latin for that path to catch.
A word entry is matched on the dubbing language and would reach lines that
have nothing to do with a game, so both belong in a pack made for one game
rather than in a general one. `normalizedGlossaryKey` and the worker's
`Glossary._key` both drop the marks at either end of a line, so an entry
written under "Fire in the hole!" answers the same shout heard with a full
stop; the two must be changed together.

Beside the three lists, or under them below `_packsBesideListsWidth` where
a column of its own would leave neither side readable, sit the packs
(`GlossaryPack`, file version 2 -- a
version 1 file has no `packs` key and reads as entries in none), filled the
way the cast's are, by dragging: the row carries a handle rather than being
draggable whole, since it holds a field and a selectable source that both
want the pointer. A pack is a way of reading the glossary rather than a place
entries are moved to, so it holds `GlossaryEntry.packKey` (`<kind>:<key>` --
a name and a phrase may be spelled the same and are still two entries) and
every entry stays in its list whatever names it. `Glossary.inUse` is the
whole rule: with no pack switched on it is everything written down, and with
one or more on it is only what they hold, several adding together. That is
the one place the rule lives -- the worker is handed the answer and knows
nothing of packs, through `{"glossary": ...}` while a session runs and
through `GlossaryService.sessionFile` when one starts, which writes `inUse`
to `<app support>/glossary.session.json` beside the shelf itself. Exporting a
pack writes it with the entries it names and switched off, an imported pack
keeping whatever it was switched to here: a file must not quietly change
which glossary the next line is read against. Deleting a pack leaves the
entries, deleting an entry takes it out of every pack, and a pack naming an
entry that is gone is pruned when the file is read.

The scheme ("Схема") draws the pipeline as nodes and is the second way to
the same settings, not a second set of them. It is a half of Эфир rather
than a screen of its own (`NavigationState.liveView`, `LiveTitleSwitch` --
the title of the page is the switch: the half that is up is the heading in
the accent, the other stands beside it smaller and quieter): it is
where the dubbing is arranged, and reaching it meant leaving the dubbing --
while it is the one arrangement that answers with a session running. Эфир
carries the dubbing's own settings for the same reason: how far the game is
turned down, how fast a line is read, and in which voice
(`live/dubbing_cards.dart`, moved off the settings screen).
`buildPipelineGraph` (`domain/pipeline_graph.dart`) is a pure function of
`AppSettings`, the cast and a `PipelineLayout`, so the canvas is rebuilt
whenever either changes and can never drift from them; every edit goes the
other way through `proposeConnection`/`proposeDisconnect`, which answer with
what the link would change (`RouteConnection` -> `AppSettings.captureRouted`,
`ReaderConnection` -> `Character.voicedBy`) or why it is refused. Cutting the
way in answers `RouteConnection(false)`: every stage is `unrouted` — faded,
labelled, still in its place — and `canStart` refuses until it is joined
again. Cutting either half of the translator's line answers
`TranslationConnection(false)`, which is not a setting of its own but the
dubbing language: whisper hands English over whatever the game speaks, so a
session dubbing into English (`untranslatedDubbingLanguage`) would have
nothing to translate, and the canvas draws the stage faded with the text
running from recognition straight into the voice. `PipelineGraphBloc` still
refuses that cut with `ConnectionRefusal.unsupported` where `dubbingLanguages`
lacks English, which is a catalogue with no English voice in it at all rather
than the one this ships. Joining it back asks for the first
installed language that has a translator and refuses with `translatorMissing`
when there is none; cutting the line that steps over the stage puts the stage
back, a voice with nothing to read being no state at all. `ModelSelection.translates`
is the same rule for the services, which then start the worker with no
`--translation-model` and send `"translate": false`. There is one route on the canvas, the game's sound through whisper,
because it is the only one this engine starts from here: reading the screen
is the Screen page's own session and is not drawn at all. Cutting one of the lines into the mix's `mixCast`
answers `CastConnection(<card>, false)` and takes that one card out:
it stays where it was put, drawn dark, who stands in for whom waits in it,
and the worker is started with `--as-heard <ids>`, which makes `read_as` hand
back the speaker it was given for those cards — the card lends its voice to
nobody and nobody stands in for it. A line drawn to a card or away from
one joins that card back (`_joined` in the bloc, over both ends of what was
drawn), and a line into the mix makes the drawing it came from one the game
speaks: a card with no part of its own and nobody to read for has nothing to
send, so the line would otherwise be taken and show nothing. The cut is the
scheme's, not the
settings': `PipelineLayout.silent` holds it by character (every drawing of a
card answers together, the mix being told a character once), which is why
`withoutNode` drops a card from it when the last drawing of that card leaves
the canvas — a card the scheme does not draw is voiced the way it always
was, whatever was cut while it was on it. Unlike the route it is not
locked while a session runs — a paused session keeps its cast loaded, so
this is the one branch the canvas may rewire mid-session, and the running
worker is told rather than restarted: `_voiceCard` writes the arrangement and
then `CastRepository.readAsHeard` sends `{"asHeard": [...]}`, which rebinds the
worker's own `as_heard` (not `args.as_heard`, which only seeds it). The set
is a session's, so `SessionRepository.start`/`startSceneVoices` read the
arrangement off disk for `WorkerPlan.asHeard` and
`NativeEngineService.readAsHeard` keeps the running session's config in step
with it (`SessionConfig.withAsHeard`). A card may be drawn more than once
(`CastPlacement`, `PipelineLayout.cast`): the node id of the first copy is
`character:<id>` — the name an arrangement written before copies already
files its position under — and later ones carry `#2`, `#3`, which
`PipelineNodeIds.characterOf` strips, so every copy answers with the same
card. `CastPlacement.heard` is the dashed line from `voiceCast`: a note that
the game's dialogue may hold this character, cut and drawn through
`HeardConnection`, kept with the arrangement and read by nothing else — the
worker matches every line against the whole cast whatever the canvas says. It
is what makes copies useful: the first copy is heard, the ones after it are
not, so the mix is told a character once while the part they take over runs
to the copy standing nearest (`_partOf`). A card sends a line on when the
game speaks it, when a part arrives at it, or when somebody reads it
(`_carrying`) — the last so that a substitution is never hidden. The pointer picks a socket up through a box held
at one size on the screen (`NodeMetrics.grabReach` divided by the zoom, no
taller than a row): a scheme fitted into a small window draws dots six pixels
across, which nothing can take hold of. Drawing a line is a drag, which
neither a keyboard nor a screen reader has, so every socket is also a named
control (`socket_names.dart`, "connected"/"free") whose action is
`NodeLayerActions.onLinkToggle`: the first socket takes the line up, the
second puts it down, its own lets it go, and all three go through the same
`PipelineLinkStarted`/`PipelineLinkReleased` the pointer does, so what a link
may join is answered in one place. A card is a control too -- `Semantics`
with its name and whether it is chosen, and `FocusRegion`
(`ui/common/focus_region.dart`) for Tab and the space bar, which draws it
with the edge of a chosen card. The six
stage nodes and the character cards carry typed sockets, and the one route
the engine runs can be drawn: game audio into whisper. The mix node is
`PlaybackScheduler`: the voice's
audio and every card's voice enter it, and what it puts in order leaves for
the output, which is why a character on the canvas is joined to the path at
both ends rather than hanging off it. `PipelineGraphBloc` applies the answer through
`SettingsRepository` and `CastRepository` — so a route change is locked
while a session runs, while a substitution is not, the running worker being
told of it rather than restarted — and keeps an undo history of layout,
route and readers. Schemes the player keeps are a shelf beside that arrangement:
`SavedPipeline` (`domain/saved_pipeline.dart`) holds the route
(`captureRouted`), the `PipelineLayout` — which carries the cut cards — and the
substitutions among the cards drawn, written to `<app support>/pipelines.json`
by `PipelineLibraryService` and exported and imported as the same shape.
A scheme is worked on rather than written once:
`PipelineSchemeReplaced` writes what the canvas says now into the scheme it
names, which keeps the name and the place on the shelf it already had.
Choosing one puts it back through the calls an edit makes —
`SettingsRepository` for the route, `CastRepository.voiceAs` for the
substitutions — so the other screens follow and one step back restores the scheme that was up; a scheme
that would reroute a running session is refused with `locked`. The
substitutions go back over the **whole** cast, not over the cards the scheme
names: a scheme is the whole picture of who reads whom, so a card it does not
draw is read by nobody. Applied only to what it lists, a scheme with an empty
canvas changed nothing and the arrangement it replaced went on sounding under
a canvas that said nothing about it. Models and
languages are deliberately not in it: they belong to the machine, and a
scheme from elsewhere must not name downloads this one does not have. The
card's picture is painted from `buildPipelineGraph` over the saved layout
(`pipeline_shelf.dart`), never stored, so it cannot drift from the scheme.
Only the arrangement is its own: node positions,
which cards were placed and where the canvas is looked at from, written to
`<app support>/pipeline_graph.json` by `PipelineGraphService` without holding
the event queue. Several nodes can be chosen at once: `PipelineGraphState.chosen` is the set,
`selected` stays the one node the inspector shows and is null over any other
number. Shift-click passes `add: true` to `PipelineNodeSelected`; a
control-drag over empty space draws a band in the canvas's own state and ends
in `PipelineSelectionSet` with what it covered, because the canvas owns the
geometry and the bloc owns the choice. `PipelineNodeMoved` then carries every
chosen node, clamping the whole group by whichever of them reaches
`GraphWorld` first so it keeps its shape. The canvas is `ui/graph/canvas/`:
`NodeMetrics` is the one place for card sizes and socket anchors, which the
curves (`LinkGeometry`, `LinkPainter`), the dots (`DotField`,
`DotFieldPainter`) and the hit-testing (`GraphHitTester`, pure, which also
fits the scheme into the window the first time it is drawn) all read;
`SchemeDiff` is what one edit drew and cut, `LinkCut` which lines carry a
badge, `NodeLabels` what a card writes on itself, and `pipeline_canvas.dart`
keeps the state -- the gestures, the animation and the caches below; `pipeline_inspector.dart` is the panel that stands over it, down the
right edge and the whole height of the canvas, drawn in the face of the node
it opened on — `NodePaint` (`node_paint.dart`, which the canvas draws its
cards from as well) hands it the same body, head, ink and rule, and
`nodeIcon` the same icon, so the panel on the orange output is orange and
the one on a card of the cast is dark with that card's own head. The four faces are `NodeFaces` (`graph/node_faces.dart`), a
`ThemeExtension` built from `LoreDubColors` and read as
`NodeFaces.of(context)`: they live beside the canvas because what a node
looks like is this screen's business, and the theme layer knows nothing of
nodes -- the application puts the two together in `app.dart`. It is
`buildLoreDubPanelTheme` (`graph/node_panel_theme.dart`) that turns a face into a theme,
and `AppTheme.build(LoreDubColors, Brightness)` (`theme/app_theme.dart`)
underneath -- one builder for the window and the panel both, reading
nothing but the roles, so the Material widgets standing in the panel are
the same widgets in another colour rather than a second set of them. A face
carries two greys where the window carries three, so `_colorsOf` puts
`sunk` on `panel`, `raised` and `deep` alike and `body` on `canvas`, and
`strongOutline` -- the graphite a pressable control is edged with in the
window -- is the face's own rule. It keeps the theme of each
of the four faces rather than building one per frame of a drag behind the
panel (`test/graph_bench.dart` measures that frame as `panel`). The panel declares that
theme and is built under it through a `Builder`, with a `Material` of its
own: a line of text that asks for no colour is handed one by the nearest
Material, and without those two the panel was written in the theme above
it. Anything put in the panel should read its colours off the theme —
`bodySmall` is what a label or a note is said in — rather than name one.

A frame of that canvas is watched, because a drag and a pan are a new state
sixty times a second: `test/graph_bench.dart` times one over a scheme of
twenty-four cards (by hand — it has no `_test` suffix). Three things keep it
down, and all three can be undone by accident. The graph is listened to
*innermost* in `PipelinePanel`, under the one listener to
`PipelineFactsBloc`, so `PipelineFacts` and `ModelSelection` are not built
afresh for a frame that only moved the canvas -- that bloc makes new facts
only when one of the five things the scheme is drawn from moves (the
settings, what is installed, the cast, the game named, and
`SessionCoordinator.activity`), and a download on its way is filtered out
before it reaches it; the toolbar has a listener of its own with a
`buildWhen`, so it is not built again for a drag. And the canvas keeps what
it drew: `NodeLayerCache` (`node_layer_cache.dart`) hands back each node's
`NodeLayer` -- its card and sockets -- as the same widget while its
`NodeInputs` (`node_inputs.dart`) compare equal, and `BadgeCache` does the
same for each cut badge against the point it sits at. A `NodeLayer` takes
its `NodeInputs` and the canvas's `NodeLayerActions` and nothing else, so
**anything new a card is drawn from has to go into `NodeInputs`** or it
cannot be read at all -- which is why the sockets that would take a pulled
line travel there as a mask (`offered`) worked out by the canvas once a
pull, rather than being asked of the graph inside the layer. Anything
inherited (the language, the theme) is handled by `didChangeDependencies`
throwing both caches away. `PipelineNode` carries
value equality for this, position and all, so one moved card is told from the
twenty-three that did not.

The Screen screen ("Экран", `DashboardSection.snapshot`) runs the second kind of
session, `PipelineSession.screen`: `SessionRepository.startScreenText` ->
`NativeEngineService.startScreenText` loads the worker with Marian and Vosk
only (no whisper) and then calls `ld_start` with `captureMode: 'ocr'`, which
starts `OcrCapture` over the game's window -- or over the virtual screen,
which `AppSettings.screenSource` picks between and `ocrSource` carries to the
native side -- and no audio capture at all. A window is read only while it is
the foreground one, so nothing laid over the game passes for its subtitles;
the screen is read whatever is in front, which is the only way into a game
that keeps no ordinary window, and needs no process at all (`canStartScreen`
asks for one only for the window). A process may still be named there, to be
turned down. The frame over the screen is a share of the virtual
screen -- every monitor together -- so the picker draws it on
`ScreenLayout` (`ld_list_monitors_json`, read at the start and with every
refresh of the processes) rather than on the shape of the monitor the
window of LoreDub stands on, which put a frame across two monitors where
it was not read from.

The screen is read two ways, and `ScreenReading` (`domain/screen_reading.dart`)
says which of them a session does: the subtitle frame, which arrives as
`ocrText`; the snippet the player picks out with the snapshot key, registered
through `ld_set_hotkeys`; or both, which is what the page's top card starts.
One engine and one worker serve all three and only the capture differs, so
the button of one reading ends the session of another and starts its own --
seconds, not the minute a worker takes. `AppSettings.screenVoices` adds the game's own sound to the subtitle
reading: `captureMode: 'ocrAndAudio'` starts `OcrCapture` and
`ProcessLoopbackCapture` together, the worker carries the converter and
`--revoice`, and `NativeEngineService` keeps the newest captured segment as
`_voiceHeard` rather than queueing it -- nothing of that sound is
recognized. A line the frame gains is queued with it
(`PendingPhrase.heardWave`) and reaches `processText` as `originalWavePath`,
which is the same field a dubbed phrase carries, so the worker places the
speaker and lays their timbre over the reading with nothing new in it. A
file is kept while a line still points at it (`_voicesInUse`) and let go
once that line has been read. `ScreenReading.snippets` starts
`ld_start` with `captureMode: 'none'`: nothing is scanned, the engine is up,
and the key is answered, which is why that reading needs no window and no
game (`canStartScreen` asks for one only where the frame is read, and for
the snapshot key only where a snippet is). A reading without the frame
registers no frame key either -- there is none to redraw. Live dubbing
registers the snapshot key as well.

`AppSettings.showFrameOverlay` draws that frame over the running game and
leaves it there: aiming it is most of what it is for, so it is shown whether
a session runs or not. `FrameOverlay` (`native/frame_overlay.cpp`) is a
click-through layered window of its own, always on top and never taking the
focus, that follows the game's client area on a 120 ms timer
(`AreaOfRegion`) and hides itself whenever that window is not the one in
front -- which is when the reading looks away too; over the whole screen it
is always shown. It is started and moved by `ld_show_frame(config)` and
taken off by `ld_hide_frame()`, both outside `ld_start`, so no session owns
it. `AppSettings.frameOverlayHotkey` shows and hides it from inside the
game: the key draws nothing itself, it arrives as
`{"type":"hotkey","action":"frameOverlay"}` and `SessionBloc` answers by
flipping the setting, since whether there is a frame to draw and over which
game is the application's to know. `SessionBloc._followFrameOverlay` is the
one place that keeps the drawing in step -- with the settings, which it
follows through `SettingsRepository.changes`, with the game chosen and with
a session ending -- and it registers that one key through
`SessionRepository.setIdleHotkeys` while nothing else holds the keys, `ld_stop`
having dropped them.

A second held key draws that frame over the running game rather than over a
picture of it: `frameKey`/`frameModifiers` with `frameProcessId`, the same
`SelectScreenArea` overlay, and then `RegionOfWindow` turning what was drawn
into fractions of that process's client area -- or `RegionOfScreen`, when the
screen is what is read and `frameOf` is therefore zero. The frame is handed to
the
reading thread through `OcrCapture::SetRegion` — the capture reads it on
every scan rather than holding the one it started with, so nothing is torn
down — and comes back as a `subtitleFrame` event, which forgets the previous
OCR text (the old frame's) and writes `AppSettings.ocrRegion` through
`SettingsRepository`, so the picker shows where the reading moved and the next
session starts there. A selection that missed the window answers
`failed` and changes nothing. The snapshot key is held, not
pressed: on its WM_HOTKEY the hotkey thread runs `SelectScreenArea`
(`native/snapshot_overlay.cpp`) — a dimming layered window over the virtual
screen, a click-through orange frame above it, a nested message loop, and
`GetAsyncKeyState` polled for the release — and `RecognizeScreenArea`
(`ocr_capture.cpp`) then reads the rectangle on a thread of its own. The
events are `snapshotReading`, then `snapshot` with the text (`failed` when
OCR could not run). The text is queued as `PendingPhrase.text(snapshot:
true)`, its `transcript` event carries `snapshot: true` and lands in
`TranscriptState.snapshots` rather than the transcript, and it is voiced
even while a live session is paused. Subtitle lines carry no such flag and go
to `TranscriptState.transcript`, which the screen draws beside the
snapshots and which is emptied when a screen session starts, a transcript
belonging to one session. The lists are `TranscriptBloc`'s rather than the
session's: it hears the engine itself, and learns that a session of some
kind began -- which empties what belonged to the last one -- from
`SessionCoordinator.activity`, which also says how many lines that kind
keeps. Every line that was voiced keeps the file it was read as
(`TranscriptEntry.spoken`, the engine's `_spoken` queue of the last 60,
emptied when the session ends), so the transcript can play it again rather
than ask the worker for it a second time. That list keeps `subtitlesKept` (10) lines
rather than the `linesKept` (50) Live keeps: the page scrolls as a whole
and every area on it is as tall as what it holds, so a longer list would
push the page down without being read. Starting live dubbing over a running screen session
stops it first, since its worker has no whisper.

Text read off the screen — the subtitle frame and the snippets — is in
`AppSettings.screenLanguage`, read through `textLanguage`: English, or the
dubbing language itself, which is then voiced untranslated (Marian only reads
English, and Windows OCR detects nothing). It is the screen's own setting
rather than `sourceLanguage` read a second way — the two were one field, so
naming the screen's text as Russian named the game's speech as Russian too,
and the graph, which draws the dubbing of sound and nothing else, redrew its
translator around a choice made on another page. For the same reason the
translation node shows English as what comes in: whisper runs with `-tr` and
hands English over whatever the game speaks, so `sourceLanguage` — what
whisper is told to listen for — says nothing about that stage. It reaches the native side as `ocrLanguage` (ld_start) and
`snapshotLanguage` (ld_set_hotkeys); `FindOcrLanguage` picks the installed
recognizer by primary subtag, and a missing one comes back as an
`ocrLanguageMissing` event (`FailureCode.ocrLanguageMissing`). When it equals
`targetLanguage`, `processText` sends `"translate": false` and the worker
voices the text as it is.

Subtitle reading voices only what a line gained: `NativeEngineService` keeps the
last `ocrText` and passes each new one through `freshOcrText`
(`domain/ocr_text_delta.dart`), which compares the two texts whole — the
longest common word subsequence, case and punctuation ignored. When more than
half of the previous words reappear, only the words of the new text outside
that alignment are queued, wherever they stand; a gap no longer than the
words it replaces is a misreading and is skipped. Less in common queues the
whole text, and text identical to the previous is not queued at all. The
user chose this whole-text comparison over an earlier first-line rule.
Windows OCR hands its lines over joined by `\n` (`Recognize` in
`ocr_capture.cpp`); the snippet path flattens them before translating. The previous text is kept for the whole session — the user
asked that a line coming back unchanged, even after leaving the screen, stay
silent — and forgotten only on stop. Snippets are never compared: each one
is asked for by hand.

The update check (`UpdateService`, `UpdateRepository`) reads the repository's
latest release at startup and compares only the three version numbers. The
Windows toast needs a Start Menu shortcut carrying the same `AppUserModelID`
the plugin registers (`com.loredub.LoreDub`) — the installer sets it in
`installer/lore_dub.iss`. Without that shortcut Windows accepts the toast and
files it in the notification centre without ever showing it, so a build run
straight from `build/` shows no banner. `UpdateInstaller` installs a newer
release: it downloads the release's `-windows-x64-setup.exe` asset through
`artifact_downloader.dart` into `<app support>/updates/`, and on Restart
starts that setup detached with `/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-
/CLOSEAPPLICATIONS /RELAUNCH /LOG=<updates>/update.log` and exits; the
`RelaunchRequested` check in `installer/lore_dub.iss` opens the new exe after
a silent install only when `/RELAUNCH` is present. Do not put a console
program (such as a PowerShell script) in between: started detached from the
app it dies before running a line. A setup already downloaded and verified
is picked up by the startup check, so the line opens on Restart. It
only offers this when `unins000.exe` sits beside the executable, i.e. the
per-user setup put this copy there; otherwise the line opens the release page.

A dubbing language is a voice and, unless it is English, a translator:
`dubbingLanguages` counts over the voice packages, so a language with two of
them would still be offered once, and English is offered with no Marian
behind it at all. The catalogue dubs into Russian and English: Silero, which
voiced German, Spanish, French and Ukrainian as well, is CC BY-NC,
and the dubbing is to be free to earn money with, so it went and took those
languages and their translators with it. `SettingsService` reads a stored
`targetLanguage` the catalogue no longer carries as its first language, or
the session would start with no translator and no voice.

The voice is `vosk-ru-0.9`, Vosk-TTS under Apache 2.0, measured a tie with the
Silero it replaced under the converter (0.743 against 0.745 from a game line).
The pipeline names a speech package by its first file, `model.onnx`, and
`assets/runtime/vosk_voice.py` reads the package from the directory it sits
in, answering the calls the worker was written against for Silero
(`speakers`, `apply_tts`). It turns onnxruntime's memory reuse off: planning
it over the graph's 29 000 nodes is what opening it cost, 100 s against 3,
with a line read in the same time either way. What its phoneme map lacks --
digits, Latin -- is dropped rather than raised on. The files are this
project's release `voices-vosk-v1` in `Hecatoncheir/LoreDub-models`, renamed flat from the authors' archive
with a NOTICE, as the translators are.

English is `kokoro-en-1.0`, Kokoro-82M under Apache 2.0, read by
`assets/runtime/kokoro_voice.py` — the same two calls (`speakers`,
`apply_tts`) the worker was written against. Which of the two wrappers reads
a speech package is the package's own answer rather than a flag from the
application: `load_voice` (`inference_worker.py`) takes Kokoro where
`voices.bin` sits beside the model and Vosk otherwise, both packages being
named by the same first file, `model.onnx`. What must not differ between them
is where a voice runs, so `onnx_speech.providers_for` is the one place that
answers it. Measured against Vosk on the same machine over fifteen game
lines: a tie per second of speech on the processor (RTF 0.29 to 0.31,
though an English reading of a line is longer than its Russian one), 353 MB
against 894, open in 1.0 s against 17.2, and 174 ms a line on the card with
**no per-shape penalty at all** — the opposite of Vosk, where a line of a new
length costs about 1.9 s. Under the converter it lands closer to the
character than Vosk does (0.805 and 0.865 against two targets to Vosk's 0.763
and 0.839) and its floor is far higher (0.717 against 0.548, Vosk's short
lines being what fall apart). The fp32 export is what ships: fp16 reads
correctly on the processor and goes silent on the card for `af_heart` in four
lines of five, and the quantized builds that load at all are four times
slower than fp32 (RTF 1.4, slower than real time). The catalogue lists 23 of
its 28 English voices with **measured** genders — `af_alloy` is a man at 147
Hz and `am_santa` a woman at 182, so a name says nothing — and leaves out the
five that fall between the worker's thresholds.

The phonemes are the part with a licence in it. Every other wrapper of that
model takes them from espeak-ng, which is GPLv3 and cannot travel inside an
MIT application, so `assets/runtime/english_g2p.py` reads the words misaki
(Apache 2.0) holds and answers the rest with the letter-to-sound network of
g2p_en (Apache 2.0), ported into that file because importing the package
reaches for two NLTK corpora and downloads them. Only its `checkpoint20.npz`
is used, found through `importlib.util.find_spec` so the module is never
executed; the port answers what `g2p_en.G2p.predict` answers on all forty
words it was checked against. Measured over the 119 English lines the
glossary had collected, misaki alone leaves 1.4% of the words unread, and
they are the ones a game is made of (Whiterun, Zorvax, Aiur, medkit) — unread
meaning **dropped**, since its `❓` is not in the model's vocabulary. The
fallback's guesses are not espeak's: over forty game proper nouns the two
agree on 3, differ only in stress on 4 and differ in what is said on 24. That
is the trade the licence buys, and the glossary is the lever the player has
over it. `prepare_windows_runtime.ps1` therefore installs misaki **without**
its `[en]` extra — that extra is what pulls espeakng-loader and
phonemizer-fork, the GPL half — naming `num2words` and `spacy` itself, and
installs `g2p-en` with `--no-deps` in a pip run of its own.


The translators are the one thing the catalogue does not fetch from its
authors: `_converted` points at this project's own release, in the public
`Hecatoncheir/LoreDub-models` repository (`_modelReleases`) -- the
application's repository is private, and a private release asset answers an
anonymous download with 404 -- because the
CTranslate2 conversion is made once here rather than on every machine — it
wants a transformers newer than the runtime carries.
`scripts/convert_translators.py` builds them and prints the entries, sizes
and SHA-256 filled in for every file, which the upstream checkpoints could
never be (OPUS-MT publishes no digests). CC-BY-4.0 allows the conversion and
its distribution and asks for attribution and a statement of what changed:
that is the NOTICE travelling in each package, and it is downloaded with the
weights rather than written afterwards. `ModelStorageService` sweeps files a
package no longer names once a download completes, so the PyTorch checkpoint
of the old shape does not sit beside the new one forever.

The recognition model is a choice, not a constant: `AppSettings.whisperModel`
names a catalogue id and the pipeline is handed that package's file path.
`ModelPackage.translatesSpeech` is false for `large-v3-turbo`, which OpenAI
fine-tuned without translation data — the pipeline then drops `-tr` and only
suits an English original. `ModelPackage.translationPrefix` carries the target
token (`>>rus<<`) that the multi-target Marian models need.

The dubbing voice is chosen per phrase. With `AppSettings.automaticVoice` the
worker is handed the male and female voices of the package plus the captured
WAV of each phrase, estimates its median fundamental (`speaker_gender` in the
worker) and answers in a matching voice, reporting it back so the interface
can show it. Voice genders in `model_catalog.dart` are measured, not looked
up — add a voice only with a gender you have measured, or leave it
`VoiceGender.unknown`, which keeps the automatic choice out of it.

With `AppSettings.originalVoice` (the "Original voice" mode) the worker is
also handed the OpenVoice V2 converter directory (`--voice-converter`, a
`ModelKind.voiceConversion` package) and re-voices each line in the timbre of
its captured WAV. The network lives in `assets/runtime/tone_converter.py`, a
torch-and-numpy-only port of the MIT converter that the worker imports from
its own directory; its weights load with `weights_only=True`. A phrase with no
voiced frames keeps the previous timbre. The converter is its own
`ComputeStage.voiceConversion` (`--converter-device`), sharing the `torch-cuda`
runtime with translation; the worker brings that runtime in when either stage
asks for CUDA and reports both devices in its `ready` line. With
`AppSettings.voiceBank` the worker is also handed `--voice-bank`, a per-game
JSON file (`VoiceBankService`, `<app support>/voice_bank/<exe>.json`): a line
whose fingerprint meets a kept one at cosine >= 0.80 belongs to that
character, otherwise a line of 1.5 s or more founds a new one. Kept voices are
never averaged — the user asked for that explicitly — and replies carry
`bankSize` so the settings count can be refreshed.

Every worker reply carries the speaker it *heard* (`speaker`), and
`TranscriptBloc` collects those into `TranscriptState.speakers` — the
"Scene voices" area beside the transcript. That area shows and does not set:
who reads whom is drawn on the graph, and there is no second place to change
it. One scheme decides who speaks for whom, because three screens that could
each change it disagreed about where the answer came from — a per-game
`speaker_map/<exe>.json` was the third, and it is gone: no file, no
`--speaker-map`, no `{"assign": {...}}` request.

`AppSettings.voice` may be picked while a session runs: the write goes to
`SettingsRepository`, `SessionBloc` hears it on that repository's stream
and sends `{"speaker": name}`
to the worker (`useVoice`, one control request beside `{"glossary": ...}`
and `{"asHeard": ...}`) and keeps the running session's config in step
(`SessionConfig.withSpeaker`). A name the
package does not ship leaves the voice alone, and the worker answers with
the one actually in use.

The substitution itself is the card's: `Character.voicedBy` names the card
that reads this one, holds in every game, and is applied by the worker's
`read_as` before `voice_for`/`timbre_for`, which is why it carries both the
voice and the timbre. `speaker` is still reported as heard — the scene
list keeps one row per voice of the game, and `PlaybackScheduler` keeps
ordering lines by who spoke. Only a card can be given away: a `timbre:<n>`
voice the bank founded has no card to carry anything, and a `voice:<name>`
speaker means nothing heard who was talking at all. The substitution is
followed one hop (`readerOfSpeaker` in `domain/speaker_keys.dart` is the same
rule for the interface, and is what names the reader in the transcript and in
the scene list). The cast file is read when a session starts, so
`CastRepository.voiceAs` — which writes the file and is what both screens
call — also sends `{"voicedBy": {...}}` to a running worker, so a scheme rearranged
under a pause is heard from the next line rather than at the next start.

The voices can be placed before anything is dubbed. `PipelineSession.scene`
(`SceneToggled` -> `SessionRepository.startSceneVoices` ->
`NativeEngineService.startScene`) is the characters session with the bank and
the cast added and the recording gate left open: `ld_start` on the
game's audio plus the worker under `--embed-only`, so it is ready in seconds.
Each captured segment goes to `{"listen": path}` instead of recognition, the
worker answers with the speaker `identify` placed it as, and the segment is
dropped — the reply becomes a `sceneVoice` event and a row with no words, only
the seconds heard. The bank is the point: a voice founded while listening is
written to `<app support>/voice_bank/<exe>.json` there and then, so the
dubbing session knows it under the same `timbre:<n>` and a card recognized
there is already the one the graph gave away. Starting live dubbing over it stops it
first, as with the snapshot session.

The Characters screen (`DashboardSection.characters`, `CastBloc` and
`VoiceCaptureBloc`) is
where the player records their own cast. `CharacterService` keeps them in one
`<app support>/characters.json` for every game — unlike the per-game bank,
because the player owns these cards — and `SessionRepository.startCharacterVoices`
runs a session for recording them: `ld_start` on the game's audio plus the
worker under `--embed-only`, which loads the converter and neither Marian nor
Vosk, so the screen is ready in seconds. While a card records the capture is held open
(`ld_hold_take`, `ProcessLoopbackCapture::SetHoldingTake`): neither the
end-of-phrase silence nor the twelve-second segment cap closes it, so the take
is everything between the two button presses, to a ceiling of three minutes.
Letting go writes it within about 100 ms and answers with how much was
gathered, so a silent take is not waited for; the recording then goes to
`{"fingerprint": path}` instead of recognition and comes back as a
`characterVoice` event, which is why `stopRecording` awaits
`recordCharacterVoice(recording: false)` rather than writing the card
straight away. Nothing is measured while the take runs, so the card counts
the seconds off its own clock. It keeps
the audio too: the engine holds every measured clip until the recording ends,
and the card's own is copied to `<app support>/characters/<id>.wav` before
that, so the player can hear back what they caught. The other button on a
card speaks rather than replays — `PipelineSession.preview` loads the speech
model and the converter under `--speech-only` (no whisper, no Marian, so it
is seconds rather than a minute), and `{"preview": {...}}` synthesizes one
line of `voiceSample` in the voice and timbre the dubbing would read that
card in. The line is in `targetLanguage`, not the interface language: a
Russian voice handed English says it letter by letter. Its
worker has neither whisper nor Marian in it, so a dubbing or snapshot session
takes it over the way live dubbing takes over a snapshot — through
`SessionCoordinator.makeRoomForDubbing`, which this screen registers its own
half of, so neither cubit has to know the other; the screen refuses the
other direction itself. Everything it starts — the
recording, a sample, a card measured from files — brings up a worker of its
own, and over a session that is dubbing that took the worker from under it
while the capture went on, so every phrase after it failed for want of
whisper: the three are out while the pipeline runs, and
`SessionCoordinator.dubbingRuns`, which the dubbing screens register, has
the bloc refuse them as well. `VoiceCaptureState.previewReady` says the speech-only
worker is still the one loaded, and is dropped on any `state` event the
screen reads — the engine at rest holds no worker, and a recording holds one
with no voice in it — or the next sample skips the loading and is told there
is no worker. Which game to listen to is one choice for every screen
(`SourcesRepository`, asked for by the shared `GamePicker`, which reads
`SourcesBloc` itself), so
while a card records the picker is closed on Live and in the node panel as
well — the recording session holds the game it started with. Every
session is handed `--characters`, and the worker matches a line against the
named cast before the game's bank (`CharacterCast`), answering
`speaker: character:<id>` and reading them in the voice their card carries.
Export and import are `file_selector` dialogs over the same JSON shape, so a
file with one card and a file with twenty read the same way.

A card can also be built from files rather than from the game. The whole
tile is a `DropTarget` (`desktop_drop`), and what lands on it goes through
`ld_decode_audio` (`native/audio_decoder.cpp`): Media Foundation reads
anything Windows can play -- ogg and opus through the Web Media Extensions --
and writes 16 kHz mono 16-bit WAV through the same `wave_file::WriteMono` the
capture uses, because the rate and the loudness are part of the fingerprint
(the same clip at 48 kHz and at 16 kHz meets itself at 0.50 to 0.86). The
worker's `build_voice` then embeds every file and averages them **as the
encoder gave them**: a card's vector is the conditioning the converter
re-voices against, so it has a length (the encoder answers around 12 to 14)
as well as a direction. Cosine ignores the length, so a normalized card is
still recognized perfectly and sounds like nobody -- converting one
character into another with a unit-length target lands at 0.05 to 0.13 of
the character aimed at, further off than not converting at all, against 0.75
to 0.90 for the plain average. Normalize only for comparing. Averaging is
measured to beat keeping one clip: over 36 clips of five characters, leaving each
out in turn, the held-out clip is closer to the average of the rest than to
any single other clip 36 times out of 36, by 0.076. This is not the bank's
"never average" rule broken -- there the pipeline founds the voices and a
fingerprint that wandered would stand for a character nobody chose; here the
player names the files as one person. What the numbers also say is that a
threshold cannot tell a stranger from an odd line of the right character
(same-character pairs run 0.57 to 0.94, different-character pairs up to
0.80), so `STRANGE_FILE` (0.45) only drops what is not a voice at all, and
`LOOSE_SET` (0.80) is a warning that the set holds two voices rather than a
rejection. `VoiceFilesDropped` borrows an embed-only session
(`startVoiceFiles`, no `ld_start`, no game) when the screen has none, and
puts it down again — that one and no other. `startVoiceFiles` answers with
the session's number out of `SessionRepository._sessions`, and
`SessionRepository.stopSession` ends it only while that number is still the
current one: Live starting while the files are measured takes the worker
over without a word to this screen, and a plain stop then ended the dubbing.
A start that never came up borrowed nothing and puts nothing down.

The cards are drawn as tiles in the models' vocabulary (`character_tiles.dart`:
`CharacterTile` over `ModelTile`'s grid and action band), and under them sit
the packs — `CharacterPack`, a name and a list of character ids, that the
player fills by dragging cards into it (`Draggable`/`DragTarget` over a
`CharacterDrag` carrying the card and the pack it came from, if any). A
character may be in several packs; dropping a card on the cast takes it out of
the pack it came from, and deleting a pack leaves the cards. Both live in the
same `characters.json` (`CharacterLibrary`, file version 2 — a version 1 file
has no `packs` key and reads as a cast in none), and the worker takes only
`characters` from it, so packs never reach the pipeline. Exporting a pack
writes the pack together with its members, which is why an import merges
cards and packs by id in one step.

Telling the characters apart is not the same switch as re-voicing them.
`ModelSelection.tracksSpeakers` loads the converter whenever the package is
installed and the bank is on, and `--revoice` (`clonesVoice`) decides whether
its timbre is carried over at all. So the worker `identify()`s the speaker
first, then `voice_for()` gives each character a voice of their own —
kept in the bank with the gender heard in their founding line, so a whisper
or a shout no longer flips a character's voice mid-scene (bank format v2;
v1's bare fingerprints still load). Without the converter nothing hears who
is speaking and the per-line gender choice stands.

One of the player's own cards is the exception: `voice_for_character` decides
for it, and the card decides alone. It is read in the voice it names, or in
one of the gender it was recorded in, or — having neither, being imported or
recorded in a line that fell between the two — in whichever voice its place
in the cast lands on, the same one every time. Never in the gender of the
character it stands in for: that is what lets a man speak for a woman and a
woman for a man. The rest of `voice_for` falls back to the pitch of the line
itself, which for a substitution would be the voice being replaced.

The same encoder splits a segment that holds two speakers. Capture cuts on
silence, so a cutscene exchange without pauses arrives as one WAV;
`PhraseProcessor._splitBySpeaker` asks the worker (`{"diarize": path}` -> `{"cuts": [s]}`,
`speaker_cuts` in the worker: 1.5 s windows stepping 0.5 s, a cosine
distance over 0.25 between neighbours, the cut moved to the quietest moment
within 0.4 s), cuts the recording with `sliceWave`
(`domain/wave_slices.dart`) and recognizes and voices each piece on its own.
Segments under 3 s and pieces under 1 s are left alone, and a diarization
that fails dubs the phrase whole. The 0.25 is measured, like the bank's 0.80:
two Silero voices joined gave 0.34 across the boundary and at most 0.11 at
the seam of two phrases by one voice, and the cut landed 20 ms from the real
boundary. Measure again before moving it — a threshold too low fragments
every phrase.

Which device each stage runs on is decided in `domain/compute_device.dart`,
which is pure and unit-tested: `resolveComputeBackend` takes the user's preset,
an optional per-stage pin, and a `ComputeAvailability` (adapters from the
native DXGI probe plus the set of downloaded runtime ids) and never returns a
backend that cannot start. Adding a backend means touching that resolver,
`requiredRuntimeId`, `runtime_catalog.dart`, and `whisperBackendDirectory` —
each whisper.cpp build needs its own folder because they ship ggml libraries
of the same name compiled against different backends.

Two of the worker's three stages run in its torch and the voice in
onnxruntime, and `torch-cuda` serves all three: the runtime installs
`onnxruntime-gpu` beside torch (`RuntimePackage.companions`, a second pip run
with `--no-deps`, since its dependencies are in the bundled interpreter and a
second numpy placed first on the import path would shadow the one the
translator was built against), and it finds the CUDA 12 and cuDNN 9 libraries
in the torch the worker imports first. `onnxruntime` is the runtime's probe,
so a directory holding torch alone -- from before the voice could use the card
-- reads as not installed; installing it again finds torch there
(`previousProbeFileName`) and runs only the companions, and a companion that
fails takes only itself away rather than the 2.7 GB beside it. The card is a poor bargain for
Vosk and it is offered anyway, Automatic choosing it, because the user asked
for every stage that can run on the card to: measured on an RTX 3080 Ti, a
phrase repeated is read in 0.3 s, but every line of a new length costs about
1.9 s against the processor's 0.4 to 1.3, cuDNN planning the convolution
afresh for each shape (`Conv` was 1.8 s of a 2.5 s run), and neither the
algorithm search nor the workspace settings change it. `--speech-device`
carries the choice to the worker, and `VoskVoice.device` reads back from the
session where it really runs -- a provider asked for and not taken leaves the
session on the processor without a word -- which is what the `ready` line
reports.

`RuntimeStorageService` fetches the GPU runtimes on demand into
`<app support>/runtime/<id>/`: archives are downloaded, unpacked in an isolate
and flattened to the probe file, while CUDA torch is installed by pip into its
own directory and put on the worker's import path via `--extra-packages`.
CUDA torch is a `RuntimeInstallKind.wheel`: when the interpreter's tag matches
`wheelPython` (`cp311`), the 2.7 GB wheel comes through the shared downloader
into `runtime/.downloads/<id>/` and pip only installs that local file plus its
small dependencies; any other interpreter falls back to `pipArguments`, where
pip resolves torch from the index itself.
It shares the download loop with the model store through
`artifact_downloader.dart`, which streams to a `.part` file and resumes it
with a range request rather than refetching; a 200 to a ranged request, a 416,
or a part that fails verification all fall back to starting over. A response
that delivers nothing for `stallTimeout` is taken for stalled and reconnected
with a range, up to `stallRetries` times, before `FailureCode.downloadStalled`.
A `DownloadControl` passed in lets the interface pause (keep the part) or
cancel (delete it); the loop checks it between chunks and returns a
`DownloadOutcome` rather than throwing, because a stop the user asked for is
not a failure. pip itself has no half-way point: a stop kills it and clears
the target directory, and the pip-only route offers nothing but a cancel.

`ModelStorageService` downloads the three model packages listed in
`model_catalog.dart` to `<app support>/models/<id>/`, streaming to a temp file
and renaming atomically only after size and (where pinned) SHA-256 validation;
optional HTTP/SOCKS5 proxy applies to downloads only.

## Conventions

- Every source file starts with the `Copyright (c) 2026 LoreDub contributors.` /
  `SPDX-License-Identifier: MIT` header pair.
- Colours and lettering are roles on the theme, reached as `context.colors`
  and `context.textStyles` (`ui/theme/`): `LoreDubColors` and
  `LoreDubTextStyles` are `ThemeExtension`s put on every theme -- the
  window's light and dark and the node panel's -- so a widget of ours
  standing in the panel is painted in that node's face without knowing it.
  `LoreDubColors.dark` is the light set turned over, and
  `AppSettings.interfaceTheme` picks between them or follows Windows. Three
  roles do not simply swap: `deep` means a surface that contrasts with the
  ground, so on the ink it is the pale one; `accentStrong` is darker against
  paper and lighter against the ink; and the three states are lifted, being
  unreadable on the ground at the values paper needs. The accent itself
  never turns over, so neither does what is written on it -- `onAccent` for
  a control's label and `onAccentLight` for a node's title, which is why the
  latter is a role of its own rather than riding on `onDeep`. Naming a
  colour in a widget breaks the dark theme, `Colors.white` as much as
  `LoreDubPalette`. `LoreDubPalette`
  (`theme/tokens/palette.dart`) is the raw palette behind them and is now
  behind them alone: no widget names it, and `tool/ratchet.dart` holds that
  count at zero, a widget that names one cannot be repainted by the theme.
  What stands outside the widget tree -- a `CustomPainter`, a look decided
  from state -- takes `LoreDubColors` as a parameter rather than reaching
  for the palette, and a painter compares it in `shouldRepaint`.
  `context.colors` falls back to `LoreDubColors.light` under a theme that
  carries no roles, so a widget of ours built alone in a test still draws.
  A note is `bodySmall`, a smaller one `labelSmall`.
- Interface strings live in `lib/l10n/app_ru.arb` (the template) and
  `app_en.arb`; reach them with `AppLocalizations.of(context)`. Names for
  languages and model packages are resolved in `lib/src/ui/language_names.dart`
  and `model_names.dart`, so the catalogue and domain hold codes, not wording.
  Services never raise a sentence: they throw `LoreDubFailure(FailureCode.x)`
  with the technical detail attached, and `ui/failure_messages.dart` turns it
  into text at the interface boundary. Add a code to `domain/failure.dart`, a
  case to `describeFailure`, and the wording to both ARB files together.
  `lib/l10n/app_localizations*.dart` is generated from the ARB files and
  committed; run `flutter gen-l10n` after adding a key, or the analyzer
  reports a missing getter on `AppLocalizations`.
- Comments, identifiers, docs, and commit messages are English. `README.md` is
  Russian and is the primary one; `README.en.md` follows it. `CHANGELOG.md` is
  Russian too — it becomes the GitHub release notes the players read — with
  `## [Не выпущено]` on top and the `## [x.y.z] - YYYY-MM-DD` headings the
  release script matches.
- `lib/src/native/*.g.dart` is generated — edit `native/lore_dub_native.h` and
  the `functions` allowlist in `tool/ffigen.dart`, then rerun ffigen.
- Formatter is configured for `page_width: 100` and `trailing_commas: preserve`;
  the analyzer runs with strict casts/inference/raw-types.
- Layers only point downward: `ui/` -> `repositories/` -> `services/` ->
  `native/`; `domain/` holds plain value types with no Flutter imports.
- Tests use no real native library or network: services take injectable
  seams (`ModelStorageService({http.Client?, ModelRootProvider?})`,
  `NativeEngineService({inference, native, workDirectory})`,
  `SharedPreferences.setMockInitialValues`, the exported
  `readNativeUtf8String` helper).
- A screen is tested in two halves, as the Glossary is. What its bloc does
  with an event is `blocTest` against a fake repository
  (`test/src/ui/dashboard/glossary_bloc_test.dart`); what the screen draws
  and sends is a widget test over a `MockBloc` (`test/support/mock_blocs.dart`,
  `glossaryShowing`), staged with `whenListen` and checked with `verify` on
  `add` -- which is why the events compare by value. Staged through
  `StagedDashboard(glossaryBloc: ...)` where the whole dashboard is pumped.
  Do not let a widget test drive a real bloc into a write: the disk does not
  answer inside the test's fake time, and a handler under `sequential()` is
  waited for by `close()`, so the test hangs in its teardown rather than
  failing. What is on disk is staged through the repository
  (`StagedDashboard.stageInstalled`), which the real `DownloadsBloc` follows
  with rows that have nothing arriving; a row with a download under way is
  a mock's (`downloadsShowing`), and `rebuild_scope_test.dart` sends a
  download's ticks down the mock's stream. `registerEventFallbacks` is what
  `any` stands in with. A bloc waits for its running handlers as it
  closes, so whatever a handler may read from disk is in memory in
  `StagedDashboard` -- the voice bank (`MemoryVoiceBank`), counted as a
  session comes to rest -- and no widget test drives a real one. Nor
  `droppable()`: cancelling its subscription as the bloc closes never
  completes in a widget test's zone either, and the settings screen hung
  every test that pumped it until it went. `StagedDashboard` keeps the
  cast (`MemoryCharacters`) and the canvas's arrangement and shelf
  (`MemorySchemes`) in memory for the same reason, since the canvas's and
  the inspector's tests drive the real `CastBloc` and `PipelineGraphBloc`,
  and the canvas writes its arrangement as it is drawn on. No bloc carries a test hook of its own: a
  state a test wants in place is put there by `StagedDashboard` --
  `stageSession` and `stageLists` emit on the real bloc, which is what
  `blocTest`'s `seed` does, and the rest is staged through the
  repositories the blocs follow (`stageInstalled`, `settingsRepository`,
  `sourcesRepository`, `cast`, and `stageScheme`, which fills
  `MemorySchemes` and opens the canvas the way the application does;
  `stageSection` through `NavigationCubit`'s own calls; `stageUpdates`
  emitting as `stageSession` does). `StagedDashboard` puts `StartupCubit`
  at rest as it is built, the first load being that cubit's own test.
- Commits follow Conventional Commits (`feat:`, `fix:`, `chore:`) with an
  imperative summary, and a native change carries its regenerated bindings in
  the same commit. `AGENTS.md` holds the same guidance in shorter, more
  general form for other agents — keep the two from drifting apart.

## CI and releasing

`.github/workflows/windows.yml` runs on every branch and pull request: `pub
get`, `dart format --set-exit-if-changed`, `dart run tool/ffigen.dart` and
`flutter gen-l10n` followed by `git diff --exit-code` over what they write (a
`lib/src/native/*.g.dart` or `app_localizations*.dart` left behind fails
there), `analyze --fatal-infos`, `flutter test`, `flutter test
test/screenshots.dart` **without** `--update-goldens` (so the Flutter version
is pinned in the workflow: the goldens are one engine's drawing), two
ratchets, and `flutter build windows --release`. The ratchets are the
engineering plan's (`TODO.md`, stage 0) guard against regressions while the
interface is taken apart: `cognitive_complexity` over the diff against the
commit before the push fails a function that is new above 15 or already
above it and growing, and `tool/ratchet.dart` holds the `dart_code_linter`
counts (`prefer-single-widget-per-file`, `avoid-returning-widgets`,
`avoid-nested-conditional-expressions`, configured under `dart_code_linter:`
in `analysis_options.yaml`, which `flutter analyze` does not read) and the
`LoreDubPalette.`/`Color(0x`/`TextStyle(` uses outside the theme to
`tool/ratchet_baseline.json`. A count that falls is written back with
`--update` and committed in the same change, so it cannot creep up again.
`.gitlab-ci.yml` runs format, analysis and tests on Linux.

A `v<major>.<minor>.<patch>` tag (and no other tag starting with a `v`) starts `.github/workflows/release.yml`: `tool/prepare_release.dart`
validates the tag against `pubspec.yaml` and cuts the release notes out of
`CHANGELOG.md`, `scripts/build_setup.ps1` builds the installer, and `gh`
publishes the release with that single `.exe`. `pubspec.yaml` version, the
`v<major>.<minor>.<patch>` git tag, and a matching `## [x.y.z] - date` section
in `CHANGELOG.md` must agree, or `prepare_release.dart` fails the workflow.

That workflow has not actually run since v0.22.0: GitHub refuses to start
the job -- "recent account payments have failed or your spending limit needs
to be increased" -- and the run fails in three seconds without reaching a
step. Until the account is settled a release is made by hand, which is the
same three things the workflow does: `scripts/build_setup.ps1
-ReleaseTag v<x.y.z>`, then
`dart run tool/prepare_release.dart --tag v<x.y.z> --output <notes>`, then
`gh release create v<x.y.z> --title "LoreDub <x.y.z>" --notes-file <notes>
dist/LoreDub-<x.y.z>-windows-x64-setup.exe`.

`-ReleaseTag` is the part that is easy to leave off and expensive to leave
off. Without a tag -- and outside CI, where `CI_COMMIT_TAG` or
`GITHUB_REF_NAME` supplies one -- the script versions the package
`<pubspec version>-local`, which is not only the file's name but the
installer's `AppVersion`, so Windows lists the program as "0.24.0-local"
and the uninstall entry carries that too. Renaming the file afterwards does
not fix it; the build has to be made again.

Every program the two build scripts start goes through `Invoke-Native`
(`scripts/invoke_native.ps1`, dot-sourced by both), and a line added to either
has to as well. `$ErrorActionPreference = "Stop"` stops a script on a failing
cmdlet and says nothing about an exit code — always in Windows PowerShell
5.1, which the GitLab job and the child call run under, and in PowerShell 7
unless `$PSNativeCommandUseErrorActionPreference` is on — while a CI step
sees the exit code of the last command only, which was ISCC. So a tag whose
`flutter test` had failed was still built and published. Do not redirect a
program's stderr inside the block: under 5.1 with `Stop`, a `2>&1` turns the
first line written there into a terminating error, and git and pip both
report progress on stderr.

The bundled Python is cached under `%LOCALAPPDATA%\LoreDubBuildCache`, and
what vouches for that cache is `python-3.11.9\.complete`, written after the
last install and holding the pins it was filled from. It used to be the
`torch` folder, which pip makes first, so a run that lost a later package to
the network left a cache the next run took for whole. Because the marker
names the pins, adding a package to `$Packages` in
`prepare_windows_runtime.ps1` rebuilds a cache made before it, which is what
checking `sacremoses` and `ctranslate2` folder by folder used to be for; the
marker is taken back out of the copy the installer packs. The `-vN` on the
cache key in `release.yml` is turned over only when a cache already saved
cannot be trusted.

The screenshots in `docs/screenshots/` that carry the interface are drawn by
`test/screenshots.dart`, not captured by hand: it stages the Blocs, loads the
real fonts and writes each screen as a golden at 1400x920 in both languages.
It has no `_test` suffix, so a plain `flutter test` — the run CI makes — passes
it by; run it with an explicit path and `--update-goldens` after a change that
shows on screen, and look at what it wrote. `compute-*.png` and `ocr-game.png`
are captures of a real machine and a real window, and are replaced by hand.

The landing page in `site/` deploys to GitHub Pages from `main`
(`.github/workflows/pages.yml`), triggered by `site/**`, `assets/branding/**`,
`assets/fonts/**` and `docs/screenshots/**`. That workflow copies named files
one by one, so a new image or font needs a line there as well.

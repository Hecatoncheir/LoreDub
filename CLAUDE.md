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

1. **Flutter/Dart UI** — `lib/src/ui/dashboard/`. State lives in five cubits
   (`cubits/`): `ShellCubit` (section, first load, the failure banner, the
   update check), `SettingsCubit`, `DownloadsCubit` (models, GPU runtimes,
   what the machine can run), `PipelineCubit` (status, transcript,
   processes) and `CharactersCubit` (the player's cast and the session that
   records a voice for a card), plus one Bloc — `PipelineGraphBloc`, the
   node canvas, which is event-driven because a gesture there is a sequence
   (grab, move, drop) rather than a call.
   `DashboardCubits` wires them together and runs `initialize()`;
   errors from any of them go to the shell through `FailureSink`. Anything
   derived from settings *and* packages together is `ModelSelection`
   (`domain/model_selection.dart`), so neither cubit owns it. `DashboardView`
   is a single large widget file whose parts subscribe through the four
   `_ShellBuilder`/`_SettingsBuilder`/`_DownloadsBuilder`/`_PipelineBuilder`
   wrappers — pass their `watch`/`onlyWhatIsInstalled` filters when a widget
   reads only a field or two, or a download tick will redraw the screen.
   `test/src/ui/dashboard/rebuild_scope_test.dart` counts that and fails if
   it does. There is no DI framework: `LoreDubBootstrap` (`lib/src/app.dart`)
   constructs services -> repositories -> cubits.
2. **Native C++ bridge** — `native/*.cpp`, loaded through Dart Native Assets
   (`hook/build.dart` compiles it with `CBuilder`; there is no `.dll` to ship
   manually). The C ABI in `native/lore_dub_native.h` is intentionally tiny:
   `ld_start(config_json)`, `ld_stop`, `ld_poll_event_json`, process listing,
   per-process volume, WAV playback, `ld_set_paused` (capture drops what it
   finishes while set) and `ld_set_hotkeys` (RegisterHotKey on a thread with
   its own message loop, presses queued as `hotkey` events; `ld_stop` drops
   them, and joins that thread before it lets go of the capture, which the
   frame key reaches into). Everything crosses the boundary as UTF-8
   JSON. The native side hand-rolls its JSON parsing/escaping (`JsonString`,
   `EscapeJson`) — keep config keys flat and string/number valued.
   `NativeEngineService` polls `ld_poll_event_json` every 80 ms and turns
   `{"type":"audioSegment"|"ocrText"|"state"|"error"}` events into a Dart
   stream. Which session it started is one `PipelineSession` field rather
   than a flag per session, and it is written onto every `state` event on the
   way out: one engine serves the dubbing screens and the characters screen
   in turn, and the same stream reaches `PipelineCubit` and `CharactersCubit`
   both, so unnamed, a start on one screen was read as a start on the other.
   A `state` event carrying no session is `ld_stop` coming to rest and ends
   what every screen was showing. Native capture runs on its own threads (`ProcessLoopbackCapture`
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
   Recognition is the larger half of the delay before a line is heard -- 1.33 s
   of a 1.5 s chain on twelve CPU threads, against 0.06 for translation and
   0.07 for Silero -- and nearly all of it is the encoder, which works over a
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
   Marian and Silero loaded, which is why the first start takes minutes.
   Startup uses the bundled embedded Python (`runtime/python/python.exe`,
   see `resolvePythonExecutable`), which `scripts/prepare_windows_runtime.ps1`
   fills with torch, transformers, sentencepiece, sacremoses and ctranslate2 —
   sacremoses is what the Marian tokenizer normalizes punctuation with, and
   transformers prints a recommendation on every start without it.
   Translation runs under **CTranslate2** rather than transformers: the same
   Marian weights in int8 read a line in about half the time (262 ms to 107 ms
   over twelve lines) and load in 0.3 s rather than 4.1 s, and transformers is
   left holding the tokenizer alone. `translation_device` is therefore the
   worker's own answer for where translation runs — it starts where torch did
   and falls back to the processor on its own — and it is what the `ready`
   line reports as `device`. `python_discovery.dart` asks an interpreter for
   ctranslate2 along with torch and transformers, since one without it would
   start and then fail on the first line it had to translate.

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
out by `transliterated` rather than translated a second time. Silero reads no
Latin: measured, it drops the word without a sound -- "Добро пожаловать в
Rapture." speaks for the same 0.95 s as "Добро пожаловать." alone -- and
raises on a line that is Latin end to end, which reaches the player as a
failure rather than as a line, so the name written out is the name spoken at
all. A letter standing on its own is
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

Segments are processed strictly sequentially — `NativeEngineService._processing`
is a chained `Future` — so a small CPU is never asked to run two inferences at
once. Preserve that when adding stages.

Playback is not sequential in the same way. Every worker reply carries a
`speaker` key (`timbre:<n>` from the voice fingerprints with the converter,
`voice:<silero name>` without it, absent when unknown), and
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
set again on the other. The screen session has no ear in the game, so it
offers `AppSettings.silenceWhileReading` instead — one switch on its own page
— and starts with `silentDuckedVolume`, which is that same number or zero. The pace sliders pair the same way over
`slowestSpeech`/`fastestSpeech`/`speechDivisions`, with `chosenSpeed` holding
a stored value inside them. `AppSettings.duckWhileSpeaking` replaces the
session-long duck with one that lasts a line: `PlaybackScheduler.onSpeaking`
reports the edges of the dubbing's own speech — consecutive lines are one
stretch, so the game is not lifted between two lines of a scene — and
`NativeEngineService._duckForSpeech` turns the game down and back. It is on
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

The seven screens are listed in the order the work is done in — Эфир,
Экран, Персонажи, Словарь, Схема, Модели, Настройки — which is the
order of `DashboardSection` itself: the compact navigation indexes into
`DashboardSection.values`, and `_sectionMark` numbers the header off
`section.index`, so a screen put between two others renumbers the rest by
itself rather than by hand.

The Glossary screen ("Словарь", `DashboardSection.glossary`, `GlossaryCubit`,
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
heard, and `_CorrectLineButton` beside its latency badge on Эфир opens on
what was said with `TranscriptEntry.english` as the source, so the screen is
the list of what was collected rather than a place to remember to visit. It
is offered only where that English is there to file the correction under.
`AppRepository.saveGlossary` writes the file and then tells a running worker
(`{"glossary": {...}}`, the same shape the file holds, so the worker has one
parser): the player writes an entry down because they just heard the line go
wrong, and mean the next one to be said their way rather than the next
session.

The Graph screen ("Схема", `DashboardSection.pipeline`) draws the pipeline as
nodes and is the second way to the same settings, not a second set of them.
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
session dubbing into English (`untranslatedDubbingLanguage`) has nothing to
translate, and the canvas draws the stage faded with the text running from
recognition straight into the voice. Joining it back asks for the first
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
then `CharactersCubit.readAsHeard` sends `{"asHeard": [...]}`, which rebinds the
worker's own `as_heard` (not `args.as_heard`, which only seeds it). The set
is a session's, so `AppRepository.start`/`startSceneVoices` read the
arrangement off disk for `'asHeard': 'id,id'` — one flat string, the config
crossing to the native side as JSON of flat values — and
`NativeEngineService.readAsHeard` keeps `_activeConfig` in step with it. A card may be drawn more than once
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
across, which nothing can take hold of. The six
stage nodes and the character cards carry typed sockets, and the one route
the engine runs can be drawn: game audio into whisper. The mix node is
`PlaybackScheduler`: the voice's
audio and every card's voice enter it, and what it puts in order leaves for
the output, which is why a character on the canvas is joined to the path at
both ends rather than hanging off it. `PipelineGraphBloc` applies the answer through
`SettingsCubit` and `CharactersCubit` — so a route change is locked while a
session runs, while a substitution is not, the running worker being told of
it rather than restarted — and keeps an undo history of layout,
route and readers. Schemes the player keeps are a shelf beside that arrangement:
`SavedPipeline` (`domain/saved_pipeline.dart`) holds the route
(`captureRouted`), the `PipelineLayout` — which carries the cut cards — and the
substitutions among the cards drawn, written to `<app support>/pipelines.json`
by `PipelineLibraryService` and exported and imported as the same shape.
A scheme is worked on rather than written once:
`PipelineSchemeReplaced` writes what the canvas says now into the scheme it
names, which keeps the name and the place on the shelf it already had.
Choosing one puts it back through the calls an edit makes — `SettingsCubit`
for the route, `CharactersCubit.voiceAs` for the substitutions — so the other
screens follow and one step back restores the scheme that was up; a scheme
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
`GraphWorld` first so it keeps its shape. `pipeline_canvas.dart` owns the geometry (`NodeMetrics`, one
place for card sizes and socket anchors, which the curves, the dots and the
hit-testing all read) and fits the scheme into the window the first time it
is drawn; `pipeline_inspector.dart` is the panel that stands over it, down the
right edge and the whole height of the canvas, drawn in the face of the node
it opened on — `NodePaint` (`node_paint.dart`, which the canvas draws its
cards from as well) hands it the same body, head, ink and rule, and
`nodeIcon` the same icon, so the panel on the orange output is orange and
the one on a card of the cast is dark with that card's own head. It is
`buildLoreDubPanelTheme` (`ui/theme.dart`) that turns a face into a theme,
so the Material widgets standing in the panel are the same widgets in
another colour rather than a second set of them. The panel declares that
theme and is built under it through a `Builder`, with a `Material` of its
own: a line of text that asks for no colour is handed one by the nearest
Material, and without those two the panel was written in the theme above
it. Anything put in the panel should read its colours off the theme —
`bodySmall` is what a label or a note is said in — rather than name one.

A frame of that canvas is watched, because a drag and a pan are a new state
sixty times a second: `test/graph_bench.dart` times one over a scheme of
twenty-four cards (by hand — it has no `_test` suffix). Three things keep it
down, and all three can be undone by accident. The graph is listened to
*innermost* in `_PipelinePanel`, under everything the scheme is drawn from,
so `PipelineFacts` and `ModelSelection` are not built afresh for a frame that
only moved the canvas; the toolbar has a listener of its own with a
`buildWhen`, so it is not built again for a drag. And the canvas keeps what
it drew: `_drawn` holds each node's card and sockets against `_NodeInputs`, a
record of everything that layer is drawn from, and `_badges` holds each cut
badge against the point it sits at. **Anything new a card is drawn from has
to go into `_NodeInputs`**, or the card will go on showing what it showed
before; anything inherited (the language, the theme) is handled by
`didChangeDependencies` throwing both caches away. `PipelineNode` carries
value equality for this, position and all, so one moved card is told from the
twenty-three that did not.

The Screen screen ("Экран", `DashboardSection.snapshot`) runs the second kind of
session, `PipelineSession.screen`: `AppRepository.startScreenText` ->
`NativeEngineService.startScreenText` loads the worker with Marian and Silero
only (no whisper) and then calls `ld_start` with `captureMode: 'ocr'`, which
starts `OcrCapture` over the game's window -- or over the virtual screen,
which `AppSettings.screenSource` picks between and `ocrSource` carries to the
native side -- and no audio capture at all. A window is read only while it is
the foreground one, so nothing laid over the game passes for its subtitles;
the screen is read whatever is in front, which is the only way into a game
that keeps no ordinary window, and needs no process at all (`canStartScreen`
asks for one only for the window). A process may still be named there, to be
turned down. One
session therefore answers for both halves of that screen — what the subtitle
frame gains, which arrives as `ocrText`, and what the player picks out with
the snapshot key, registered through `ld_set_hotkeys`; live dubbing registers
the key as well. Because the frame is read out of one window, this session
needs a process chosen, which `canStartScreen` checks.

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
`SettingsCubit`, so the picker shows where the reading moved and the next
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
`LivePipelineState.snapshots` rather than the transcript, and it is voiced
even while a live session is paused. Subtitle lines carry no such flag and go
to `LivePipelineState.transcript`, which the screen draws beside the
snapshots and which `toggleScreenText` clears at the start, a transcript
belonging to one session. Starting live dubbing over a running screen session
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
them (Russian has `v5_3_ru` and the MIT CIS package) is still offered once,
and English is offered with no Marian behind it at all.

The translators are the one thing the catalogue does not fetch from its
authors: `_converted` points at this project's own release, because the
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
`PipelineCubit` collects those into `LivePipelineState.speakers` — the
"Scene voices" area beside the transcript. That area shows and does not set:
who reads whom is drawn on the graph, and there is no second place to change
it. One scheme decides who speaks for whom, because three screens that could
each change it disagreed about where the answer came from — a per-game
`speaker_map/<exe>.json` was the third, and it is gone: no file, no
`--speaker-map`, no `{"assign": {...}}` request.

The substitution itself is the card's: `Character.voicedBy` names the card
that reads this one, holds in every game, and is applied by the worker's
`read_as` before `voice_for`/`timbre_for`, which is why it carries both the
Silero voice and the timbre. `speaker` is still reported as heard — the scene
list keeps one row per voice of the game, and `PlaybackScheduler` keeps
ordering lines by who spoke. Only a card can be given away: a `timbre:<n>`
voice the bank founded has no card to carry anything, and a `voice:<name>`
speaker means nothing heard who was talking at all. The substitution is
followed one hop (`readerOfSpeaker` in `domain/speaker_keys.dart` is the same
rule for the interface, and is what names the reader in the transcript and in
the scene list). The cast file is read when a session starts, so
`CharactersCubit.voiceAs` — which the graph bloc is now the only caller of —
also sends `{"voicedBy": {...}}` to a running worker, so a scheme rearranged
under a pause is heard from the next line rather than at the next start.

The voices can be placed before anything is dubbed. `PipelineSession.scene`
(`toggleSceneVoices` -> `AppRepository.startSceneVoices` ->
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

The Characters screen (`DashboardSection.characters`, `CharactersCubit`) is
where the player records their own cast. `CharacterService` keeps them in one
`<app support>/characters.json` for every game — unlike the per-game bank,
because the player owns these cards — and `AppRepository.startCharacterVoices`
runs a session for recording them: `ld_start` on the game's audio plus the
worker under `--embed-only`, which loads the converter and neither Marian nor
Silero, so the screen is ready in seconds. While a card records the capture is held open
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
`PipelineCubit.releaseWorker`, which `DashboardCubits` wires to
`CharactersCubit.stopSession` so that neither cubit has to know the other;
the screen refuses the other direction itself, its button being out while the
pipeline runs. Which game to listen to is one choice for every screen
(`PipelineCubit.selectedProcess`, asked for by the shared `ProcessPicker`), so
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
rejection. `CharactersCubit.voiceFromFiles` borrows an embed-only session
(`startVoiceFiles`, no `ld_start`, no game) when the screen has none, and
puts it down again.

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
first, then `voice_for()` gives each character a Silero voice of their own —
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
`_splitBySpeaker` asks the worker (`{"diarize": path}` -> `{"cuts": [s]}`,
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
  `SharedPreferences.setMockInitialValues`, the exported
  `readNativeUtf8String` helper).
- Commits follow Conventional Commits (`feat:`, `fix:`, `chore:`) with an
  imperative summary, and a native change carries its regenerated bindings in
  the same commit. `AGENTS.md` holds the same guidance in shorter, more
  general form for other agents — keep the two from drifting apart.

## CI and releasing

`.github/workflows/windows.yml` runs on every branch and pull request: `pub
get`, `dart run tool/ffigen.dart`, `analyze --fatal-infos`, `flutter test`,
`flutter build windows --release`. It regenerates the bindings itself, so a
`lib/src/native/*.g.dart` left behind by a header change fails there. It does
not check formatting — `.gitlab-ci.yml` is the one that runs `dart format
--set-exit-if-changed`, so run the formatter before pushing rather than
trusting the GitHub build to catch it.

A `v*` tag starts `.github/workflows/release.yml`: `tool/prepare_release.dart`
validates the tag against `pubspec.yaml` and cuts the release notes out of
`CHANGELOG.md`, `scripts/build_setup.ps1` builds the installer, and `gh`
publishes the release with that single `.exe`. `pubspec.yaml` version, the
`v<major>.<minor>.<patch>` git tag, and a matching `## [x.y.z] - date` section
in `CHANGELOG.md` must agree, or `prepare_release.dart` fails the workflow.

The screenshots in `docs/screenshots/` that carry the interface are drawn by
`test/screenshots.dart`, not captured by hand: it stages the cubits, loads the
real fonts and writes each screen as a golden at 1400x920 in both languages.
It has no `_test` suffix, so a plain `flutter test` — the run CI makes — passes
it by; run it with an explicit path and `--update-goldens` after a change that
shows on screen, and look at what it wrote. `compute-*.png` and `ocr-game.png`
are captures of a real machine and a real window, and are replaced by hand.

The landing page in `site/` deploys to GitHub Pages from `main`
(`.github/workflows/pages.yml`), triggered by `site/**`, `assets/branding/**`,
`assets/fonts/**` and `docs/screenshots/**`. That workflow copies named files
one by one, so a new image or font needs a line there as well.

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
   them). Everything crosses the boundary as UTF-8
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
4. **Python inference worker** — `assets/runtime/inference_worker.py`, bundled
   as a Flutter asset, extracted to the app-support `work/` directory and run
   by `LocalInferenceService` as a persistent subprocess speaking
   line-delimited JSON (`{"id","text"}` in, `{"id","translated","wave"}` or
   `{"id","error"}` out, plus one `{"type":"ready"}` handshake). It keeps
   Marian and Silero loaded, which is why the first start takes minutes.
   Startup uses the bundled embedded Python (`runtime/python/python.exe`,
   see `resolvePythonExecutable`), which `scripts/prepare_windows_runtime.ps1`
   fills with torch, transformers, sentencepiece and sacremoses — the last one
   is what the Marian tokenizer normalizes punctuation with, and transformers
   prints a recommendation on every start without it.

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
to `audibleDuck` (0.1) wherever the game's own sound is what the pipeline
listens to, and lets subtitle mode silence it outright, having no ear in it;
both volume sliders — the settings screen and the output node — read
`quietestDuck`/`loudestDuck`/`duckDivisions`, so a number set on one can be
set again on the other. The pace sliders pair the same way over
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

The six screens are listed in the order the work is done in — Эфир,
Фрагмент, Персонажи, Схема, Модели, Настройки — which is the order of
`DashboardSection` itself: the compact navigation indexes into
`DashboardSection.values`, and the header numbers each screen by it.

The Graph screen ("Схема", `DashboardSection.pipeline`) draws the pipeline as
nodes and is the second way to the same settings, not a second set of them.
`buildPipelineGraph` (`domain/pipeline_graph.dart`) is a pure function of
`AppSettings`, the cast and a `PipelineLayout`, so the canvas is rebuilt
whenever either changes and can never drift from them; every edit goes the
other way through `proposeConnection`/`proposeDisconnect`, which answer with
what the link would change (`RouteConnection` -> `captureMode`,
`ReaderConnection` -> `Character.voicedBy`) or why it is refused. Cutting the
way in answers `RouteConnection(null)`: `AppSettings.captureRouted` goes
false, the mode is remembered for whichever link is drawn back, every stage
is `unrouted` — faded, labelled, still in its place — and `canStart` refuses
until it is joined again. Cutting any of the lines into the mix's `mixCast`
answers `CastConnection(false)` and takes the player's whole cast out the
same way: the cards stay where they were put, drawn dark, who stands in for
whom waits in them, and the worker is started with `--as-heard`, which makes
`read_as` hand back the speaker it was given. Unlike the route it is not
locked while a session runs — a paused session keeps its cast loaded, so
this is the one branch the canvas may rewire mid-session, and the running
worker is told rather than restarted. A card may be drawn more than once
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
stage nodes and the character cards carry typed sockets, and only the two
routes the engine runs can be drawn: game audio through whisper, or screen
text straight into the translator, which leaves the recognition node
`bypassed` rather than gone. The mix node is `PlaybackScheduler`: the voice's
audio and every card's voice enter it, and what it puts in order leaves for
the output, which is why a character on the canvas is joined to the path at
both ends rather than hanging off it. `PipelineGraphBloc` applies the answer through
`SettingsCubit` and `CharactersCubit` — so a route change is locked while a
session runs, while a substitution is not, the running worker being told of
it the way a scene assignment is — and keeps an undo history of layout,
capture mode and readers. Only the arrangement is its own: node positions,
which cards were placed and where the canvas is looked at from, written to
`<app support>/pipeline_graph.json` by `PipelineGraphService` without holding
the event queue. `pipeline_canvas.dart` owns the geometry (`NodeMetrics`, one
place for card sizes and socket anchors, which the curves, the dots and the
hit-testing all read) and fits the scheme into the window the first time it
is drawn; `pipeline_inspector.dart` is the panel that floats over it.

The Snippet screen ("Фрагмент", `DashboardSection.snapshot`) runs a second kind of
session, `PipelineSession.snapshot`: `AppRepository.startSnapshot` ->
`NativeEngineService.startSnapshot` loads the worker with Marian and Silero
only (no whisper, no `ld_start`) and registers just the snapshot key through
`ld_set_hotkeys`; live dubbing registers it as well. The key is held, not
pressed: on its WM_HOTKEY the hotkey thread runs `SelectScreenArea`
(`native/snapshot_overlay.cpp`) — a dimming layered window over the virtual
screen, a click-through orange frame above it, a nested message loop, and
`GetAsyncKeyState` polled for the release — and `RecognizeScreenArea`
(`ocr_capture.cpp`) then reads the rectangle on a thread of its own. The
events are `snapshotReading`, then `snapshot` with the text (`failed` when
OCR could not run). The text is queued as `PendingPhrase.text(snapshot:
true)`, its `transcript` event carries `snapshot: true` and lands in
`LivePipelineState.snapshots` rather than the transcript, and it is voiced
even while a live session is paused. Starting live dubbing over a running
snapshot session stops that session first, since its worker has no whisper.

Text read off the screen — subtitle mode and snippets — is in
`AppSettings.textLanguage`: English, or the dubbing language itself when the
original is named as that (Marian only reads English, and Windows OCR detects
nothing). It reaches the native side as `ocrLanguage` (ld_start) and
`snapshotLanguage` (ld_set_hotkeys); `FindOcrLanguage` picks the installed
recognizer by primary subtag, and a missing one comes back as an
`ocrLanguageMissing` event (`FailureCode.ocrLanguageMissing`). When it equals
`targetLanguage`, `processText` sends `"translate": false` and the worker
voices the text as it is.

Subtitle mode voices only what a line gained: `NativeEngineService` keeps the
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
voiced frames keeps the previous timbre, and subtitle mode has no audio, so
`ModelSelection.clonesVoice` is false there. The converter is its own
`ComputeStage.voiceConversion` (`--converter-device`), sharing the `torch-cuda`
runtime with translation; the worker brings that runtime in when either stage
asks for CUDA and reports both devices in its `ready` line. With
`AppSettings.voiceBank` the worker is also handed `--voice-bank`, a per-game
JSON file (`VoiceBankService`, `<app support>/voice_bank/<exe>.json`): a line
whose fingerprint meets a kept one at cosine >= 0.80 belongs to that
character, otherwise a line of 1.5 s or more founds a new one. Kept voices are
never averaged — the user asked for that explicitly — and replies carry
`bankSize` so the settings count can be refreshed.

Who a line is read in can be overridden per game. Every worker reply carries
the speaker it *heard* (`speaker`), and `PipelineCubit` collects those into
`LivePipelineState.speakers` — the "Scene voices" area beside the transcript.
Assigning a character there writes `<app support>/speaker_map/<exe>.json`
(`SpeakerMapService`, named like the bank) and sends `{"assign": {...}}` to the
running worker, so the next line is already read anew; `--speaker-map` hands
the same file to the next session. In the worker `read_as` swaps the heard
`(kind, index)` for the assigned character before `voice_for`/`timbre_for`,
which is why the replacement carries both the Silero voice and the timbre,
while `speaker` is still reported as heard — the scene list keeps one row per
voice of the game, and `PlaybackScheduler` keeps ordering lines by who spoke.
A `voice:<name>` speaker means nothing heard who was talking, so it is the one
kind that cannot be replaced.

A substitution can also be set before anyone has spoken: `Character.voicedBy`
names the card that reads this one, holds in every game, and is applied by the
same `read_as` — the per-game map answers first, the card after it, one hop
only (`readerOfSpeaker` in `domain/speaker_map.dart` is the same rule for the
interface, and is what names the reader in the transcript). The cast file is
read when a session starts, so `CharactersCubit.voiceAs` also sends
`{"voicedBy": {...}}` to a running worker, the way a scene assignment does.

The voices can be placed before anything is dubbed. `PipelineSession.scene`
(`toggleSceneVoices` -> `AppRepository.startSceneVoices` ->
`NativeEngineService.startScene`) is the characters session with the bank, the
cast and the map added and the recording gate left open: `ld_start` on the
game's audio plus the worker under `--embed-only`, so it is ready in seconds.
Each captured segment goes to `{"listen": path}` instead of recognition, the
worker answers with the speaker `identify` placed it as, and the segment is
dropped — the reply becomes a `sceneVoice` event and a row with no words, only
the seconds heard. The bank is the point: a voice founded while listening is
written to `<app support>/voice_bank/<exe>.json` there and then, so the
dubbing session knows it under the same `timbre:<n>` and the replacements made
beforehand still name the same speaker. Starting live dubbing over it stops it
first, as with the snapshot session.

The Characters screen (`DashboardSection.characters`, `CharactersCubit`) is
where the player records their own cast. `CharacterService` keeps them in one
`<app support>/characters.json` for every game — unlike the per-game bank,
because the player owns these cards — and `AppRepository.startCharacterVoices`
runs a session for recording them: `ld_start` on the game's audio plus the
worker under `--embed-only`, which loads the converter and neither Marian nor
Silero, so the screen is ready in seconds. While a card records, each captured
segment goes to `{"fingerprint": path}` instead of recognition and comes back
as a `characterVoice` event; the cubit keeps the longest clear one. It keeps
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
worker's `build_voice` then embeds every file and averages them, which is
measured to beat keeping one: over 36 clips of five characters, leaving each
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

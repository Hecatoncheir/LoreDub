<p align="center">
  <img src="assets/branding/loredub-icon.png" width="180" alt="LoreDub application icon">
</p>

<h1 align="center">LoreDub</h1>

<p align="center"><b>Any game dubbed into your language while you play. Nothing leaves your machine.</b></p>

<p align="center">
  <a href="https://github.com/Hecatoncheir/LoreDub/releases/latest"><img src="https://img.shields.io/github/v/release/Hecatoncheir/LoreDub?label=download&style=for-the-badge&color=e8590c" alt="Download the latest release"></a>
</p>

<p align="center">
  <a href="https://github.com/Hecatoncheir/LoreDub/actions/workflows/windows.yml"><img src="https://github.com/Hecatoncheir/LoreDub/actions/workflows/windows.yml/badge.svg" alt="Windows build"></a>
  <a href="https://github.com/Hecatoncheir/LoreDub/actions/workflows/release.yml"><img src="https://github.com/Hecatoncheir/LoreDub/actions/workflows/release.yml/badge.svg" alt="Windows release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Hecatoncheir/LoreDub" alt="MIT license"></a>
</p>

<p align="center"><a href="README.md">Русский</a> · <b>English</b></p>

LoreDub listens to the game you select, recognizes the lines, translates them
and speaks them aloud while you play. The original is turned down rather than
off. Everything runs on your own machine: neither the audio nor the text is
sent anywhere, and there is no account to make.

<p align="center">
  <img src="docs/screenshots/live-en.png" width="900" alt="The LoreDub main screen with recognized and translated lines">
</p>

<p align="center"><i>A real run: each line recognized, translated and voiced in 1.4–1.7 s.</i></p>

## What it is good for

- **A game in a language you do not read becomes playable.** The lines are
  spoken, not shown as subtitles you have to catch mid-fight.
- **Nothing leaves the machine.** The internet is needed once, to download the
  models. After that you can play offline: recognition, translation and speech
  all run locally.
- **Only the game is heard.** The audio of the selected process is captured,
  not everything at once — Discord, music and the browser stay out of it.
  LoreDub's own speech is excluded too, so it never feeds back into
  recognition.
- **The voice matches the character.** A man's or a woman's, chosen from the
  pitch of the original, line by line — and in [Original voice](#dubbing-voice)
  mode the dubbing takes on the speaker's timbre too.
- **Five dubbing languages:** Russian, German, Spanish, French and Ukrainian.
- **A graphics card is optional.** NVIDIA roughly halves the recognition time,
  but everything works on the processor without one.
- **There is a [subtitle mode](#subtitle-mode).** When the lines are written
  rather than spoken, LoreDub reads them off the screen — from a frame you draw
  with the mouse — and voices them.
- **Free, open source, MIT.** No ads, no telemetry, no subscription.

## Quick start

**1. Download and install.** The
[latest release](https://github.com/Hecatoncheir/LoreDub/releases/latest) ships
`LoreDub-<version>-windows-x64-setup.exe`. The installer already contains
everything needed to run on the processor.

**2. Download the models on the Models screen.**

<p align="center">
  <img src="docs/screenshots/models-en.png" width="900" alt="The Models screen: the Whisper models on a size-against-quality chart, with the translators below">
</p>

Two things are needed: one recognition model (start with **Whisper base**) and
a translator/voice pair for the language you want to play in. For Russian that
is about 740 MB. The other languages need not be downloaded: every language
has its own tile, and its one Download button fetches both halves of the pair.

**3. Start the game** and let it play some sound, so it appears in the process
list.

**4. Go back to Live, choose the game and press Start dubbing.**

The first start takes a minute or two while the translator and the speech
synthesizer load. After that the lines begin to appear in the list and to be
spoken. The button becomes active as soon as a process is chosen and the
models are in place.

## What to expect

So that nothing comes as a surprise, here is the honest picture.

- **Delay.** A line is not voiced instantly: the phrase has to end first, then
  be recognized, translated and synthesized. On a graphics card that is about
  a second and a half, on a processor two and a half and up. Fine for dialogue
  and cutscenes; noticeable for quick calls during a fight.
- **The translation is machine translation.** Ordinary lines come out decently,
  but idioms, jokes and proper nouns get mangled. Wins and failures are shown
  under [Translator](#translator).
- **The voice is synthesized.** Silero is even and clear, but it is not acting.
- **Dense dialogue accumulates a lag.** No phrase is dropped, so if characters
  speak without pauses the dubbing gradually falls behind the picture.
- **The first start is slow** — a minute or two to load the models into memory.

## Requirements

- **Windows 10 build 20348 or later, or Windows 11** — required by the
  process-specific loopback API.
- An x64 CPU and about 2 GB of free disk space for the runtime and the models.
- A graphics card is optional. NVIDIA gives the speed-up; AMD and Intel go
  through Vulkan.

The app changes only the selected process session's volume and restores it when
the pipeline stops or the app closes.

## The screens

### Live

This is where the audio source is chosen and the dubbing is started.
**Process** captures the selected game only; **All audio** captures the whole
default output except LoreDub itself. When the language of the game is known in
advance, turn **Detect language** off and name it: that removes an extra
recognition pass and one common mistake — a wrong guess made from a short first
phrase.

Every line is shown as the original, the translation, and the time it took to
travel the whole pipeline.

### Models

At the top sits speech recognition: one Whisper model for every language. The
builds are drawn as a chart: a bar's height is its download to scale, its
place along the bottom is how well it recognizes speech. A light bar with a
download cloud is not downloaded yet, a light one with a tick is, a dark one
with an orange edge is in use, and one being downloaded fills from the bottom
with its percentage in a ring. The buttons are always on the bar: download,
pause or resume and cancel, or delete for a downloaded model (after a
confirmation). A click on a downloaded bar picks it.

Below it are the dubbing languages, a tile each. A tile holds the pair: the
translator and the voice, each with its size and a tick once on disk. The pair
is downloaded, picked and deleted as one, with one ring for both while it
downloads. A click on a tile picks the language. At the bottom is the voice
converter's tile: one for every language, needed only by Original voice mode.
The tiles speak the Whisper bars' language: light is missing, ticked is
downloaded, dark with an orange edge is in use, a fill from the bottom is
downloading.

Any download can be paused, resumed and cancelled. Closing the application
mid-download is not a loss: the next attempt fetches the rest rather than
starting over.

### Settings

<p align="center">
  <img src="docs/screenshots/settings-en.png" width="900" alt="The Settings screen">
</p>

Interface language (Russian or English, applied immediately), the text source
(audio or subtitles), how far the original is turned down while dubbing, the
speech rate and the voice. Below those: CPU threads, the compute device, the
Python path and a proxy for downloads.

### Graphics card

<p align="center">
  <img src="docs/screenshots/compute-en.png" width="900" alt="The Compute device section">
</p>

The default is **Automatic**: the app finds the graphics card itself and
assigns a device to every stage. Below the preset is a table of stage by
device. The cell a stage runs on is dark with an orange edge; a light one can be
picked with a click; one with a cloud needs a package first, and a click
fetches it; a faded one is ruled out by the machine or the stage, with the
reason in its tooltip. Below that, the graphics card packages are tiles like the
models: download, pause, resume, cancel, delete. The heavy GPU runtimes are not in the
installer and are fetched on demand, so nobody who leaves the card off pays for
them. Measurements and details are under
[Compute device](#compute-device).

## How it works

```text
Game process (WASAPI process loopback, 16 kHz mono)
  -> energy VAD and phrase endpointing
  -> whisper.cpp --translate
  -> Helsinki-NLP Marian English -> chosen language
  -> Silero TTS in that language
  -> (Original voice mode) OpenVoice V2: the line's timbre over the Silero voice
  -> default Windows output
```

Audio capture can target a selected process tree or the complete default output.
Complete-output mode excludes the LoreDub process tree so synthesized speech
does not feed back into recognition. Alternatively, OCR mode captures a
player-chosen area of the selected game window, recognizes stable
English subtitle text with Windows OCR, and sends it directly to Marian and
Silero without running Whisper.

Models are downloaded by the application on demand and kept in the Windows
application-support directory.

## Interface

The LoreDub interface uses the same industrial language as its icon: warm
off-white equipment panels, graphite signal areas, restrained typography, and
a single orange accent for active controls. The layout adapts from a persistent
desktop sidebar to compact bottom navigation. The complete rationale and UI
tokens are documented in [docs/UI_DESIGN.md](docs/UI_DESIGN.md).

The interface language — Russian or English — is switched in **Settings**
and applies immediately, without a restart. Every label lives in
`lib/l10n/*.arb`, with the Russian file as the source.

## Dubbing voice

Settings carries an **Automatic / Choose / Original voice** switch. Automatic is the default:
the worker measures the pitch of the captured phrase and answers in a man's
or a woman's voice to match, line by line. The decision is sticky — an
unclear phrase keeps the previous voice, so noise does not change the
character mid-conversation. The voice in use is shown in the same section
while the pipeline runs.

The genders are measured rather than looked up: every voice was synthesized
and its median fundamental taken.

| Language | Male | Female | Automatic |
| --- | --- | --- | --- |
| Russian | aidar, eugene | baya, kseniya, xenia | yes |
| German | bernd_ungerer, friedrich, karlsson | eva_k, hokuspokus | yes |
| French | fr_0…fr_3, fr_5 | fr_4 | yes |
| Spanish | es_0, es_1, es_2 | — | no |
| Ukrainian | mykyta | — | no |

Automatic is unavailable where a package ships voices of one gender only, and
in subtitle mode, which never hears the original. Both say so in Settings and
fall back to the chosen voice.

**Original voice** goes further: the timbre is taken from the same captured
line and moved onto the Silero voice by the
[OpenVoice V2](https://github.com/myshell-ai/OpenVoice) tone colour converter
(MIT licence). The base voice is still picked by pitch, which leaves the
converter less to move; where the package cannot follow the speaker's gender,
the chosen voice is the base. A line with no voice in it — music, noise, a short
grunt — keeps the previous timbre. It needs the converter (131 MB) from the
Original voice section of the **Models** screen, and on the processor it adds
about 0.9 s a line. Subtitle mode cannot offer it for the same reason:
there is no original to hear.

Where the converter runs is chosen apart from translation, in the
**OpenVoice** row of the Device section, which appears with the mode. On an
NVIDIA card a line is re-voiced in about 0.1 s; that takes the same CUDA torch
runtime translation uses, and either row can download it.

The **Remember the characters' voices** switch (off by default) keeps a voice
bank. Every new character's voice fingerprint is saved, and when they speak
again the line is voiced with that fingerprint instead of the timbre of the
current phrase, so a character's voice does not drift from line to line and
stays the same after a restart. Fingerprints are not averaged: a character is
represented by their first clear line longer than a second and a half. A line
counts as the same character when the fingerprints meet at a cosine of 0.80
or more: on the OpenVoice demo voices two noisy lines of one person met at
0.86 and above, two different people at 0.79 at most. Every game has a bank of
its own (`voice_bank/<game>.json` in the application data); the switch shows
how many voices are kept, and **Clear** deletes them all once confirmed.

The **Let different characters overlap** switch (on by default) lets another
character's new line start at once while the previous one is still sounding,
so the dubbing falls behind less in a quick exchange. A character never talks
over themselves: their next line waits for the last to end. No more than two
voices sound together; a third waits. Who is speaking is told apart
differently by mode:

- Original voice: by the voice fingerprint (the kept character with the voice
  bank on, this session's fingerprints without it);
- Automatic: by the Silero voice, which separates men from women and nothing
  more;
- Choose and subtitle mode have one voice, so lines play strictly in turn.

A short line nobody could be matched to plays on its own.

## Translator

English text is translated by a Helsinki-NLP/Marian model. Russian uses
`opus-mt-tc-big-en-zle` from the Tatoeba Challenge (461 MB), which replaced
the 2020 `opus-mt-en-ru` (287 MB). It serves the East Slavic languages
together, so the target is named by a token in front of the text (`>>rus<<`).

The gain is not in fine wording but in the gross failures it removes. Over
25 lines of game dialogue:

| Original | Old | New |
| --- | --- | --- |
| The well ran dry three summers ago. | **Лаборатория** высохла три лета назад. | Три года назад колодец высох. |
| Keep your voice down, the guards are near. | **Не двигайся**, охранники рядом. | Не кричи, стража рядом. |
| You there! Halt and state your business. | **Стой и стой, стой!** | Остановись и скажи… |
| That armour will not stop an arrow. | **Эти брони не остановят** стрелу. | Эта броня не остановит стрелу. |

Not everything improves: "hills" became "горы", and it addresses the player
formally more often. It also costs more — about 400 ms a line against 260 ms.

Now and then it leaves a proper noun in Latin script, which Silero cannot
read. The worker catches that and translates again with the line lower-cased;
over those 25 lines it happened once, and the retry fixed it.

## Recognition model

The Models screen picks the Whisper build. `base` is the default because it is
the only one that suits a plain processor; the rest are worth it once
recognition runs on a card.

Measured on an RTX 3080 Ti over three 3 s English lines, warm. "Errors" counts
how many of the three came out wrong:

| Model | Size | Time | Errors |
| --- | --- | --- | --- |
| base | 141 MB | ~680 ms | 2 |
| small | 465 MB | ~1120 ms | 1 |
| medium-q5_0 | 514 MB | ~1320 ms | 0 |
| **large-v3-turbo-q5_0** | 547 MB | **~1130 ms** | **0** |

`large-v3-turbo` wins on both counts — medium's accuracy at small's speed,
from having 4 decoder layers instead of 32. But **it must not be asked to
translate speech**: OpenAI fine-tuned it with the translation data left out.
LoreDub therefore does not pass it `-tr` and asks it to transcribe, which only
suits an original already in English. The catalogue marks this, and if the
original language is set by hand to something other than English the interface
says so.

The first run of a new model on CUDA costs a few seconds while the driver
builds its kernel cache for those shapes. It is a one-off.

## Compute device

The default is **Automatic**: the app enumerates adapters through DXGI, checks
for `nvcuda.dll` and `vulkan-1.dll`, and assigns a device to each stage itself.
Any stage can then be moved by hand — an option the machine cannot run is shown
but disabled, with a tooltip saying why.

| Stage | CUDA | Vulkan | CPU |
| --- | --- | --- | --- |
| Whisper | yes, downloaded (436 MB) | yes, if built (see below) | always |
| Translation (Marian) | yes, downloaded (~2.5 GB) | no: torch has no Vulkan backend | always |
| Speech (Silero) | no | no | always |

The heavy GPU runtimes are **not in the installer**. They are fetched on demand
by the same machinery as the models, with progress, SHA-256 verification and
proxy support, so nobody who leaves the GPU off pays for them. A download
interrupted by closing the application resumes with a range request instead of
starting over, and removing a runtime asks first — hundreds of megabytes are
not worth a stray click. They land in
`<app support>/runtime/<id>/` and a button in the same section gives them back.

Any download can be paused, resumed and cancelled. A pause keeps what has
arrived and resuming fetches the rest with a range request; a cancel removes
the partial file. The stop is checked between chunks, so it lands within a
hundred kilobytes or two rather than at the end of the file. When data stops
arriving but the connection stays open, the download reconnects by itself after
a minute and carries on from where it was; after five such attempts it stops
with a plain error and keeps what arrived.

CUDA torch is a single 2.5 GB wheel. LoreDub fetches it with the same
downloader as the models — pausable, resumable and checked against its
SHA-256 — and pip then only installs that file and fetches a few small
dependencies. It used to be left to pip entirely: no progress, no resuming,
and on a connection that stopped delivering it could hang for hours. The wheel
is built for the bundled Python 3.11; with another interpreter set in Settings
pip resolves torch the old way, and only a cancel is offered there — it kills
the process and clears the directory, so a half-installed runtime cannot pass
for a finished one.

Speech stays on the processor deliberately: Silero utterances are short, and
moving them to the card costs more than the work itself.

Measured on an RTX 3080 Ti with a 5.6 s English line and `ggml-base`.
Recognition:

| Whisper | Time |
| --- | --- |
| CPU, 4 threads | ~2320 ms |
| CPU, 12 threads | ~1275 ms |
| CPU, 24 threads | ~1110 ms |
| CUDA | ~745 ms |

Translation and speech add ~470 ms on the processor and barely move with the
thread count (461 ms at 12 threads against 476 ms at 4), so once recognition
is on the card the **CPU threads** setting stops mattering much.

End to end, from the close of a phrase to its dubbed audio, a real run lands
near 1.2 s on CUDA against 2.7 s on the CPU at four threads. The first phrase
of a session costs extra while the language is detected, and the first run
after switching to CUDA took 23 s while the driver built its kernel cache — a
one-off.

AMD and Intel cards are left with Vulkan, but no official Windows build of
`whisper.cpp` with Vulkan exists, so `scripts/prepare_windows_runtime.ps1`
compiles one (`-DGGML_VULKAN=ON`). That needs the Vulkan SDK and CMake on the
build machine; without them the step is skipped with a warning, and
`-RequireVulkan` turns that skip into an error, which is what a release build
wants. The resulting binary is small and ships in the installer, so there is
nothing to download for it.

## Subtitle mode

When the lines of a game are written rather than spoken, LoreDub reads them
off the screen. Windows OCR recognizes the English text inside a chosen area of
the game window, and each line goes straight to the translator and the speech
synthesizer — this mode needs neither Whisper nor a recognition model.

### Setting it up

**1. Turn the mode on.** **Settings → Text source → Subtitles + OCR.**

**2. Frame the place where the game prints its subtitles.** A **Subtitle area**
card appears below the switch, with a scaled-down screen shaped like your
monitor that stands for the game window. Drag across it to draw a frame, then
move it and pull its corners and sides. From the keyboard, the arrows move the
frame and Shift with the arrows resizes it. **Reset** puts back the default,
the bottom 45% of the window.

<p align="center">
  <img src="docs/screenshots/ocr-settings-en.png" width="900" alt="Settings: the Subtitles + OCR mode and a frame on the scaled-down monitor">
</p>

The frame is kept as a share of the game window rather than in pixels, so it
survives a change of resolution. The line under the screen gives its size and
offsets in percent.

**3. Start dubbing.** On **Live**, choose the game process, press **Start
dubbing** and switch to the game. Text is read only while the game is the
foreground window, so neither LoreDub nor a browser over the game can pass for
subtitles.

<p align="center">
  <img src="docs/screenshots/ocr-game.png" width="900" alt="The game window: only the text inside the frame is read, the objective in the corner stays outside it">
</p>

<p align="center"><i>What OCR sees: everything outside the frame is dimmed. The line at the bottom is translated, the objective in the corner is not.</i></p>

<p align="center">
  <img src="docs/screenshots/ocr-live-en.png" width="900" alt="Live: lines read off the screen, translated and voiced">
</p>

<p align="center"><i>A real run over the test window: each line read off the screen, translated and voiced in under a second — there is no speech recognition to wait for. None of the objectives from the corner reached the transcript.</i></p>

### Framing tips

- **The tighter the frame, the cleaner the dubbing.** Health bars, names over
  heads and control prompts inside the frame are read just as readily as a
  line of dialogue, and get voiced with it.
- **Leave room in height.** A long line often wraps onto a second row, and a
  frame one row high cuts it off.
- **A line has to stay put.** The screen is scanned about every two thirds of
  a second, and a line is sent on once two scans in a row agree, so subtitles
  typed out letter by letter are not voiced in pieces. The same line is not
  repeated while it stays on screen.

### Limits

- Only English text is read, and Windows needs its English OCR pack. Without
  it LoreDub says so. The pack comes with the English language under
  **Settings → Time & language → Language & region**, or from an elevated
  PowerShell:
  `Add-WindowsCapability -Online -Name "Language.OCR~~~en-US~0.0.1.0"`.
- Windowed and borderless games work. Exclusive fullscreen and a minimized
  window cannot be read through the lightweight GDI capture — switch the game
  to borderless windowed.
- The voice does not follow the character in this mode: there is no original
  to hear, so no pitch to measure. The lines are read in the voice chosen by
  hand.

### Trying it without a game

The mode can be tried without a game. `scripts/ocr_test_window.ps1` opens a
game-like window with English dialogue changing at the bottom centre and the
current objective in the top-left corner. Pick `LoreDubOcrTest.exe` in the
process list, frame the dialogue, start dubbing and switch to that window: only
the dialogue should reach the transcript. `scripts/check_ocr_region.ps1` does the
same without models or the interface, running the native capture with a few
frames and checking what Windows OCR read.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/ocr_test_window.ps1
powershell -ExecutionPolicy Bypass -File scripts/check_ocr_region.ps1
```

## Checking for updates

The bottom left of the sidebar carries a button with the installed version.
The check runs by itself at startup, spinning on the button while it does;
pressing it checks again.

When the repository has published something newer, Windows shows a
notification and the version gives way to a line reading "Current version
v0.8.0 → v0.9.0" with an orange mark. A click downloads the new version's
setup — with a bar and a percentage, resuming after a dropped connection,
checked against its size and SHA-256 when GitHub publishes one. Once it is
down, the line turns into "Updated" and a **Restart** button. That stops the
dubbing and closes LoreDub; the setup installs the new version over the old
one with no window — for the current user, with no administrator prompt — and
the application opens again. The install itself takes the few seconds between
closing and opening: a running application cannot overwrite its own files.
What happened is written to `updates/update.log` in the application data.

A copy run from the build folder is not updated by the setup, which would
install a second copy elsewhere, so there the line opens the release page.

Only the three version numbers are compared: the build after `+` is ignored,
because `0.2.1+3` and `0.2.1+4` are the same release to anyone reading a
changelog. A tag that does not read as a version, `nightly` say, is passed
over in silence. A failed check is its own state rather than "up to date":
an unreachable GitHub says nothing about the dubbing, so it does not raise
the error banner.

The notification only appears for a copy installed from the setup. Windows
shows a desktop application's toast only when a Start Menu shortcut carries
the same `AppUserModelID`, which the installer now sets. Run from the build
folder, the notification goes straight to the notification centre while the
button and the arrow behave as usual.

## How the pipeline is built

The audio mode is wired end to end. The setup contains pinned `whisper.cpp`
v1.8.2 binaries and an embedded Python CPU runtime for Marian and Silero.

Recognition, translation and synthesis are serialized so a small CPU is never
asked to run two inferences at once, while playback happens beside them:
voicing a reply takes as long as the reply itself, and waiting for it would put
every later phrase further behind the game. No phrase is dropped.

The delay depends heavily on the CPU and on **CPU threads** in Settings, which
defaults to half of the logical processors. Recognition dominates it, so the
language whisper.cpp detects is reused for the rest of the session instead of
being detected again for every phrase, which costs a full extra encoder pass.

## Planned

- **Headroom for dense dialogue.** Nothing is dropped, so speech arriving
  faster than the pipeline can dub it still accumulates a delay — currently
  around one phrase per 1.5 s on a 12-core CPU. Unmeasured options, in the
  order worth trying: raise **CPU threads** to 16–24 and measure what the game
  loses; then benchmark a quantized Whisper model (`ggml-base-q5_1.bin`)
  against `base` for both recognition speed and translation quality. Recognition
  is the dominant cost, so that is where the remaining time is. Keeping the
  bundled `whisper-server.exe` resident would save only the ~160 ms model load
  and is not worth the complexity.
- **Subtitle overlay.** `AppSettings.showOverlay` is persisted but nothing
  reads it yet; the intent is to draw the translated lines over the game.

## Development on Windows

Install Flutter stable, Visual Studio 2022 with **Desktop development with
C++**, and Inno Setup 6. Then run:

```powershell
flutter pub get
dart run tool/ffigen.dart
flutter analyze --fatal-infos
flutter test
powershell -ExecutionPolicy Bypass -File scripts/build_setup.ps1
```

The last command downloads and caches the pinned runtimes, builds the Flutter
app, and creates:

```text
dist/LoreDub-<version>-windows-x64-setup.exe
```

For a development run without an installer, build Flutter first and place the
runtime beside `lore_dub.exe`:

```powershell
flutter build windows --debug
powershell -ExecutionPolicy Bypass -File scripts/prepare_windows_runtime.ps1 `
  -Destination build/windows/x64/runner/Debug/runtime
flutter run -d windows
```

After updating an existing checkout across an executable rename, older Flutter
or CMake versions may retain the previous target in their local build cache.
The project repairs that value automatically. If configuration still reports
`No target` for an old application name, regenerate the local artifacts once:

```powershell
flutter clean
flutter pub get
flutter run -d windows
```

## Model integrity

Downloads are streamed to temporary files and moved atomically only after size
and, when supplied upstream, digest validation. Every artifact in the catalogue
has a pinned byte size, measured against the host. The Whisper weights and the
Russian Marian weights additionally carry pinned SHA-256 values; the weights of
the other languages are size-checked only.

An optional HTTP or SOCKS5 proxy for model downloads can be configured in
**Settings → Model downloads**. Both `host:port` and authenticated
`http://user:password@host:port` / `socks5://user:password@host:port` formats
are accepted. The setting affects only model downloads; recognition,
translation, and speech synthesis remain local. Settings also shows the model
storage directory and can open it in Explorer.

The setup-bundled `runtime/python/python.exe` is selected by default. Settings
also accepts a custom absolute path, and **Find automatically** scans the
bundled runtime, the runtime of an installed LoreDub, `PATH` and the standard
Windows installation directories for an interpreter that actually has `torch`
and `transformers`. The Microsoft Store `python.exe` execution alias is skipped:
it only advertises the Store and cannot run the worker.

## GitLab CI

`verify` runs formatting, analysis, unit/widget tests, and the portable native
build. `windows-setup` requires a GitLab shell runner tagged `windows` with
Flutter, Visual Studio, and Inno Setup 6. It caches runtimes under
`%LOCALAPPDATA%` and publishes the setup executable for tags and the default
branch.

## GitHub releases

Every tag named `v<major>.<minor>.<patch>` starts the Windows release workflow.
The tag version must match the version in `pubspec.yaml` (without its `+build`
suffix), and `CHANGELOG.md` must contain a non-empty section with the same
version. The changelog is kept in Russian, since it becomes the GitHub release
notes. For example:

```markdown
## [0.2.0] - 2026-09-10

- Добавлено ...
- Исправлено ...
```

To publish that version, commit both files, tag that commit, and push:

```bash
git add pubspec.yaml CHANGELOG.md
git commit -m "chore: prepare 0.2.0 release"
git tag v0.2.0
git push origin main v0.2.0
```

GitHub Actions validates the three versions, builds the Windows installer, and
publishes `LoreDub-0.2.0-windows-x64-setup.exe` with the matching changelog
section at the [LoreDub releases page](https://github.com/Hecatoncheir/LoreDub/releases).

## Source layout

```text
assets/runtime/              persistent Marian/Silero worker
assets/branding/             LoreDub icon and brand assets
assets/fonts/                bundled Nunito, Nunito Sans and JetBrains Mono (OFL)
docs/screenshots/            screen captures used by the READMEs
lib/l10n/                    interface translations, Russian is the source
lib/src/data/services/       orchestration, native bridge, model storage
lib/src/ui/                  Windows dashboard and model manager
native/                      process-loopback capture, VAD, volume, playback
hook/                        Dart Native Assets compiler hook
tool/ffigen.dart             generated FFI bindings
installer/                   Inno Setup definition
scripts/                     Windows runtime and packaging scripts
```

Project-owned code is MIT licensed. Downloaded runtime and model artifacts keep
their upstream licenses and are not stored in this repository.

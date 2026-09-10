<p align="center">
  <img src="assets/branding/loredub-icon.png" width="180" alt="LoreDub application icon">
</p>

<h1 align="center">LoreDub</h1>

<p align="center">
  <a href="https://github.com/Hecatoncheir/LoreDub/actions/workflows/windows.yml"><img src="https://github.com/Hecatoncheir/LoreDub/actions/workflows/windows.yml/badge.svg" alt="Windows build"></a>
  <a href="https://github.com/Hecatoncheir/LoreDub/actions/workflows/release.yml"><img src="https://github.com/Hecatoncheir/LoreDub/actions/workflows/release.yml/badge.svg" alt="Windows release"></a>
  <a href="https://github.com/Hecatoncheir/LoreDub/releases/latest"><img src="https://img.shields.io/github/v/release/Hecatoncheir/LoreDub" alt="Latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Hecatoncheir/LoreDub" alt="MIT license"></a>
</p>

<p align="center"><a href="README.md">Русский</a> · <b>English</b></p>

LoreDub is a Windows-first, fully local game voice-over companion. It captures
only the selected game's process tree, turns speech into English, translates it
into the language you pick, and speaks the result over the current default audio
output while keeping the original game session quiet.

```text
Game process (WASAPI process loopback, 16 kHz mono)
  -> energy VAD and phrase endpointing
  -> whisper.cpp base --translate
  -> Helsinki-NLP Marian English -> chosen language
  -> Silero TTS in that language
  -> default Windows output
```

Audio capture can target a selected process tree or the complete default output.
Complete-output mode excludes the LoreDub process tree so synthesized speech
does not feed back into recognition. Alternatively, OCR mode captures a configurable lower portion of the selected
game window, recognizes stable English subtitle text with Windows OCR, and
sends it directly to Marian and Silero without running Whisper.

Everything runs on the user's CPU. Audio and text do not leave the machine.
Models are downloaded by the Dart application on demand and kept in the Windows
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

Settings carries an **Automatic / Choose** switch. Automatic is the default:
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

## Compute device

The default is **Automatic**: the app enumerates adapters through DXGI, checks
for `nvcuda.dll` and `vulkan-1.dll`, and assigns a device to each stage itself.
Any stage can then be moved by hand — an option the machine cannot run is shown
but disabled, with a tooltip saying why.

| Stage | CUDA | Vulkan | CPU |
| --- | --- | --- | --- |
| Whisper | yes, downloaded (436 MB) | yes, if built (see below) | always |
| Translation (Marian) | yes, downloaded (~2.7 GB) | no: torch has no Vulkan backend | always |
| Speech (Silero) | no | no | always |

The heavy GPU runtimes are **not in the installer**. They are fetched on demand
by the same machinery as the models, with progress, SHA-256 verification and
proxy support, so nobody who leaves the GPU off pays for them. A download
interrupted by closing the application resumes with a range request instead of
starting over, and removing a runtime asks first — hundreds of megabytes are
not worth a stray click. They land in
`<app support>/runtime/<id>/` and a button in the same section gives them back.

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

## Windows release status

The audio mode is wired end to end. The setup contains pinned `whisper.cpp`
v1.8.2 binaries and an embedded Python CPU runtime for Marian and Silero.

**Models** groups the downloads the way the pipeline uses them. Whisper stands
alone at the top: it turns speech in any language into English, and recognition
needs nothing else. Below it sit the translators and the voices, one of each per
language — Russian, German, Spanish, French and Ukrainian. Picking a language in
either section selects both halves of the pair, because a translation read by a
voice for another language would be gibberish, and only that pair has to be
downloaded. At the first launch install Whisper and one pair, choose a running
game process, and press **Start dubbing**.

The first pipeline start can take one or two minutes while Marian and Silero are
loaded. Recognition, translation and synthesis are then serialized so a small
CPU is never asked to run two inferences at once, while playback happens beside
them: voicing a reply takes as long as the reply itself, and waiting for it
would put every later phrase further behind the game. No phrase is dropped.

The delay depends heavily on the CPU and on **CPU threads** in Settings, which
defaults to half of the logical processors. Recognition dominates it, so the
language whisper.cpp detects is reused for the rest of the session instead of
being detected again for every phrase, which costs a full extra encoder pass.
When the language of the game is known in advance, turning **Detect language**
off and picking it from **Original language** skips that pass entirely and rules
out a wrong guess made from a short or noisy first phrase.
On a 12-core CPU with twelve threads a phrase is voiced about 1.5 s after it
ends; `base` is chosen as the quality/speed compromise.

The **Subtitles + OCR** mode works with visible windowed or borderless games.
Choose how much of the lower game window to scan in Settings. English OCR must
be installed in Windows; the app reports a direct error when that language pack
is missing. Scanning runs only while the selected game is the foreground window,
which prevents other windows from being mistaken for subtitles. Exclusive-fullscreen or minimized windows cannot be read through
the lightweight GDI capture path.

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

## Requirements

- Windows 10 build 20348 or later, or Windows 11. This is required by the
  process-specific loopback API.
- x64 CPU and about 2 GB of free disk space for the application runtime and
  downloaded models.
- An active audio session from the selected process. Start the game and let it
  play sound before refreshing the process list.

The app changes only the selected process session's volume and restores it when
the pipeline stops or the app closes. TTS comes from the LoreDub process, so
it cannot feed back into the selected game's capture.

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
version. For example:

```markdown
## [0.2.0] - 2026-09-10

- Added ...
- Fixed ...
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

# LoreDub

LoreDub is a Windows-first, fully local game voice-over companion. It captures
only the selected game's process tree, turns speech into English, translates it
to Russian, and speaks the result over the current default audio output while
keeping the original game session quiet.

```text
Game process (WASAPI process loopback, 16 kHz mono)
  -> energy VAD and phrase endpointing
  -> whisper.cpp base --translate
  -> Helsinki-NLP Marian English -> Russian
  -> Silero TTS v5.3 Russian
  -> default Windows output
```

Alternatively, OCR mode captures a configurable lower portion of the selected
game window, recognizes stable English subtitle text with Windows OCR, and
sends it directly to Marian and Silero without running Whisper.

Everything runs on the user's CPU. Audio and text do not leave the machine.
Models are downloaded by the Dart application on demand and kept in the Windows
application-support directory.

## Windows release status

The audio mode is wired end to end. The setup contains pinned `whisper.cpp`
v1.8.2 binaries and an embedded Python CPU runtime for Marian and Silero. At the
first launch, install all three model cards, choose a running game process, and
press **Start**.

The first pipeline start can take one or two minutes while Marian and Silero are
loaded. Subsequent phrases are processed sequentially so a small CPU is not
overloaded. Expected delay depends heavily on CPU and phrase length; `base` is
chosen as the quality/speed compromise.

The **Subtitles + OCR** mode works with visible windowed or borderless games.
Choose how much of the lower game window to scan in Settings. English OCR must
be installed in Windows; the app reports a direct error when that language pack
is missing. Scanning runs only while the selected game is the foreground window,
which prevents other windows from being mistaken for subtitles. Exclusive-fullscreen or minimized windows cannot be read through
the lightweight GDI capture path. Only Russian output is packaged at the moment.

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
runtime beside `game_lingo.exe`:

```powershell
flutter build windows --debug
powershell -ExecutionPolicy Bypass -File scripts/prepare_windows_runtime.ps1 `
  -Destination build/windows/x64/runner/Debug/runtime
flutter run -d windows
```

## Model integrity

Downloads are streamed to temporary files and moved atomically only after size
and, when supplied upstream, digest validation. The Whisper base and large
Marian weights have pinned SHA-256 values. Smaller Marian metadata files are
size-checked. The Silero host does not currently publish a digest or stable
content length, so Dart validates that download by successful completion.

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

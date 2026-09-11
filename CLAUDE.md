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

## Architecture

Four processes cooperate; changing the pipeline usually means touching more
than one of them.

1. **Flutter/Dart UI** — `lib/src/ui/dashboard/`. State lives in four cubits
   (`cubits/`): `ShellCubit` (section, first load, the failure banner, the
   update check), `SettingsCubit`, `DownloadsCubit` (models, GPU runtimes,
   what the machine can run) and `PipelineCubit` (status, transcript,
   processes). `DashboardCubits` wires them together and runs `initialize()`;
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
   per-process volume, WAV playback. Everything crosses the boundary as UTF-8
   JSON. The native side hand-rolls its JSON parsing/escaping (`JsonString`,
   `EscapeJson`) — keep config keys flat and string/number valued.
   `NativeEngineService` polls `ld_poll_event_json` every 80 ms and turns
   `{"type":"audioSegment"|"ocrText"|"state"|"error"}` events into a Dart
   stream. Native capture runs on its own threads (`ProcessLoopbackCapture`
   WASAPI process loopback + energy VAD writing 16 kHz WAV chunks;
   `OcrCapture` GDI + Windows OCR over `AppSettings.ocrRegion`, a frame the
   player draws in Settings and stored as fractions of the foreground game
   window's client area).
3. **whisper.cpp** — invoked per audio segment as a one-shot subprocess with
   `-tr` (translate to English). Which build runs is the compute setting:
   bundled `runtime/whisper/` (CPU) or `runtime/whisper-vulkan/`, or the
   downloaded `<app support>/runtime/whisper-cuda/`. OCR mode skips it.
4. **Python inference worker** — `assets/runtime/inference_worker.py`, bundled
   as a Flutter asset, extracted to the app-support `work/` directory and run
   by `LocalInferenceService` as a persistent subprocess speaking
   line-delimited JSON (`{"id","text"}` in, `{"id","translated","wave"}` or
   `{"id","error"}` out, plus one `{"type":"ready"}` handshake). It keeps
   Marian and Silero loaded, which is why the first start takes minutes.
   Startup uses the bundled embedded Python (`runtime/python/python.exe`,
   see `resolvePythonExecutable`).

Segments are processed strictly sequentially — `NativeEngineService._processing`
is a chained `Future` — so a small CPU is never asked to run two inferences at
once. Preserve that when adding stages.

The update check (`UpdateService`, `UpdateRepository`) reads the repository's
latest release at startup and compares only the three version numbers. The
Windows toast needs a Start Menu shortcut carrying the same `AppUserModelID`
the plugin registers (`com.loredub.LoreDub`) — the installer sets it in
`installer/lore_dub.iss`. Without that shortcut Windows accepts the toast and
files it in the notification centre without ever showing it, so a build run
straight from `build/` shows no banner.

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
It shares the download loop with the model store through
`artifact_downloader.dart`, which streams to a `.part` file and resumes it
with a range request rather than refetching; a 200 to a ranged request, a 416,
or a part that fails verification all fall back to starting over. A
`DownloadControl` passed in lets the interface pause (keep the part) or
cancel (delete it); the loop checks it between chunks and returns a
`DownloadOutcome` rather than throwing, because a stop the user asked for is
not a failure. The pip runtime has no half-way point, so it only honours a
cancel, by killing the process and clearing the target directory.

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
- Comments, identifiers, docs, and commit messages are English. `README.md` is
  Russian and is the primary one; `README.en.md` follows it.
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

## Releasing

`pubspec.yaml` version, the `v<major>.<minor>.<patch>` git tag, and a matching
`## [x.y.z] - date` section in `CHANGELOG.md` must agree, or
`tool/prepare_release.dart` fails the GitHub release workflow.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

LoreDub is a Windows-only Flutter desktop app that dubs game audio in real time,
fully on the local CPU: capture -> ASR/translation -> TTS -> default output.
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
powershell -ExecutionPolicy Bypass -File scripts/prepare_windows_runtime.ps1 -Destination build/windows/x64/runner/Debug/runtime
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

1. **Flutter/Dart UI** — `lib/src/ui/dashboard/`. `DashboardViewModel` is a
   plain `ChangeNotifier` holding all app state (section, settings, processes,
   model install states, transcript, `PipelineStatus`); `DashboardView` is a
   single large widget file. There is no DI framework: `LoreDubBootstrap`
   (`lib/src/app.dart`) constructs services -> repositories -> view model.
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
   `OcrCapture` GDI + Windows OCR over the lower part of the foreground game
   window).
3. **whisper.cpp** — invoked per audio segment as a one-shot
   `runtime/whisper/whisper-cli.exe` subprocess with `-tr` (translate to
   English). OCR mode skips this stage entirely.
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
  Service-layer exception messages are still **Russian** literals.
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

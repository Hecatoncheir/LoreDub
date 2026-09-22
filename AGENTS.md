# Repository Guidelines

## Project Structure & Module Organization

LoreDub is a Windows-only Flutter desktop application. Dart code lives in `lib/`: domain
models and pure decisions are under `lib/src/domain`, persistence and platform services under
`lib/src/data`, and widgets plus their Blocs and Cubits under `lib/src/ui`. Native Windows capture, playback,
OCR, and hotkey code is in `native/`, compiled through `hook/build.dart`. Python inference
workers ship from `assets/runtime/`; fonts, icons, and branding are also under `assets/`.
Tests mirror production paths in `test/`, with shared helpers in `test/support`. Build and
release tooling is in `tool/`, `scripts/`, and `installer/`; user-facing screenshots and design
notes live in `docs/`.

## Build, Test, and Development Commands

```powershell
flutter pub get
dart run tool/ffigen.dart          # regenerate lib/src/native/*.g.dart (committed) after a C ABI change
flutter gen-l10n                   # after editing lib/l10n/*.arb (output is committed)
dart format --output=none --set-exit-if-changed lib test tool hook
flutter analyze --fatal-infos      # CI is --fatal-infos; infos must be zero
flutter test --coverage            # the whole suite; a path and --plain-name "substring" for one test
dart run tool/coverage.dart        # the data layer's and the domain's coverage does not fall
flutter test test/screenshots.dart --update-goldens   # redraw docs/screenshots/ (no _test suffix)
flutter test test/graph_bench.dart # what a frame of the graph screen costs (no _test suffix)
python -m unittest discover -s test/runtime       # the worker's text half, any Python
ruff check assets/runtime test/runtime scripts    # ruff.toml; CI pins the version
powershell -ExecutionPolicy Bypass -File tool/native_tests.ps1    # native/tests/*_test.cpp
powershell -ExecutionPolicy Bypass -File tool/native_analyze.ps1  # native/*.cpp under /analyze /WX
dart pub global run bloc_tools:bloc lint lib      # the `bloc:` rules in analysis_options.yaml
```

The two ratchets CI runs, after `dart pub global activate cognitive_complexity 0.2.4` and
`dart_code_linter 4.4.0`:

- `dart pub global run cognitive_complexity --git-diff=origin/main --fail-on-increase
  --fail-threshold 15 lib`: a new function above 15, or one already above it growing, fails.
- `dart pub global run dart_code_linter:metrics analyze lib --reporter=json
  --json-path=build/metrics.json --no-fatal-warnings`, then `dart run tool/ratchet.dart --metrics
  build/metrics.json`, counts private widgets, methods returning widgets, nested conditionals and
  palette/`TextStyle(` uses outside the theme against `tool/ratchet_baseline.json`. A count may
  only fall; when it does, rerun with `--update` and commit the baseline. `tool/coverage.dart`
  works the same way over `tool/coverage_baseline.json`, the other way up.

Run the app locally -- the Python/whisper runtime must sit beside the executable, otherwise the
pipeline fails at start:

```powershell
flutter build windows --debug
powershell -ExecutionPolicy Bypass -File scripts/prepare_windows_runtime.ps1 -Destination build/windows/x64/runner/Debug/runtime -SkipVulkan
flutter run -d windows
```

`powershell -ExecutionPolicy Bypass -File scripts/build_setup.ps1` builds the installer
(`dist/LoreDub-<version>-windows-x64-setup.exe`) and re-runs ffigen, analysis and the tests
itself. Every program it and `prepare_windows_runtime.ps1` start goes through `Invoke-Native`
(`scripts/invoke_native.ps1`): PowerShell does not stop on a non-zero exit code by itself, so an
unwrapped call lets a failed step through to a published installer.

Subtitle mode can be tried without a game: `scripts/ocr_test_window.ps1` opens
`LoreDubOcrTest.exe`, a window drawing dialogue and a quest objective the way a game does, and
`scripts/check_ocr_region.ps1` drives the native OCR capture against it and compares what
Windows OCR read with what each frame covers. Build the native library first, and leave the
test window in front.

## Coding Style & Naming Conventions

Use Dart's standard two-space indentation and the configured 100-column formatter width
(`trailing_commas: preserve`).
Keep analyzer infos at zero; strict casts, inference, and raw types are enabled. Name files in
`snake_case.dart`, types in `UpperCamelCase`, and members in `lowerCamelCase`. Keep domain logic
pure where possible and preserve the service → repository → Bloc dependency direction: a
Bloc reads repositories, never another Bloc. A Cubit is kept only where the state is a setter
and nothing more (the banner, the section, whether the first load is back). What more than
one screen needs lives in a repository that owns it and publishes it synchronously, and that
repository is the only writer — a Bloc that also emitted what it wrote put its own stale echo
back. C/C++
ABI additions must remain small, UTF-8/JSON-based, and be followed by binding regeneration.

## Testing Guidelines

Use `flutter_test`; name files `*_test.dart` and describe behavior in readable `test(...)`
sentences. Place tests beside the matching source hierarchy. Cover new domain decisions,
service edge cases, repository publishing order, and Bloc transitions (`blocTest` against a
fake repository; a screen's widgets over a `MockBloc`, checking the events it sends). UI changes that affect subscription scope must
keep `test/src/ui/dashboard/rebuild_scope_test.dart` passing. A fake implements what it
stands for on `Fake` and never extends it; shared fakes live in `test/support/fakes/`.

## Commit & Pull Request Guidelines

Follow the existing Conventional Commit style: `feat: ...`, `fix: ...`, or `chore: ...` with a
concise imperative summary. Keep generated bindings and related native changes in the same
commit. Pull requests should explain user-visible behavior, list verification commands, link
relevant issues, and include screenshots for UI changes. Ensure formatting, analysis, tests,
and the Windows build pass before review.

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

- `flutter pub get` installs Dart and Flutter dependencies.
- `dart run tool/ffigen.dart` regenerates the committed bindings in `lib/src/native/` after C
  ABI changes.
- `flutter gen-l10n` regenerates the committed `lib/l10n/app_localizations*.dart` after an ARB
  file changes.
- `dart format --output=none --set-exit-if-changed lib test tool hook` checks formatting.
- `flutter analyze --fatal-infos` runs the same strict analysis enforced by CI.
- `flutter test` runs the complete test suite; add a path and `--plain-name "substring"` for a
  focused test.
- `flutter test test/screenshots.dart --update-goldens` redraws `docs/screenshots/` from the
  real widgets; it carries no `_test` suffix, so the suite above leaves it alone.
- `dart pub global run cognitive_complexity --git-diff=origin/main --fail-on-increase
  --fail-threshold 15 lib` is the complexity ratchet CI runs (after `dart pub global activate
  cognitive_complexity 0.2.4`): a new function above 15, or one already above it growing, fails.
- `dart pub global run dart_code_linter:metrics analyze lib --reporter=json
  --json-path=build/metrics.json --no-fatal-warnings`, then `dart run tool/ratchet.dart --metrics
  build/metrics.json`, counts private widgets, methods returning widgets, nested conditionals and
  palette/`TextStyle(` uses outside the theme against `tool/ratchet_baseline.json`. A count may
  only fall; when it does, rerun with `--update` and commit the baseline.
- `flutter build windows --debug` builds a local Windows executable. Prepare its runtime with
  `scripts/prepare_windows_runtime.ps1` before exercising inference.
- `powershell -ExecutionPolicy Bypass -File scripts/build_setup.ps1` validates and produces the
  release installer in `dist/`. Every program it and `prepare_windows_runtime.ps1` start goes
  through `Invoke-Native` (`scripts/invoke_native.ps1`): PowerShell does not stop on a non-zero
  exit code by itself, so an unwrapped call lets a failed step through to a published installer.

## Coding Style & Naming Conventions

Use Dart's standard two-space indentation and the configured 100-column formatter width.
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

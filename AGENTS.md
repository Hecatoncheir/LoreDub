# Repository Guidelines

## Project Structure & Module Organization

LoreDub is a Windows-only Flutter desktop application. Dart code lives in `lib/`: domain
models and pure decisions are under `lib/src/domain`, persistence and platform services under
`lib/src/data`, and widgets plus Cubits under `lib/src/ui`. Native Windows capture, playback,
OCR, and hotkey code is in `native/`, compiled through `hook/build.dart`. Python inference
workers ship from `assets/runtime/`; fonts, icons, and branding are also under `assets/`.
Tests mirror production paths in `test/`, with shared helpers in `test/support`. Build and
release tooling is in `tool/`, `scripts/`, and `installer/`; user-facing screenshots and design
notes live in `docs/`.

## Build, Test, and Development Commands

- `flutter pub get` installs Dart and Flutter dependencies.
- `dart run tool/ffigen.dart` regenerates the committed bindings in `lib/src/native/` after C
  ABI changes.
- `dart format --output=none --set-exit-if-changed lib test tool hook` checks formatting.
- `flutter analyze --fatal-infos` runs the same strict analysis enforced by CI.
- `flutter test` runs the complete test suite; add a path and `--plain-name "substring"` for a
  focused test.
- `flutter build windows --debug` builds a local Windows executable. Prepare its runtime with
  `scripts/prepare_windows_runtime.ps1` before exercising inference.
- `powershell -ExecutionPolicy Bypass -File scripts/build_setup.ps1` validates and produces the
  release installer in `dist/`.

## Coding Style & Naming Conventions

Use Dart's standard two-space indentation and the configured 100-column formatter width.
Keep analyzer infos at zero; strict casts, inference, and raw types are enabled. Name files in
`snake_case.dart`, types in `UpperCamelCase`, and members in `lowerCamelCase`. Keep domain logic
pure where possible and preserve the service → repository → Cubit dependency direction. C/C++
ABI additions must remain small, UTF-8/JSON-based, and be followed by binding regeneration.

## Testing Guidelines

Use `flutter_test`; name files `*_test.dart` and describe behavior in readable `test(...)`
sentences. Place tests beside the matching source hierarchy. Cover new domain decisions,
service edge cases, and Cubit state transitions. UI changes that affect subscription scope must
keep `test/src/ui/dashboard/rebuild_scope_test.dart` passing.

## Commit & Pull Request Guidelines

Follow the existing Conventional Commit style: `feat: ...`, `fix: ...`, or `chore: ...` with a
concise imperative summary. Keep generated bindings and related native changes in the same
commit. Pull requests should explain user-visible behavior, list verification commands, link
relevant issues, and include screenshots for UI changes. Ensure formatting, analysis, tests,
and the Windows build pass before review.

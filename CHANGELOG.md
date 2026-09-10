# Changelog

All notable changes to LoreDub are documented in this file.

## [Unreleased]

- Added optional HTTP and SOCKS5 proxy settings for model downloads, including authentication.
- Added a searchable process picker and full default-output capture that excludes LoreDub playback.
- Added configurable bundled/PATH Python runtime selection.
- Added the model storage path and an Explorer shortcut to Settings.
- Fixed the speech speed setting, which was stored and shown but never applied.
- Fixed translated phrases being dropped when the Python worker wrote its replies in the
  Windows ANSI code page instead of UTF-8.
- Added runtime preflight: a missing whisper.cpp binary or Whisper model is reported before
  the pipeline ducks the game instead of silently swallowing every captured phrase.
- Added detection of the Microsoft Store `python.exe` execution alias, which cannot run the
  worker, and reported worker crashes with the interpreter output instead of an exit code.

## [0.2.1] - 2026-09-10

- Fixed local Windows builds after the executable rename by migrating stale CMake target caches.
- Fixed intermittent UTF-8 decoding failures while the Windows process list changes during initialization.
- Aligned the refresh and start buttons vertically with the game process selector.

## [0.2.0] - 2026-09-10

- Completed the project-wide LoreDub rename across the app, native bridge, and build outputs.
- Added the LoreDub icon to the Windows executable, installer, application shell, and README.
- Redesigned the dashboard around a tactile industrial audio-module visual system.
- Added responsive desktop navigation and compact-window widget coverage.

## [0.1.0] - 2026-09-09

- Added Windows process-specific audio capture with quiet original audio.
- Added local speech recognition and English translation using whisper.cpp base.
- Added English-to-Russian Marian translation and Russian Silero speech synthesis.
- Added subtitle recognition using Windows OCR with configurable capture area.
- Added on-demand model downloads and a Windows Inno Setup installer.

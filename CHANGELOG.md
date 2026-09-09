# Changelog

All notable changes to LoreDub are documented in this file.

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

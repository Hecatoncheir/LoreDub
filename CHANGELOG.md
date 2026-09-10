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
- Added automatic Python detection in Settings: LoreDub now scans the bundled runtime, an
  installed LoreDub runtime, `PATH` and the standard installation directories, and picks the
  first interpreter that actually provides torch and transformers.
- Fixed stopping the pipeline reporting an error for the phrase that was still being
  processed at that moment.
- Fixed the dubbing falling further behind the game the longer it ran. Playback no longer
  blocks recognition, the language whisper.cpp detects is reused instead of being detected
  again for every phrase, and the default thread count now follows the CPU. On a 12-core
  machine a phrase is voiced after about 1.5 s instead of 4.7 s, and no phrase is dropped.
- Fixed a failed phrase leaving the session stuck: the pipeline kept running but could
  neither be started nor stopped.
- Added a source-language selector next to the start button, with a toggle for automatic
  detection. Naming the language in advance skips whisper's detection pass and rules out a
  wrong guess made on the first phrase.
- Added startup progress on the start button: the worker now reports each stage it is
  loading, so the first start no longer looks frozen for ten seconds.
- Added the detected language beside the toggle, so automatic detection is no longer
  a silent decision.
- Fixed synthesized audio being left in the work directory when the pipeline was stopped
  while a phrase was still being voiced.
- Added German, Spanish, French and Ukrainian alongside Russian, and grouped the models
  screen into recognition, translation and voices. Whisper stays on its own at the top:
  recognition needs nothing else. Choosing a language selects its translator and voice
  together, and only that pair has to be downloaded.
- Replaced Segoe UI with bundled Nunito, Nunito Sans and JetBrains Mono, the last one
  reserved for module labels and measured times.

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

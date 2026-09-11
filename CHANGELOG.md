# Changelog

All notable changes to LoreDub are documented in this file.

## [Unreleased]

## [0.3.0] - 2026-09-11

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
- Added an English interface alongside Russian. Every label moved into `lib/l10n/*.arb`,
  and Settings carries the switch; Russian stays the default and the source of the
  wording. `README.md` is now Russian, with `README.en.md` beside it.
- Replaced the Live section icon with the Material Symbols `audio_capture` mark. It has no
  glyph in the Material Icons font Flutter bundles, so it ships as the upstream SVG and is
  tinted at draw time like any other icon.
- Added a compute device section to Settings. "Automatic" probes the graphics adapters and
  assigns CUDA, Vulkan or the CPU to recognition, translation and speech; each stage can then
  be moved by hand, and a backend the machine cannot run is shown disabled with the reason.
  The heavy GPU runtimes stay out of the installer and are downloaded on demand.
- Downloads now resume. A `.part` left behind when the application closed is continued with
  a range request instead of being fetched again, which matters most for the 436 MB GPU
  runtime; a server that refuses the range, or a part that fails verification, still starts
  over.
- Removing a downloaded GPU runtime now asks for confirmation before giving the disk space
  back, since the button sits where the download button used to be.
- Every download can now be paused, resumed and cancelled, models and GPU runtimes alike.
  A pause keeps the partial file so resuming continues with a range request; a cancel takes
  it with it. The stop is checked between chunks rather than at the end of the file. CUDA
  torch is the exception: pip has no half-way point, so only a cancel is offered there, and
  it kills the process and clears the directory.
- Added an update check. The sidebar shows the installed version, checks at startup and on
  request, and offers an arrow to the release page plus a Windows notification when the
  repository has published something newer. The installer now stamps its shortcuts with an
  AppUserModelID, without which Windows files a desktop application's toast away unshown.
- Made the Whisper model a choice. The Models screen now lists base, small, medium-q5_0 and
  large-v3-turbo-q5_0 and remembers which one recognition uses; the smallest stays the
  default. large-v3-turbo is marked as unable to translate speech — OpenAI fine-tuned it
  without translation data — so it is asked to transcribe and only suits an English original.
- Replaced the Russian translator with the Tatoeba-Challenge `opus-mt-tc-big-en-zle`. It
  clears up the worst failures of the 2020 model, at 479 MB against 307 MB and about 150 ms
  more per line. The identifier changes, so the old translator has to be downloaded again.
  A proper noun it leaves in Latin script, which Silero cannot read, is caught and
  translated again with the line lower-cased.
- Added a dubbing voice setting. "Automatic" measures the pitch of each captured phrase and
  answers in a man's or a woman's voice to match; a voice can also be picked by hand. The
  genders in the catalogue were measured, which turned up that every Spanish voice is a
  man's, so that language cannot follow a speaker and says so.
- Added a clear button to the Live transcript. It is disabled while there is nothing to
  clear, and clearing does not touch a running session: new phrases keep arriving.
- Added error messages in the interface language. Services now raise an error code instead
  of a Russian sentence, so a failure raised while the app was in one language is rewritten
  the moment the other one is picked.
- Fixed the game process picker being squeezed to a stub, with its label broken mid-word,
  in windows too narrow for the one-row layout; below that width the controls now stack.
- Made the dashboard redraw only what changed. A download used to redraw the whole screen
  for every chunk it received; it now reports whole percent, and neither a progress tick
  nor a recognized phrase redraws the screens that do not show it.
- Rewrote both READMEs around getting started, with screenshots of a real session.

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

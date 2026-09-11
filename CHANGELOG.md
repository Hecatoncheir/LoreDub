# Changelog

All notable changes to LoreDub are documented in this file.

## [Unreleased]

- Redrew the translators, voices and the voice converter in the Whisper chart's style. A
  dubbing language is now one tile holding its translator and voice, downloaded, picked and
  deleted together, with one progress ring for the pair; the converter is a tile of its own.
  Every tile keeps its buttons in sight and grows slightly under the pointer, and any
  downloaded model can now be deleted.
- Fixed Cancel on a paused download doing nothing: the paused part files are now deleted.

## [0.8.0] - 2026-09-11

- Redrew the Whisper models on the Models screen as a chart of size against quality: each build
  is a bar as tall as its download, light when missing, ticked once downloaded, dark with an
  orange edge when in use, and filling from the bottom while it downloads. Every bar keeps its
  buttons in sight — download, pause or resume and cancel, or delete — and grows slightly under
  the pointer; a click on a downloaded bar picks it. Large-v3-turbo is marked as not
  translating. Narrow windows keep the list of cards.
- Added deleting a downloaded Whisper model, after a confirmation. The model in use cannot be
  deleted while dubbing runs.

## [0.7.0] - 2026-09-11

- Lines of different characters can now overlap: a new line starts at once while another
  character is still speaking, instead of waiting for them to finish. A character never talks
  over themselves, and no more than two voices sound together. Characters are told apart by
  the voice fingerprint in Original voice mode and by the Silero voice (man or woman) in
  Automatic mode; "Let different characters overlap" in the voice settings turns it off.
  Playback moved from PlaySound, which could hold one sound at a time, to waveOut.

## [0.6.0] - 2026-09-11

- Added a device choice for the Original voice: an OpenVoice row under Device puts the converter
  on the CPU or on an NVIDIA card independently of translation. On the card a line is
  re-voiced in about 0.1 s instead of about a second; it uses the same CUDA torch runtime as
  translation.
- Added a voice bank for the Original voice, off by default. With "Remember the characters'
  voices" on, every new character's voice fingerprint is kept per game, and their later lines —
  restarts included — are voiced with it instead of the timbre of each line. Fingerprints are
  matched, not averaged. Settings show how many voices are kept, and Clear deletes them.

## [0.5.0] - 2026-09-11

- Fixed the CUDA runtime download hanging with the bar stuck at 5%: pip fetched the 2.5 GB
  wheel with no progress, no resume, and no end on a connection that stopped delivering.
  LoreDub now downloads the wheel itself — pausable, resumable, checked against its SHA-256 —
  and pip only installs the local file. Any download that stops receiving data reconnects by
  itself after a minute and carries on from where it was.
- Added an Original voice mode beside Automatic and Choose: every line is re-voiced in the
  timbre of the phrase it answers by the OpenVoice V2 tone colour converter (MIT, 131 MB,
  downloaded from the new Original voice section of the Models screen), laid over the Silero
  voice picked by pitch. A line with no voice in it keeps the previous timbre. Subtitle mode
  cannot offer it, having no audio.
- Fixed translation running on a single processor thread: loading the Silero voice reset
  torch's thread count, so the CPU threads setting only held until the voice was loaded.

## [0.4.2] - 2026-09-11

- Fixed the GPU runtime download failing without a word: the button went back to "Download" and
  nothing said why. The reason now shows under the stage, with the last lines pip printed, and a
  failed CUDA torch install no longer leaves a half-written directory that could pass for a
  finished one.

## [0.4.1] - 2026-09-11

- Fixed a double-click on Start cancelling the start it had just begun, which left the Live
  screen on "Stopped" with nothing to explain it. A second press within 800 ms of Start is now
  taken for the rest of the double-click; a later press still cancels.
- Fixed native capture errors, such as a missing English OCR pack, clearing the error banner
  instead of raising it.
- Fixed the Live screen describing the audio path in subtitle mode: the note under the process
  picker and the empty transcript now say the lines are read off the game window by Windows OCR
  instead of captured as audio and recognized by Whisper.

## [0.4.0] - 2026-09-11

- Added a drawn subtitle area: in subtitle mode Settings show a scaled-down screen shaped like
  the monitor, on which the player drags, moves and resizes the frame OCR reads, instead of
  choosing only the height of a full-width band at the bottom of the window.
- Added `scripts/ocr_test_window.ps1`, a game-like window for trying subtitle mode without a
  game, and `scripts/check_ocr_region.ps1`, which runs the native capture against it with
  several frames and checks that each reads only the text inside it.

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

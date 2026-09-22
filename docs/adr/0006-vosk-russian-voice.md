# 0006. Russian is voiced by Vosk-TTS

Status: accepted. Code: `assets/runtime/vosk_voice.py`, `model_catalog.dart`.

## Decision

The Russian voice is `vosk-ru-0.9`, Vosk-TTS under Apache 2.0, which a
dubbing free to earn money with can carry -- the Silero it replaced is
CC BY-NC -- and which measured a tie with it under the converter. Its memory
reuse is turned off, and what its phoneme map lacks is dropped.

## Why, measured

As it stood in `CLAUDE.md` when the decision was taken, numbers and
all; measure again before changing what it holds up.

The voice is `vosk-ru-0.9`, Vosk-TTS under Apache 2.0, measured a tie with the
Silero it replaced under the converter (0.743 against 0.745 from a game line).
The pipeline names a speech package by its first file, `model.onnx`, and
`assets/runtime/vosk_voice.py` reads the package from the directory it sits
in, answering the calls the worker was written against for Silero
(`speakers`, `apply_tts`). It turns onnxruntime's memory reuse off: planning
it over the graph's 29 000 nodes is what opening it cost, 100 s against 3,
with a line read in the same time either way. What its phoneme map lacks --
digits, Latin -- is dropped rather than raised on. The files are this
project's release `voices-vosk-v1` in `Hecatoncheir/LoreDub-models`, renamed flat from the authors' archive
with a NOTICE, as the translators are.

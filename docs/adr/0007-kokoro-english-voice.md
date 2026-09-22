# 0007. English is voiced by Kokoro, fp32

Status: accepted. Code: `assets/runtime/kokoro_voice.py`, `assets/runtime/onnx_speech.py`, `load_voice`.

## Decision

English is `kokoro-en-1.0`, Kokoro-82M under Apache 2.0, in its fp32 export.
The package says which wrapper reads it (`voices.bin` beside the model), one
function says where either voice runs, and the catalogue lists only the
voices whose gender was measured.

## Why, measured

As it stood in `CLAUDE.md` when the decision was taken, numbers and
all; measure again before changing what it holds up.

English is `kokoro-en-1.0`, Kokoro-82M under Apache 2.0, read by
`assets/runtime/kokoro_voice.py` — the same two calls (`speakers`,
`apply_tts`) the worker was written against. Which of the two wrappers reads
a speech package is the package's own answer rather than a flag from the
application: `load_voice` (`inference_worker.py`) takes Kokoro where
`voices.bin` sits beside the model and Vosk otherwise, both packages being
named by the same first file, `model.onnx`. What must not differ between them
is where a voice runs, so `onnx_speech.providers_for` is the one place that
answers it. Measured against Vosk on the same machine over fifteen game
lines: a tie per second of speech on the processor (RTF 0.29 to 0.31,
though an English reading of a line is longer than its Russian one), 353 MB
against 894, open in 1.0 s against 17.2, and 174 ms a line on the card with
**no per-shape penalty at all** — the opposite of Vosk, where a line of a new
length costs about 1.9 s. Under the converter it lands closer to the
character than Vosk does (0.805 and 0.865 against two targets to Vosk's 0.763
and 0.839) and its floor is far higher (0.717 against 0.548, Vosk's short
lines being what fall apart). The fp32 export is what ships: fp16 reads
correctly on the processor and goes silent on the card for `af_heart` in four
lines of five, and the quantized builds that load at all are four times
slower than fp32 (RTF 1.4, slower than real time). The catalogue lists 23 of
its 28 English voices with **measured** genders — `af_alloy` is a man at 147
Hz and `am_santa` a woman at 182, so a name says nothing — and leaves out the
five that fall between the worker's thresholds.

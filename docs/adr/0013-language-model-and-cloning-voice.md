# 0013. A language model translates and a cloning voice reads, where a card can carry them

Status: accepted. Code: `assets/runtime/llm_translation.py`, `assets/runtime/qwen_voice.py`,
`assets/runtime/qwen_fast.py`, `ModelPackage.languageModel`/`clonesVoice` and
`ModelSelection._preferred` in `lib/src/domain/`, `ComputeStage.languageModel` in
`lib/src/domain/compute_device.dart`.

## Decision

The catalogue lists TranslateGemma 4B (Q4_K_M, under llama.cpp) before Marian and
Qwen3-TTS 1.7B Base before Vosk and Kokoro, and a machine with either on disk
dubs through it; the older packages stay for the processor. The language
model is handed what whisper heard in the game's own language, with the last
lines of the scene, the glossary entries the line touches and the speaker's
gender in front of it. The cloning voice reads in the timbre of a clip -- the
phrase the game just spoke, a card's own recording, or one of seven clips
shipped beside the worker for the fixed voices -- and the OpenVoice converter
is left to tell the characters apart. On the card the voice runs through CUDA
graphs over static caches rather than transformers' generation loop.

## Why, measured

All on an RTX 3080 Ti under Windows 11, torch 2.7.1+cu126, llama.cpp b11118.

**Translation.** TranslateGemma answers a line in 0.08 to 0.15 s on the CUDA
build, against Marian's 0.04 to 0.09 on the processor. Over eight game lines
Marian put every first person in the masculine ("Я пошел домой и запер
дверь") where the model, told the line was a woman's, wrote "Я вернулась
домой и заперла дверь"; "Fire in the hole!" came back from Marian as "Огонь в
дыру!", and the glossary phrase stood above both. The wording of the
speaker's gender matters and is measured: "The line is spoken by a woman: use
the feminine forms where Russian requires them for the speaker" put three of
five first-person lines in the feminine; "The speaker is a woman." put one; a
longer wording that also asked for the person addressed to be left alone put
none. What no wording fixes is the person addressed following on occasion
("Ты говорила"), and "I was born here", which every wording left in the
masculine. The memory of translations is keyed by the speaker's gender for
the same reason: the same line in a woman's mouth and in a man's are two lines.

The model's own chat template refuses a plain message -- it expects one item
with `source_lang_code` and `target_lang_code` -- so llama.cpp is started with
`--no-jinja --chat-template gemma`, whose built-in Gemma template wraps the
same turns around the instruction TranslateGemma was tuned on.

**The voice.** Read through the `qwen_tts` package as published, a 3.4 s line
took 9.6 s (RTF 2.8): 55 steps of the 1.7B talker at 70 ms each and 810 steps
of the code predictor at 11.8, of which arithmetic is a fraction -- Windows'
driver charges for every one of the few hundred kernels a step launches.
Replacing transformers' `generate` around the predictor's fifteen steps with a
plain loop changed nothing (300 ms a frame). Captured into CUDA graphs over
static caches, a talker step replays in 10.9 ms against 49.2 eager and a
predictor step in 0.99 against 8.8, and a line reads in 0.37 to 0.41 of its
length: 1.4 s for 3.4 s of speech. Greedy, the graph loop and the model's own
are each deterministic and agree frame for frame over the first 88 of 134
frames, then drift on bf16 arithmetic, the durations staying within 0.1 s. The
graphs cost 12 s at load and the whole voice 5.1 GB of the card. Cloning from
the clip with its transcript and from the speaker's embedding alone run at
the same speed; the transcript is passed where whisper wrote the clip down as
heard. One line in about a hundred lost its ending and ran the fifty-second
limit out, so a line may take no more than 24 frames plus two per character,
a Russian line reading at about a frame a character.

**The choice of package.** The first package of a kind that serves the
language and is on disk is the one used, and the first listed where none is:
a machine with only Marian and Vosk keeps dubbing with them and is not asked
to download 7 GB before it can start, and one with the newer packages uses
them without a setting to switch.

## What was tried and is not taken up

- Qwen3-TTS through transformers as published: three times slower than the
  speech it makes, for the launch cost above.
- `torch.compile` for the same end: its `cudagraphs` backend works on this
  torch, but the model declares no static-cache support, so the graphs are
  captured by hand over `StaticCache`.
- Chatterbox and CosyVoice as the voice: measured earlier at five seconds a
  line and not measured again here; Seed-VC as a converter is GPL-3.0;
  Vevo2 is trained without Russian.
- Tower+ as the translator: CC-BY-NC-SA. HY-MT: its licence excludes the EU,
  the UK and South Korea.

## Measured later: the card is shared

On 2026-09-23 the whole stack on the 12 GB card -- the worker 7.1 GB (the
voice in bf16, its tokenizer, the converter), llama-server 2.9 GB -- met a
desktop holding 6.5 GB of it (dwm under a live wallpaper 3.7 GB, the NVIDIA
overlay 2.8 GB). Nothing was refused: WDDM paged the model through system
memory, the first line took 207 s in the speech tokenizer's encode (0.07 s
on a free card), llama answered in 0.5 s instead of 0.13, and a benchmark
started beside it hung the display driver. So the language model is loaded
last and offered the card only for what is then free past 3.5 GB kept for
whisper and the voice's own growth under the lines (`layers_for_card`); otherwise llama.cpp keeps it on the processor,
where a line takes a few seconds.

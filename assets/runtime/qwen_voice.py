# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT
#
# Qwen3-TTS is Apache 2.0 (the Qwen team, Alibaba Cloud), and so is the
# `qwen_tts` package that reads it. The synthesis is the model's; only the
# loading, the reference clips and the caching are ours.

"""The voice that clones.

Qwen3-TTS reads ten languages, Russian and English among them, in the
timbre of a few seconds of whoever it is handed: the phrase the game just
spoke, a card the player recorded, or one of the clips shipped beside the
worker, which stand in for the fixed voices the other packages list. It
answers the calls the worker was written against -- `speakers` and
`apply_tts(...)` giving a torch tensor at the rate asked for -- plus the
reference the line is to be read in, which the Vosk and Kokoro wrappers
have no use for.

The timbre goes in with the text rather than being laid over the result:
where the OpenVoice converter moved a fixed voice's reading toward the
speaker, the model reads as the speaker from the first phoneme, so the
converter is left to what it alone does -- telling the characters apart.
"""

import collections
import pathlib
import types

import numpy as np
import torch

from llm_translation import language_name
from tone_converter import resample

# What the model answers at.
_RATE = 24000

# The longest line, in codec frames at 12 Hz: fifty seconds. Past it the
# model is looping rather than reading.
_MAX_NEW_TOKENS = 600

# How many frames a line may take for its length: measured, a Russian line
# reads at about a frame a character, so twice that and a margin is room
# for a slow reading, and a line that runs past it has lost its ending
# rather than found more to say -- one in a hundred did, and ran the fifty
# seconds out.
_FRAMES_PER_CHARACTER = 2
_FRAMES_MARGIN = 24

# How many reference clips are kept encoded: a scene's speakers and the
# fixed voices, so a character is not re-encoded for every line.
_PROMPTS_KEPT = 32

# A line is cut where the voice starts and stops, with this much kept on
# either side, as the other voices' are.
_MARGIN_SECONDS = 0.05
_SILENCE_BELOW_PEAK = 0.02

# The name the model knows every language by that it does not know by
# name: it picks the language up from the text itself.
_ANY_LANGUAGE = "Auto"


def _directory(path):
    path = pathlib.Path(path)
    return path.parent if path.is_file() else path


def _trimmed(samples, rate):
    """[samples] without the silence at either end, a small margin kept."""
    if samples.size == 0:
        return samples
    loud = np.flatnonzero(np.abs(samples) > _SILENCE_BELOW_PEAK * np.abs(samples).max())
    if loud.size == 0:
        return samples
    margin = int(_MARGIN_SECONDS * rate)
    return samples[max(0, loud[0] - margin) : min(samples.size, loud[-1] + margin + 1)]


def voice_language(code):
    """The name the model is told the language by, or its own guess."""
    if not code:
        return _ANY_LANGUAGE
    named = language_name(code)
    return _ANY_LANGUAGE if named == code else named


def _pick(logits, do_sample, top_k, top_p, temperature):
    """One token from [logits], sampled the way the model's generation
    settings ask: the hottest [top_k], within [top_p] of the mass, at
    [temperature]; or the likeliest, without sampling."""
    if not do_sample:
        return logits.argmax(dim=-1)
    logits = logits.float() / max(float(temperature or 1.0), 1e-5)
    if top_k and 0 < top_k < logits.shape[-1]:
        lowest_kept = torch.topk(logits, top_k).values[..., -1, None]
        logits = logits.masked_fill(logits < lowest_kept, float("-inf"))
    if top_p is not None and top_p < 1.0:
        ordered, order = torch.sort(logits, descending=True)
        probabilities = torch.softmax(ordered, dim=-1)
        # Everything past the mass asked for goes, the hottest token kept.
        past = probabilities.cumsum(dim=-1) - probabilities > top_p
        ordered = ordered.masked_fill(past, float("-inf"))
        logits = torch.full_like(logits, float("-inf")).scatter(-1, order, ordered)
    return torch.multinomial(torch.softmax(logits, dim=-1), 1).squeeze(-1)


def quick_code_predictor(predictor):
    """The code predictor's `generate`, without the generation machinery.

    Every frame of speech is sixteen codebook entries, the first from the
    talker and the fifteen after it from this small model, one at a time,
    and the model's own code asks transformers' `generate` for the fifteen:
    measured, that machinery cost 235 ms a frame on an RTX 3080 Ti -- three
    times slower than the speech it makes. The same fifteen steps in a plain
    loop over the model, with its cache, are what `generate` would have run
    anyway, with the same heads, embeddings and sampling in the same order.
    """
    embedders = predictor.model.get_input_embeddings()

    def generate(inputs_embeds, max_new_tokens, do_sample=True, top_p=1.0, top_k=50, temperature=1.0, **_):
        from transformers import DynamicCache

        past = DynamicCache()
        embeds = predictor.small_to_mtp_projection(inputs_embeds)
        tokens = []
        for step in range(int(max_new_tokens)):
            answered = predictor.model(inputs_embeds=embeds, past_key_values=past, use_cache=True)
            past = answered.past_key_values
            logits = predictor.lm_head[step](answered.last_hidden_state[:, -1])
            token = _pick(logits, do_sample, top_k, top_p, temperature)
            tokens.append(token)
            if step + 1 < max_new_tokens:
                embeds = predictor.small_to_mtp_projection(embedders[step](token.unsqueeze(1)))
        return types.SimpleNamespace(sequences=torch.stack(tokens, dim=1))

    return generate


class QwenVoice:
    """Qwen3-TTS over torch, cloning from a reference clip per line."""

    # The worker hands a voice that clones the clip a line is to be read
    # in; the others are read in their own fixed voices.
    clones = True

    def __init__(self, directory, threads=4, device="cpu", language=None, references=None):
        from qwen_tts import Qwen3TTSModel

        directory = _directory(directory)
        torch.set_num_threads(max(1, threads))
        # A card torch cannot see leaves the voice on the processor rather
        # than the session failed, the way the converter falls back.
        use_cuda = device == "cuda" and torch.cuda.is_available()
        self.device = "cuda" if use_cuda else "cpu"
        self._model = Qwen3TTSModel.from_pretrained(
            str(directory),
            device_map=self.device,
            # The card reads it in half precision; the processor has none.
            dtype=torch.bfloat16 if use_cuda else torch.float32,
            attn_implementation="sdpa",
        )
        self.language = voice_language(language)
        self._references = dict(references or {})
        self.speakers = sorted(self._references)
        self._prompts = collections.OrderedDict()
        # On the card the whole loop runs through CUDA graphs (`qwen_fast`):
        # measured, a line is read in 0.4 of its length rather than 2.8. On
        # the processor the model's own loop stays, with the fifteen
        # sub-codebook steps of every frame run plainly rather than through
        # transformers' generation loop each time.
        from qwen_fast import fast_generation

        if not fast_generation(self._model.model):
            talker = getattr(self._model.model, "talker", None)
            predictor = getattr(talker, "code_predictor", None)
            if predictor is not None and hasattr(predictor, "lm_head"):
                predictor.generate = quick_code_predictor(predictor)

    def _prompt(self, reference, transcript):
        """The reference clip encoded once, kept for the lines after."""
        key = str(reference)
        kept = self._prompts.get(key)
        if kept is not None:
            self._prompts.move_to_end(key)
            return kept
        # With its transcript the clip conditions the reading itself; without
        # one only the speaker's embedding is taken from it.
        prompt = self._model.create_voice_clone_prompt(
            ref_audio=key,
            ref_text=transcript or None,
            x_vector_only_mode=not transcript,
        )
        self._prompts[key] = prompt
        while len(self._prompts) > _PROMPTS_KEPT:
            self._prompts.popitem(last=False)
        return prompt

    def reference_of(self, speaker):
        """The clip and transcript a fixed voice is read from; the package's
        first voice for a name it does not ship."""
        if speaker in self._references:
            return self._references[speaker]
        if self.speakers:
            return self._references[self.speakers[0]]
        raise RuntimeError("the voice has no reference clip to read in")

    def apply_tts(
        self,
        text,
        speaker,
        sample_rate,
        reference=None,
        reference_text="",
        put_accent=True,
        put_yo=True,
    ):
        """[text] read in [speaker]'s clip, or in [reference] where a line
        brings its own, as a torch tensor at [sample_rate]."""
        if reference is None:
            reference, reference_text = self.reference_of(speaker)
        prompt = self._prompt(reference, reference_text)
        with torch.inference_mode():
            waves, rate = self._model.generate_voice_clone(
                text=text,
                language=self.language,
                voice_clone_prompt=prompt,
                non_streaming_mode=True,
                max_new_tokens=min(_MAX_NEW_TOKENS, _FRAMES_MARGIN + _FRAMES_PER_CHARACTER * len(text)),
            )
        samples = np.asarray(waves[0], dtype=np.float32).ravel()
        if self.device == "cuda":
            # What a line allocated goes back to the card rather than into
            # torch's cache, on a card the language model and whisper share
            # with the voice: measured, the voice is 5.7 GB live and 6.3 GB
            # reserved at load, and grew half a gigabyte more under lines.
            torch.cuda.empty_cache()
        return torch.from_numpy(resample(_trimmed(samples, rate), rate, sample_rate))

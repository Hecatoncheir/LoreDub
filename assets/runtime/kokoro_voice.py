# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT
#
# Kokoro-82M is Apache 2.0 (hexgrad), and so is the ONNX export this reads.
# The synthesis is the model's; only the loading and the phonemes are ours.

"""The English voice the worker reads with.

The package is laid out flat, the way the catalogue publishes it:
`model.onnx`, `voices.bin` and a NOTICE. It answers the calls the worker was
written against -- `speakers` and `apply_tts(...)` giving a torch tensor at
the rate asked for -- which is the shape `vosk_voice.py` answers in Russian.

Measured against that Russian voice on the same machine, over fifteen game
lines: a line takes 522 ms on twelve processor threads against Vosk's 427,
which is a tie per second of speech (RTF 0.29 against 0.31; the English
reading of a line is simply longer). What differs is everything around it --
the model opens in 1.0 s against 17.2, weighs 353 MB against 894, and the
card is a real bargain rather than Vosk's poor one: 174 ms a line, RTF 0.10,
with no per-shape penalty at all (the longest line measured, 4.3 s of
speech, took 312 ms). Under the voice converter it lands closer to the
character it aims at than Vosk does -- 0.805 and 0.865 against two targets,
where Vosk gives 0.763 and 0.839, and its floor is far higher: 0.717 against
0.548, Vosk's short lines being what fall apart.

The fp32 export is the one that ships. The fp16 half of it reads correctly
on the processor and goes silent on the card for `af_heart` in four lines of
five -- the graph answers with an empty waveform -- while other voices are
fine; a voice-dependent overflow is not something to hand a player.
"""

import json
import pathlib
import re

import numpy as np
import torch

from english_g2p import EnglishG2P
from onnx_speech import providers_for
from tone_converter import resample

# What the export was trained and exported at.
_RATE = 24000

# The window of tokens the graph takes. A longer line is read in several,
# cut between words.
_MAX_TOKENS = 510

# A line is cut where the voice starts and stops, with this much kept on
# either side, as the Russian voice's is.
_MARGIN_SECONDS = 0.05
_SILENCE_BELOW_PEAK = 0.02

# The file carries 54 voices for nine languages. This is the English
# package, so it answers with the English ones -- American and British, the
# names the catalogue lists and measured the gender of.
_ENGLISH_VOICES = ("af_", "am_", "bf_", "bm_")

_SPACES = re.compile(r"(\s+)")


def _directory(path):
    """The package's directory. The pipeline names a speech package by its
    first file, which for Kokoro is `model.onnx`; the directory itself does
    as well."""
    path = pathlib.Path(path)
    return path.parent if path.name == "model.onnx" else path


def _session(path, threads, providers):
    import onnxruntime

    options = onnxruntime.SessionOptions()
    options.intra_op_num_threads = max(1, threads)
    # Memory reuse is left on, unlike the Russian voice's: this graph opens
    # in about a second with it, and turning it off saves nothing to pay
    # for.
    options.log_severity_level = 3
    return onnxruntime.InferenceSession(str(path), sess_options=options, providers=providers)


def _vocab(session):
    """The phoneme table the model was exported with, read out of the model
    itself rather than carried beside it -- one file fewer to keep in step."""
    carried = session.get_modelmeta().custom_metadata_map.get("kokoro_config")
    if not carried:
        raise RuntimeError("the speech model carries no phoneme table")
    return dict(json.loads(carried)["vocab"])


def _trimmed(samples, rate):
    # A line of nothing this voice can read -- Cyrillic handed to it, or a
    # line of punctuation -- comes back empty, and an empty line is trimmed
    # to itself rather than raising on a peak that is not there.
    if not samples.size:
        return samples
    loud = np.flatnonzero(np.abs(samples) > _SILENCE_BELOW_PEAK * (np.abs(samples).max() or 1.0))
    if not loud.size:
        return samples
    margin = int(rate * _MARGIN_SECONDS)
    return samples[max(0, loud[0] - margin) : loud[-1] + margin + 1]


def _windows(phonemes, vocab, limit):
    """[phonemes] cut into windows the graph will take, between words where
    that is possible -- a cut inside a word is heard as a stumble."""
    windows = []
    window = ""
    counted = 0
    for piece in _SPACES.split(phonemes):
        if not piece:
            continue
        length = sum(1 for symbol in piece if symbol in vocab)
        if counted + length > limit and window.strip():
            windows.append(window.strip())
            window = ""
            counted = 0
        # A single word longer than the window is rare enough to cut hard.
        while length > limit:
            windows.append(piece[:limit])
            piece = piece[limit:]
            length -= limit
        window += piece
        counted += length
    if window.strip():
        windows.append(window.strip())
    return windows


class KokoroVoice:
    def __init__(self, directory, threads=4, device="cpu"):
        directory = _directory(directory)
        self._onnx = _session(directory / "model.onnx", threads, providers_for(device))
        # A provider asked for and not taken -- a driver too old, a library
        # missing -- leaves the session on the processor without a word, so
        # where it runs is read back from the session rather than assumed.
        taken = self._onnx.get_providers()
        self.device = "cuda" if "CUDAExecutionProvider" in taken else "cpu"
        self._vocab = _vocab(self._onnx)
        self._voices = np.load(directory / "voices.bin")
        self.speakers = sorted(
            name for name in self._voices.files if name.startswith(_ENGLISH_VOICES)
        )
        self._g2p = EnglishG2P()

    def _read(self, tokens, style):
        """One window of tokens, as the waveform the model answers with."""
        said = self._onnx.run(
            None,
            {
                "input_ids": np.array([[0, *tokens, 0]], dtype=np.int64),
                "style": np.asarray(style, dtype=np.float32),
                "speed": np.array([1.0], dtype=np.float32),
            },
        )
        return np.asarray(said[0], dtype=np.float32).ravel()

    def apply_tts(self, text, speaker, sample_rate, put_accent=True, put_yo=True):
        # An unknown name is the package's first voice rather than a failed
        # line, the way the Russian voice answers an unknown speaker.
        voice = self._voices[speaker if speaker in self.speakers else self.speakers[0]]
        parts = []
        for window in _windows(self._g2p(text), self._vocab, _MAX_TOKENS):
            tokens = [self._vocab[symbol] for symbol in window if symbol in self._vocab]
            # The window was cut on phonemes and the graph counts tokens, so
            # the last few are dropped rather than handed over the limit.
            tokens = tokens[:_MAX_TOKENS]
            if not tokens:
                continue
            # One style vector per phoneme count: n tokens read row n - 1.
            parts.append(self._read(tokens, voice[min(len(tokens), len(voice)) - 1]))
        samples = np.concatenate(parts) if parts else np.zeros(0, dtype=np.float32)
        return torch.from_numpy(resample(_trimmed(samples, _RATE), _RATE, sample_rate))

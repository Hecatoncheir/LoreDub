# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT
#
# Vosk-TTS reads the text here: the synthesis is the vosk-tts package's own
# (Apache 2.0, Alpha Cephei), and only the loading is done differently.

"""The Vosk-TTS voice the worker reads with.

It answers the calls the worker was written against -- `speakers` and
`apply_tts(...)` giving a torch tensor at the rate asked for -- the shape of
the Silero model it replaced.

The package is laid out flat, the way the catalogue publishes it:
`model.onnx`, `config.json`, `dictionary`, `bert.onnx` and `bert-vocab.txt`.
"""

import json
import pathlib
import re

import numpy as np
import torch

from tone_converter import resample

# A line is cut where the voice starts and stops, with this much kept on
# either side. The women's voices leave half a second of silence at each end,
# which would be a second of every line spent saying nothing.
_MARGIN_SECONDS = 0.05
_SILENCE_BELOW_PEAK = 0.02


def _directory(path):
    """The package's directory. The pipeline names a speech package by its
    first file, which for Vosk is `model.onnx`; the directory itself does as
    well."""
    path = pathlib.Path(path)
    return path.parent if path.name == "model.onnx" else path


def _providers(device):
    """Where to read, best first. The card is used through onnxruntime-gpu,
    which the CUDA runtime installs beside torch and which finds its CUDA and
    cuDNN libraries in the torch imported before it; the processor's build
    of onnxruntime offers no such provider, and the voice stays there."""
    import onnxruntime

    if device == "cuda" and "CUDAExecutionProvider" in onnxruntime.get_available_providers():
        return ["CUDAExecutionProvider", "CPUExecutionProvider"]
    return ["CPUExecutionProvider"]


def _session(path, threads, providers):
    import onnxruntime

    options = onnxruntime.SessionOptions()
    # Measured: planning the reuse of memory over this graph's 29 000 nodes
    # is what opening it costs -- 100 s with it, 3 s without, and a line is
    # read in the same time either way.
    options.enable_mem_reuse = False
    options.intra_op_num_threads = max(1, threads)
    # The card's copies between its nodes and the processor's are announced
    # as a warning on every load; they are the model's shape, not a fault.
    options.log_severity_level = 3
    return onnxruntime.InferenceSession(str(path), sess_options=options, providers=providers)


class _Model:
    """What vosk_tts.Synth reads off its model, filled in from our files."""

    def __init__(self, directory, threads, providers):
        from tokenizers.implementations import BertWordPieceTokenizer

        self.config = json.loads((directory / "config.json").read_text(encoding="utf-8"))
        self.onnx = _session(directory / "model.onnx", threads, providers)
        # A word may be listed with several stresses; the likeliest is kept,
        # as vosk_tts.Model does.
        self.dic = {}
        likeliest = {}
        with open(directory / "dictionary", encoding="utf-8") as lines:
            for line in lines:
                items = line.split(maxsplit=2)
                if len(items) < 3:
                    continue
                chance = float(items[1])
                if likeliest.get(items[0], 0) < chance:
                    self.dic[items[0]] = items[2]
                    likeliest[items[0]] = chance
        vocab = directory / "bert-vocab.txt"
        if vocab.is_file():
            self.tokenizer = BertWordPieceTokenizer(
                vocab=str(vocab), unk_token="[UNK]", lowercase=False
            )
            self.bert_onnx = _session(directory / "bert.onnx", threads, providers)
        else:
            self.tokenizer = None


_CYRILLIC = re.compile(r"[а-яё]", re.IGNORECASE)
_DASHES = str.maketrans({"—": "-", "–": "-", "«": " ", "»": " ", '"': " "})


def _sayable(text, phonemes):
    """The text with what the model has no sound for taken out.

    Anything outside its phoneme map -- a digit, a Latin letter left in the
    line -- is a KeyError deep in the synthesis rather than a word skipped.
    The Silero it replaced passed those by in silence (a line with "3" and
    "25" in it lasted as long as the line without them), and this voice does
    the same rather than fail the line.
    """
    kept = [
        char
        if char.isspace() or char == "+" or char in phonemes or _CYRILLIC.match(char)
        else " "
        for char in text.translate(_DASHES)
    ]
    return re.sub(r"\s+", " ", "".join(kept)).strip()


def _trimmed(samples, rate):
    loud = np.flatnonzero(np.abs(samples) > _SILENCE_BELOW_PEAK * (np.abs(samples).max() or 1.0))
    if not loud.size:
        return samples
    margin = int(rate * _MARGIN_SECONDS)
    return samples[max(0, loud[0] - margin) : loud[-1] + margin + 1]


class VoskVoice:
    def __init__(self, directory, threads=4, device="cpu"):
        from vosk_tts import Synth

        directory = _directory(directory)
        self._synth = Synth(_Model(directory, threads, _providers(device)))
        # A provider asked for and not taken -- a driver too old, a library
        # missing -- leaves the session on the processor without a word, so
        # where it runs is read back from the session rather than assumed.
        taken = self._synth.model.onnx.get_providers()
        self.device = "cuda" if "CUDAExecutionProvider" in taken else "cpu"
        self._rate = int(self._synth.model.config["audio"]["sample_rate"])
        self._ids = dict(self._synth.model.config.get("speaker_id_map") or {})
        self.speakers = list(self._ids)
        self._phonemes = {
            symbol
            for symbol in self._synth.model.config.get("phoneme_id_map", {})
            if len(symbol) == 1
        }

    def apply_tts(self, text, speaker, sample_rate, put_accent=True, put_yo=True):
        pcm = self._synth.synth_audio(
            _sayable(text, self._phonemes), speaker_id=self._ids.get(speaker, 0)
        )
        samples = _trimmed(np.asarray(pcm, dtype=np.float32) / 32768.0, self._rate)
        return torch.from_numpy(resample(samples, self._rate, sample_rate))

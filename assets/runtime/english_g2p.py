# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT
#
# The letter-to-sound network below is g2p_en's (Apache 2.0, Kyubyong Park
# and Jongseok Kim, https://github.com/Kyubyong/g2p): its weights are read
# out of the installed package and the decode is the same arithmetic. It is
# written here rather than imported because importing `g2p_en` reaches for
# two NLTK corpora and downloads them when they are missing, which an
# application that dubs a game offline cannot do. Only the weights travel.

"""English phonemes for the Kokoro voice, out of Apache-licensed parts alone.

Every other wrapper of this model phonemizes with espeak-ng, which is GPLv3
and cannot travel inside an MIT application. misaki (Apache 2.0) reads the
words it holds and leaves the rest to a fallback -- and espeak is the
fallback it ships.

Measured over the 119 English lines the player's glossary had collected,
misaki alone leaves 1.4% of the words unread (7 of 501), and they are the
words a game is made of: Whiterun, Zorvax, Aiur, medkit. Unread is worse
than read wrongly: misaki writes an unknown word as a question mark, which
is not in the model's vocabulary and is dropped before synthesis, so the
name is not mispronounced, it is not said at all -- "Zorvax is waiting for
you beyond the Whiterun gate." ran 3.14 s with a fallback and 2.28 s
without, missing both names.

What this fallback guesses is not what espeak guesses: over forty game
proper nouns the two agree on 3, differ only in stress on 4, and differ in
what is actually said on 24 -- "Whiterun" is white-run to espeak and
wit-er-un here. Neither is the truth; both are rules run over a name nobody
taught them. A guess said aloud is one the player can correct with a
glossary entry, and a name dropped in silence is not.
"""

import importlib.util
import pathlib
import re

import numpy as np

# The package whose letter-to-sound weights are read. It is installed for
# this file alone and never imported.
_WEIGHTS_PACKAGE = "g2p_en"
_WEIGHTS_FILE = "checkpoint20.npz"

# The alphabets the network was trained over, in the order its weights index
# them.
_GRAPHEMES = ["<pad>", "<unk>", "</s>"] + list("abcdefghijklmnopqrstuvwxyz")
_PHONEMES = [
    "<pad>", "<unk>", "<s>", "</s>",
    "AA0", "AA1", "AA2", "AE0", "AE1", "AE2", "AH0", "AH1", "AH2", "AO0",
    "AO1", "AO2", "AW0", "AW1", "AW2", "AY0", "AY1", "AY2", "B", "CH", "D",
    "DH", "EH0", "EH1", "EH2", "ER0", "ER1", "ER2", "EY0", "EY1", "EY2", "F",
    "G", "HH", "IH0", "IH1", "IH2", "IY0", "IY1", "IY2", "JH", "K", "L", "M",
    "N", "NG", "OW0", "OW1", "OW2", "OY0", "OY1", "OY2", "P", "R", "S", "SH",
    "T", "TH", "UH0", "UH1", "UH2", "UW", "UW0", "UW1", "UW2", "V", "W", "Y",
    "Z", "ZH",
]

# ARPAbet as the network answers in, written in the phonemes Kokoro was
# trained on. The capitals are the model's own: A is the vowel of "wait", I
# of "white", O of "boat", W of "how", Y of "boy".
_SOUNDS = {
    "AA": "ɑ", "AE": "æ", "AH": "ʌ", "AO": "ɔ", "AW": "W", "AY": "I",
    "B": "b", "CH": "ʧ", "D": "d", "DH": "ð", "EH": "ɛ", "ER": "ɜɹ",
    "EY": "A", "F": "f", "G": "ɡ", "HH": "h", "IH": "ɪ", "IY": "i",
    "JH": "ʤ", "K": "k", "L": "l", "M": "m", "N": "n", "NG": "ŋ",
    "OW": "O", "OY": "Y", "P": "p", "R": "ɹ", "S": "s", "SH": "ʃ",
    "T": "t", "TH": "θ", "UH": "ʊ", "UW": "u", "V": "v", "W": "w",
    "Y": "j", "Z": "z", "ZH": "ʒ",
}

# A vowel carrying no stress is the reduced one, which is a different sound
# rather than the same sound said quietly.
_REDUCED = {"AH": "ə", "ER": "ɚ"}

_STRESS = {"1": "ˈ", "2": "ˌ", "0": ""}

_LETTERS = re.compile(r"[^a-z']")

# What misaki writes where it has no reading. It is not in the model's
# vocabulary, so a line still carrying one would be voiced with a hole in it.
UNREADABLE = "❓"


def _weights_file():
    """Where the letter-to-sound weights sit, without importing what holds
    them."""
    found = importlib.util.find_spec(_WEIGHTS_PACKAGE)
    if found is None or not found.origin:
        raise RuntimeError(f"{_WEIGHTS_PACKAGE} is not installed beside the worker")
    return pathlib.Path(found.origin).parent / _WEIGHTS_FILE


def phonemes_of(arpabet):
    """[arpabet] written in Kokoro's phonemes, or None where a symbol has no
    sound here."""
    written = []
    for symbol in arpabet:
        mark = symbol[-1] if symbol and symbol[-1].isdigit() else ""
        base = symbol[: -1] if mark else symbol
        reduced = _REDUCED.get(base) if mark == "0" else None
        sound = reduced or _SOUNDS.get(base)
        if sound is None:
            return None
        written.append(_STRESS.get(mark, "") + sound)
    return "".join(written)


class LetterToSound:
    """g2p_en's network, reading a word nothing has a spelling for."""

    def __init__(self):
        weights = np.load(_weights_file())
        self._graphemes = {symbol: index for index, symbol in enumerate(_GRAPHEMES)}
        self._phonemes = dict(enumerate(_PHONEMES))
        self._enc_emb = weights["enc_emb"]
        self._enc_w_ih = weights["enc_w_ih"]
        self._enc_w_hh = weights["enc_w_hh"]
        self._enc_b_ih = weights["enc_b_ih"]
        self._enc_b_hh = weights["enc_b_hh"]
        self._dec_emb = weights["dec_emb"]
        self._dec_w_ih = weights["dec_w_ih"]
        self._dec_w_hh = weights["dec_w_hh"]
        self._dec_b_ih = weights["dec_b_ih"]
        self._dec_b_hh = weights["dec_b_hh"]
        self._fc_w = weights["fc_w"]
        self._fc_b = weights["fc_b"]

    @staticmethod
    def _step(x, h, w_ih, w_hh, b_ih, b_hh):
        """One GRU cell."""
        rzn_ih = np.matmul(x, w_ih.T) + b_ih
        rzn_hh = np.matmul(h, w_hh.T) + b_hh
        split_ih = rzn_ih.shape[-1] * 2 // 3
        split_hh = rzn_hh.shape[-1] * 2 // 3
        rz = 1 / (1 + np.exp(-(rzn_ih[:, :split_ih] + rzn_hh[:, :split_hh])))
        r, z = np.split(rz, 2, -1)
        n = np.tanh(rzn_ih[:, split_ih:] + r * rzn_hh[:, split_hh:])
        return (1 - z) * n + z * h

    def __call__(self, word):
        """[word] as ARPAbet, the way the network spells it out."""
        letters = list(word) + ["</s>"]
        encoded = np.take(
            self._enc_emb,
            np.expand_dims([self._graphemes.get(letter, 1) for letter in letters], 0),
            axis=0,
        )
        hidden = np.zeros((1, self._enc_w_hh.shape[-1]), np.float32)
        for step in range(len(word) + 1):
            hidden = self._step(
                encoded[:, step, :],
                hidden,
                self._enc_w_ih,
                self._enc_w_hh,
                self._enc_b_ih,
                self._enc_b_hh,
            )

        spoken = np.take(self._dec_emb, [2], axis=0)  # 2: <s>
        said = []
        # The longest word the network answers for; beyond it the decode is
        # running away rather than spelling.
        for _ in range(20):
            hidden = self._step(
                spoken,
                hidden,
                self._dec_w_ih,
                self._dec_w_hh,
                self._dec_b_ih,
                self._dec_b_hh,
            )
            chosen = int((np.matmul(hidden, self._fc_w.T) + self._fc_b).argmax())
            if chosen == 3:  # 3: </s>
                break
            said.append(self._phonemes.get(chosen, "<unk>"))
            spoken = np.take(self._dec_emb, [chosen], axis=0)
        return said


class EnglishG2P:
    """The text as phonemes, misaki first and the network for the rest."""

    def __init__(self, british=False):
        import misaki.en as en
        import spacy

        # misaki downloads the tagger itself when it is missing, which is a
        # network call inside a dubbing session. The runtime carries it.
        if not spacy.util.is_package("en_core_web_sm"):
            raise RuntimeError("en_core_web_sm is not installed beside the worker")
        self._letters = LetterToSound()
        self._g2p = en.G2P(british=british, fallback=self._guessed)

    def _guessed(self, token):
        """What misaki asks for where it has no reading of its own."""
        word = _LETTERS.sub("", str(getattr(token, "text", token)).lower())
        if not word:
            return None, None
        written = phonemes_of(self._letters(word))
        # The rating misaki files a guess under; its own espeak fallback
        # uses the same.
        return written, 3

    def __call__(self, text):
        phonemes, _ = self._g2p(text)
        return phonemes

# 0008. English phonemes without espeak-ng

Status: accepted. Code: `assets/runtime/english_g2p.py`, `scripts/prepare_windows_runtime.ps1`.

## Decision

The English voice's phonemes come from misaki's dictionary and, for the words
it lacks, g2p_en's letter-to-sound network ported into the worker -- both
Apache 2.0 -- and never from espeak-ng, which is GPLv3 and cannot travel inside
an MIT application. misaki is installed without its `[en]` extra, which is
what pulls the GPL half in.

## Why, measured

As it stood in `CLAUDE.md` when the decision was taken, numbers and
all; measure again before changing what it holds up.

The phonemes are the part with a licence in it. Every other wrapper of that
model takes them from espeak-ng, which is GPLv3 and cannot travel inside an
MIT application, so `assets/runtime/english_g2p.py` reads the words misaki
(Apache 2.0) holds and answers the rest with the letter-to-sound network of
g2p_en (Apache 2.0), ported into that file because importing the package
reaches for two NLTK corpora and downloads them. Only its `checkpoint20.npz`
is used, found through `importlib.util.find_spec` so the module is never
executed; the port answers what `g2p_en.G2p.predict` answers on all forty
words it was checked against. Measured over the 119 English lines the
glossary had collected, misaki alone leaves 1.4% of the words unread, and
they are the ones a game is made of (Whiterun, Zorvax, Aiur, medkit) — unread
meaning **dropped**, since its `❓` is not in the model's vocabulary. The
fallback's guesses are not espeak's: over forty game proper nouns the two
agree on 3, differ only in stress on 4 and differ in what is said on 24. That
is the trade the licence buys, and the glossary is the lever the player has
over it. `prepare_windows_runtime.ps1` therefore installs misaki **without**
its `[en]` extra — that extra is what pulls espeakng-loader and
phonemizer-fork, the GPL half — naming `num2words` and `spacy` itself, and
installs `g2p-en` with `--no-deps` in a pip run of its own.

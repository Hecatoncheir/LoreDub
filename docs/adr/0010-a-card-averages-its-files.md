# 0010. A card built from files averages them as the encoder gave them

Status: accepted. Code: `build_voice` in `assets/runtime/voices.py`.

## Decision

A card built from files is the plain average of every file's embedding, not
normalized: the vector is what the converter re-voices against, so its length
counts. Thresholds only drop what is not a voice (`STRANGE_FILE`, 0.45) and
warn of a set holding two (`LOOSE_SET`, 0.80); neither rejects an odd line of
the right character, which no threshold can tell from a stranger.

## Why, measured

As it stood in `CLAUDE.md` when the decision was taken, numbers and
all; measure again before changing what it holds up.

The
worker's `build_voice` then embeds every file and averages them **as the
encoder gave them**: a card's vector is the conditioning the converter
re-voices against, so it has a length (the encoder answers around 12 to 14)
as well as a direction. Cosine ignores the length, so a normalized card is
still recognized perfectly and sounds like nobody -- converting one
character into another with a unit-length target lands at 0.05 to 0.13 of
the character aimed at, further off than not converting at all, against 0.75
to 0.90 for the plain average. Normalize only for comparing. Averaging is
measured to beat keeping one clip: over 36 clips of five characters, leaving each
out in turn, the held-out clip is closer to the average of the rest than to
any single other clip 36 times out of 36, by 0.076. This is not the bank's
"never average" rule broken -- there the pipeline founds the voices and a
fingerprint that wandered would stand for a character nobody chose; here the
player names the files as one person. What the numbers also say is that a
threshold cannot tell a stranger from an odd line of the right character
(same-character pairs run 0.57 to 0.94, different-character pairs up to
0.80), so `STRANGE_FILE` (0.45) only drops what is not a voice at all, and
`LOOSE_SET` (0.80) is a warning that the set holds two voices rather than a
rejection.

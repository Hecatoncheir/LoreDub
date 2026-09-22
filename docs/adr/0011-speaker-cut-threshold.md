# 0011. A segment is cut between speakers at a cosine distance of 0.25

Status: accepted. Code: `speaker_cuts` in `assets/runtime/audio.py`, `PhraseProcessor._splitBySpeaker`.

## Decision

`speaker_cuts` cuts a segment where the distance between neighbouring 1.5 s
windows passes 0.25, at the quietest moment within 0.4 s.

## Why, measured

As it stood in `CLAUDE.md` when the decision was taken, numbers and
all; measure again before changing what it holds up.

The 0.25 is measured, like the bank's 0.80:
two Silero voices joined gave 0.34 across the boundary and at most 0.11 at
the seam of two phrases by one voice, and the cut landed 20 ms from the real
boundary. Measure again before moving it — a threshold too low fragments
every phrase.

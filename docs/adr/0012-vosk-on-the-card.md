# 0012. Vosk is offered on the card, and Automatic chooses it

Status: accepted. Code: `--speech-device`, `resolveComputeBackend` in `lib/src/domain/compute_device.dart`.

## Decision

The voice runs on the card when the compute setting says so, and Automatic
chooses the card for it too, although Vosk pays for every line of a new length
there: the user asked for every stage that can run on the card to.

## Why, measured

As it stood in `CLAUDE.md` when the decision was taken, numbers and
all; measure again before changing what it holds up.

The card is a poor bargain for
Vosk and it is offered anyway, Automatic choosing it, because the user asked
for every stage that can run on the card to: measured on an RTX 3080 Ti, a
phrase repeated is read in 0.3 s, but every line of a new length costs about
1.9 s against the processor's 0.4 to 1.3, cuDNN planning the convolution
afresh for each shape (`Conv` was 1.8 s of a 2.5 s run), and neither the
algorithm search nor the workspace settings change it.

# 0009. The translators are converted here and published with digests

Status: accepted. Code: `scripts/convert_translators.py`, `_converted` and `_modelReleases` in `model_catalog.dart`.

## Decision

The Marian translators are converted to CTranslate2 once, by
`scripts/convert_translators.py`, and published as this project's release in
the public `Hecatoncheir/LoreDub-models` with sizes, SHA-256 and the NOTICE
CC-BY-4.0 asks for, rather than converted on every machine.

## Why, measured

As it stood in `CLAUDE.md` when the decision was taken, numbers and
all; measure again before changing what it holds up.

The translators are the one thing the catalogue does not fetch from its
authors: `_converted` points at this project's own release, in the public
`Hecatoncheir/LoreDub-models` repository (`_modelReleases`) -- the
application's repository is private, and a private release asset answers an
anonymous download with 404 -- because the
CTranslate2 conversion is made once here rather than on every machine — it
wants a transformers newer than the runtime carries.
`scripts/convert_translators.py` builds them and prints the entries, sizes
and SHA-256 filled in for every file, which the upstream checkpoints could
never be (OPUS-MT publishes no digests). CC-BY-4.0 allows the conversion and
its distribution and asks for attribution and a statement of what changed:
that is the NOTICE travelling in each package, and it is downloaded with the
weights rather than written afterwards. `ModelStorageService` sweeps files a
package no longer names once a download completes, so the PyTorch checkpoint
of the old shape does not sit beside the new one forever.

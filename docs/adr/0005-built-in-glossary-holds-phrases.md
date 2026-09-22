# 0005. The built-in glossary holds phrases, each one measured

Status: accepted. Code: `lib/src/data/services/glossary_catalog.dart`, `GlossaryService.withBuiltIn`.

## Decision

The packs LoreDub brings carry phrases and nothing else, and a phrase is in
them only where the pipeline's own Marian answered it wrong. Names and words
belong in a pack made for one game.

## Why, measured

As it stood in `CLAUDE.md` when the decision was taken, numbers and
all; measure again before changing what it holds up.

`glossary_catalog.dart` is the two packs LoreDub brings with it -- the
general one and the lines a player knows by heart, where being literally
right is not enough and a fresh translation lands wrong however correct it
is -- laid over the file once by `GlossaryService.withBuiltIn` and marked by a
`glossary.builtin` file beside it, so a pack the player threw away does not
come back. It carries phrases and nothing else, and that is measured rather
than chosen: every line in it was put through the same Marian the pipeline
runs and kept only where the answer was wrong, while a name entry was tried
against sixteen proper nouns in two frames each and fired **none** -- the
model renders every one of them and leaves no Latin for that path to catch.
A word entry is matched on the dubbing language and would reach lines that
have nothing to do with a game, so both belong in a pack made for one game
rather than in a general one.

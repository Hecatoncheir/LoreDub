# 0004. The glossary has three kinds of entry, and only three

Status: accepted. Code: `lib/src/domain/glossary.dart`, `Glossary` in `assets/runtime/dubbing_text.py`.

## Decision

A phrase is a whole sentence answered before the model is asked; a name
replaces what the translator left in Latin, inside `readable` and nowhere
else; a word is matched on the dubbing language after the translation and
replaced whole, never by stem. A placeholder in the source, `target_prefix`
and `suppress_sequences` were each measured as a way to reach further, and
none of them works.

## Why, measured

As it stood in `CLAUDE.md` when the decision was taken, numbers and
all; measure again before changing what it holds up.

Three kinds, kept apart
because they reach a line at different moments and none can do another's
work. A `GlossaryKind.phrase` is a whole sentence with the player's own
translation, answered before the model is asked: the model is not wrong about
"Fire in the hole!" so much as ignorant of the game. A `GlossaryKind.name`
replaces what the translator left in Latin script, inside `readable`, and
nowhere else -- measured, the model transliterates and correctly declines the
names it does render ("The people of Megaton" comes back as "Жители
Мегатона", "Talk to the mayor of Megaton" as "с мэром Мегатона"), so a
nominative laid over the whole line would break the grammar it had already
found. Two ways of reaching further were measured and do not work: a
placeholder put in the source so the name could be substituted afterwards is
transliterated like any other Latin ("Zorvax" survived one sentence of eight,
and a short one like "Qqq" was dropped outright, taking the name with it), and
`target_prefix` only holds the start of the line -- forced "Мегатон", the
decoder wrote "Мегатонн" anyway. `suppress_sequences` looked promising on the
first two lines tried and does not survive forty-two: forbidding a rendering
puts the model's *second* choice in its place, so where the first was right
the answer gets worse -- "Добро пожаловать в Мегатон" became "в Мегафон",
"Уайтран ушел" became "Уайтрун ушла", "Жители Мегатона" became "Жители
Мегатонна". It helps only where the first choice was already broken
("из Рапта" became "из Раптуры"), and telling a broken form from a
declined one is the morphology this has none of. Do not reach for it again.
What those forty-two lines did show is a larger thing nothing here fixes: the
model translates a name it reads as a word, and differently from line to line
-- "Vault" is "Убежище" in one line and "Хранилище" in the next,
"Rapture" runs "Восторг", "Восхищение", "в восторге", and "Whiterun"
reaches "Жители Белгорода". No Latin is left to hook onto, so the only
lever the player has over it is a phrase entry on the line itself. A `GlossaryKind.word` is the third and the only one matched on the dubbing
language rather than on English: it replaces a word of what was said, after
the translation and whether or not there was one, which is how the screen's
own text is reached as well. It exists for the case nothing else can touch --
the model's rendering wandering between lines -- and that case is rarer than
one small sample suggested: over eight frames "Vault" came back as "Убежище"
seven times, declined correctly each time, and "Хранилище" once; "Whiterun"
ran seven to one the same way. The whole word is replaced and nothing less.
Swapping a stem and carrying the match's ending onto it was measured and
rejected: it turns "Восхищение сгорит" into "Восторге сгорит" and
"Ворота Восхищения" into "Ворота Восторгя", two words that mean the
same thing not having to decline the same way. Passing a declined form by
leaves the line as the model said it; inventing one puts a word that does not
exist into the player's ears. Matching ignores case and spacing on all three,
and a word entry carries the capital it was found under.

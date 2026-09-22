# 0002. A line is translated a sentence at a time

Status: accepted. Code: `assets/runtime/dubbing_text.py`, `Translation` in `assets/runtime/inference_worker.py`.

## Decision

`sentences` cuts a line into its sentences and CTranslate2 decodes them as one
batch; `TranslationMemory` keeps the last 512. What is left in Latin is written
out by `transliterated` rather than translated again, unless more than two
Latin words were left -- a line passed through -- and nothing of it runs when
the dubbing language is written in Latin. A lone letter is named.

## Why, measured

As it stood in `CLAUDE.md` when the decision was taken, numbers and
all; measure again before changing what it holds up.

A line is translated a sentence at a time. Marian was trained on single
sentences and answers a reply of several with one of them, dropping the rest --
"Get to the chopper! Now! Go, go, go!" came back as "Давай, давай, давай", and five of
nine multi-sentence lines measured lost a sentence. `sentences`
(`assets/runtime/dubbing_text.py`, the worker's text half, which needs no
numpy and is tested on any Python in `test/runtime/`) cuts the line where one ends and the next begins -- a
full stop before a small letter being a line thinking aloud rather than an end,
and one closing a title or an initial no end either -- and the pieces go to
CTranslate2 as a single batch, which decodes them side by side: 100 ms against
116 for the same lines whole. `TranslationMemory` keeps the last 512 sentences,
so a game repeating itself costs nothing and one shout is never rendered two
ways in the same fight. What the translator leaves in Latin script is written
out by `transliterated` rather than translated a second time. The voice reads
no Latin: `vosk_voice.py` drops whatever its phoneme map lacks -- Latin and
digits -- rather than raise on it (the Silero it replaced dropped the word
too, measured, and raised on a line that was Latin end to end), so the name
written out is the name spoken at all. None of this runs for a session
dubbing into English: `dubbed_in_latin` is true the moment there is no
translator, and the English voice reads Latin and nothing else. A letter standing on its own is
dropped the same way and is named rather than spelt: "Press F to pay respects"
is "Нажмите эф", since one letter of Cyrillic is worth as little to the
voice as one of Latin (2.07 s against the 1.98 s of the line without it, and
2.22 s named). `LATIN_RUN` stays the Latin *word*, which is what says whether
the line was translated at all; `LATIN_TEXT` is any Latin at all, which is
what has to be written over. The second pass all this replaces answered
"Rapture" with "восторг" and "Megaton" with "мегатонну", names it had no
business translating -- and only where the dubbing language is not written in
Latin itself, which `dubbed_in_latin` asks the translator once at startup: a
German line is Latin from end to end, so every one of them used to go through
the model twice for an answer that was thrown away. More than two Latin words
left behind is a line passed through rather than translated, and that is the one
case where the second pass earns the time it costs.

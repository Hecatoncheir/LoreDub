# Decisions

Each file here is one decision the code rests on, with what was measured to
take it: the numbers that hold a threshold where it is, the flags and models
that were tried and do not work, and the licences that ruled a library out.
`CLAUDE.md` keeps the rule and names the file; read the one a change touches
before changing what it holds up, and measure again rather than argue with
the numbers.

A new decision is the next number, `NNNN-a-few-words.md`, with a Decision and
a Why, and a line in `CLAUDE.md` where the rule is kept.

| | Decision |
| --- | --- |
| 0001 | [Recognition shortens the encoder window to 1000 at most](0001-whisper-encoder-window.md) |
| 0002 | [A line is translated a sentence at a time](0002-translate-sentence-by-sentence.md) |
| 0003 | [The speech threshold follows the game down](0003-speech-threshold-under-the-duck.md) |
| 0004 | [The glossary has three kinds of entry, and only three](0004-three-kinds-of-glossary-entry.md) |
| 0005 | [The built-in glossary holds phrases, each one measured](0005-built-in-glossary-holds-phrases.md) |
| 0006 | [Russian is voiced by Vosk-TTS](0006-vosk-russian-voice.md) |
| 0007 | [English is voiced by Kokoro, fp32](0007-kokoro-english-voice.md) |
| 0008 | [English phonemes without espeak-ng](0008-english-phonemes-without-espeak.md) |
| 0009 | [The translators are converted here and published with digests](0009-translators-converted-here.md) |
| 0010 | [A card built from files averages them as the encoder gave them](0010-a-card-averages-its-files.md) |
| 0011 | [A segment is cut between speakers at a cosine distance of 0.25](0011-speaker-cut-threshold.md) |
| 0012 | [Vosk is offered on the card, and Automatic chooses it](0012-vosk-on-the-card.md) |
| 0013 | [A language model translates and a cloning voice reads, where a card can carry them](0013-language-model-and-cloning-voice.md) |

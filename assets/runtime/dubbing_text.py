# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

"""What the worker does to a line as text: cuts it into sentences, writes
out what the translator left in Latin, answers from the player's glossary,
and remembers what it translated.

Nothing here needs numpy or torch, so it is tested on any interpreter.
"""

import collections
import json
import re

# Two or more Latin letters in a translated line means a name came through
# untranslated, and the voice does not read Latin: vosk_voice.py drops what
# its phoneme map lacks, so "Добро пожаловать в Rapture." would be said
# without the name at all (the Silero this replaced did the same, and raised
# on a line of Latin end to end).
LATIN_RUN = re.compile(r"[A-Za-z]{2,}")

# A letter standing on its own is dropped the same way -- "Нажмите F, чтобы
# выразить почтение." speaks for the 1.98 s of the line without it -- but
# it is a key or an initial rather than a word, so it is named rather than
# spelt out. [LATIN_RUN] stays the Latin *word*, which is what says whether a
# line was translated at all; this is any Latin at all, which is what has to
# be written over.
LATIN_TEXT = re.compile(r"[A-Za-z]+")

# Marian was trained a sentence at a time, and a reply of several arrives as
# one. Handed the lot, it answers for one of them and drops the rest: "Get to
# the chopper! Now! Go, go, go!" came back as "Давай, давай, давай", and five
# of nine multi-sentence lines measured lost a sentence. Cut apart and
# translated as one batch they all come back, and it is the faster way as
# well -- the batch decodes the short pieces side by side, 100 ms against 116
# for the same lines whole.

# The sentence that follows opens with a capital; a full stop before a
# small letter is a line thinking aloud -- "I was... afraid." is one
# sentence, and cut in two it came back as "Я был... боюсь."
SENTENCE_BREAK = re.compile(
    "(?:(?<=[.!?…])|(?<=[.!?…][\"'”’)\\]]))\\s+(?=[\"'“‘(\\[]*[^a-z])"
)

# A full stop that closes a title or an initial does not end a sentence.
ABBREVIATIONS = frozenset(
    "mr mrs ms dr st sgt lt cpl capt maj col gen prof sr jr vs etc no".split()
)
TRAILING_WORD = re.compile("([A-Za-z]+)[.!?…][\"'”’)\\]]?$")


def sentences(text):
    """[text] cut where one sentence ends and the next begins."""
    parts = []
    start = 0
    for split in SENTENCE_BREAK.finditer(text):
        head = text[start : split.start()].strip()
        closing = TRAILING_WORD.search(head)
        if closing and (len(closing.group(1)) == 1 or closing.group(1).lower() in ABBREVIATIONS):
            continue
        if head:
            parts.append(head)
        start = split.end()
    tail = text[start:].strip()
    if tail:
        parts.append(tail)
    return parts or [text.strip()]


# What is left in Latin script is written out rather than translated a second
# time. The second pass answered "Rapture" with "восторг" and "Megaton" with
# "мегатонну" -- names it had no business translating -- and cost a whole pass
# of the model to do it. Written out, the name is spoken at all, which is the
# whole of it: the voice says nothing where it stood. The table reads aloud
# rather than spells correctly; every dubbing language shipped that is not
# written in Latin is written in Cyrillic.
TRANSLITERATION = (
    ("sch", "ш"),
    ("tch", "ч"),
    ("ch", "ч"),
    ("sh", "ш"),
    ("th", "т"),
    ("ph", "ф"),
    ("ck", "к"),
    ("qu", "кв"),
    ("ce", "се"),
    ("ci", "си"),
    ("cy", "си"),
    ("ee", "и"),
    ("ea", "и"),
    ("oo", "у"),
    ("ou", "ау"),
    ("ow", "ау"),
    ("ai", "эй"),
    ("ay", "эй"),
    ("ey", "эй"),
    ("oy", "ой"),
    ("a", "а"),
    ("b", "б"),
    ("c", "к"),
    ("d", "д"),
    ("e", "е"),
    ("f", "ф"),
    ("g", "г"),
    ("h", "х"),
    ("i", "и"),
    ("j", "дж"),
    ("k", "к"),
    ("l", "л"),
    ("m", "м"),
    ("n", "н"),
    ("o", "о"),
    ("p", "п"),
    ("q", "к"),
    ("r", "р"),
    ("s", "с"),
    ("t", "т"),
    ("u", "у"),
    ("v", "в"),
    ("w", "в"),
    ("x", "кс"),
    ("y", "и"),
    ("z", "з"),
)

# The "e" that lengthens the vowel before it and is not said itself: Rapture
# is read "Раптур" rather than "Раптуре", Blade "Блад".
SILENT_E = re.compile("(?<=[aeiouy])([bcdfgklmnprstvz])e$")


# The English names of the letters, as a player says them: "Press F to pay
# respects" is "Нажмите эф", not "Нажмите ф" -- one letter of Cyrillic is
# dropped by the voice as readily as one of Latin.
LETTER_NAMES = {
    "a": "эй",
    "b": "би",
    "c": "си",
    "d": "ди",
    "e": "и",
    "f": "эф",
    "g": "джи",
    "h": "эйч",
    "i": "ай",
    "j": "джей",
    "k": "кей",
    "l": "эль",
    "m": "эм",
    "n": "эн",
    "o": "оу",
    "p": "пи",
    "q": "кью",
    "r": "ар",
    "s": "эс",
    "t": "ти",
    "u": "ю",
    "v": "ви",
    "w": "дабл-ю",
    "x": "икс",
    "y": "уай",
    "z": "зет",
}


def transliterated(word):
    """[word] written in Cyrillic, to be read aloud rather than understood."""
    if len(word) == 1:
        # Left in lower case: a letter on its own carries no sentence, and
        # "Нажмите Эф" would be a capital in the middle of one.
        return LETTER_NAMES.get(word.lower(), word)
    lowered = SILENT_E.sub(r"\1", word.lower())
    said = []
    at = 0
    while at < len(lowered):
        for piece, sound in TRANSLITERATION:
            if lowered.startswith(piece, at):
                # "York" opens on a consonant, "Mystery" carries a vowel.
                said.append("й" if piece == "y" and at == 0 else sound)
                at += len(piece)
                break
        else:
            said.append(lowered[at])
            at += 1
    written = "".join(said)
    return written.capitalize() if word[:1].isupper() else written


# How many Latin words a translated line may keep and still have been
# translated: a name or two stays behind as it is, more is a line the model
# passed through untouched.
NAMES_LEFT_IN_LATIN = 2


def readable(translated, source, translate, glossary=None):
    """[translated] with whatever the translator left in Latin script written
    so that the voice can say it."""
    if len(LATIN_RUN.findall(translated)) > NAMES_LEFT_IN_LATIN:
        # More than a name or two stayed behind: the line was passed through
        # rather than translated, and asking again without the capitals is
        # what recovers it. Measured, that is the one case where the second
        # pass earns the time it costs. Lone letters do not count towards it:
        # a key named in a line is not a line left untranslated.
        retry = translate(source.lower())
        if not LATIN_RUN.search(retry):
            translated = retry
    def written(run):
        # The player's own spelling first: they wrote it down because the
        # letters below said it wrong.
        word = run.group(0)
        named = glossary.reading(word) if glossary is not None else None
        return named if named else transliterated(word)

    return LATIN_TEXT.sub(written, translated)


class Glossary:
    """What the player wrote down about the games they play.

    Two kinds, and each reaches the line at its own moment. A phrase is a
    whole sentence the player has translated themselves, answered before the
    model is asked at all -- the model is not wrong about "Fire in the hole!"
    so much as ignorant of the game. A name is a word the model left in Latin
    script, and it is written in only there: measured, the model transliterates
    and correctly declines the names it does render -- "The people of Megaton"
    comes back as "Жители Мегатона" -- so a nominative laid over the whole line
    would break the grammar it had already found.
    """

    def __init__(self, path=""):
        self.names = {}
        self.phrases = {}
        self.words = []
        # The names and words as the player spelled them, with their
        # readings: what a model that can be told them is told.
        self.hints = []
        if not path:
            return
        try:
            with open(path, encoding="utf-8") as source:
                self.replace(json.load(source))
        except (OSError, ValueError):
            # A damaged file is a glossary the player has not written yet.
            pass

    # What is punctuation at the edge of a line rather than part of it.
    # The interface files an entry under the same rule: a shout arrives
    # with a full stop as often as with an exclamation, and an entry
    # written under one spelling would otherwise miss the other.
    EDGE = """.!?,;:…"'«»“”-–—"""

    @classmethod
    def _key(cls, source):
        collapsed = " ".join(str(source).lower().split())
        # The space goes with the marks, as the interface strips them: "Fire
        # in the hole! !" is the same shout, and stripping the marks alone
        # stopped at the space and kept the first "!". A source that is
        # punctuation and nothing else keeps what it had.
        return collapsed.strip(cls.EDGE + " ") or collapsed

    def replace(self, written):
        """Reads what the interface keeps, which is also what it sends when
        the player edits an entry while a session runs."""
        names, phrases, words, hints = {}, {}, [], []
        # A file of the wrong shape is a glossary not written yet, rather than
        # a worker that will not start.
        entries = written.get("entries") if isinstance(written, dict) else None
        for entry in entries if isinstance(entries, list) else []:
            if not isinstance(entry, dict):
                continue
            source = str(entry.get("source") or "").strip()
            reading = str(entry.get("reading") or "").strip()
            kind = entry.get("kind")
            # A phrase the player silenced carries no reading, and that is
            # the whole of it: the sentence leaves the line rather than being
            # said. Everything else needs both halves to mean anything.
            silent = kind == "phrase" and entry.get("silent") is True
            if not source or (not reading and not silent):
                continue
            if silent:
                phrases[self._key(source)] = ""
                continue
            if kind == "word":
                # Compiled once: this runs over every line, and a word is
                # looked for whether or not it is there.
                words.append((re.compile(rf"\b{re.escape(source)}\b", re.IGNORECASE), reading))
                hints.append((source, reading))
            elif kind == "phrase":
                phrases[self._key(source)] = reading
            else:
                names[self._key(source)] = reading
                hints.append((source, reading))
        self.names, self.phrases, self.words, self.hints = names, phrases, words, hints

    def reading(self, word):
        """How the player says this Latin word, or None."""
        return self.names.get(self._key(word))

    def said(self, sentence):
        """The player's own translation of this sentence, or None."""
        return self.phrases.get(self._key(sentence))

    def mentioned(self, text):
        """The names and words the player renamed that [text] holds, each
        with its reading: what a translator that takes instructions is told
        before the line, so that it declines the name rather than leaving it
        for the nominative to be laid over afterwards."""
        lowered = text.lower()
        return [(source, reading) for source, reading in self.hints if source.lower() in lowered]

    def worded(self, text):
        """[text] with the words the player renamed said their way.

        The whole word and nothing less, with the capital it was found under
        kept: a word at the head of a sentence is still at the head of it.
        """
        for pattern, reading in self.words:
            text = pattern.sub(lambda found, reading=reading: _like(reading, found.group(0)), text)
        return text

    def __len__(self):
        return len(self.names) + len(self.phrases) + len(self.words)


def _like(word, found):
    """[word] written with the capital [found] carried."""
    if found[:1].isupper():
        return word[:1].upper() + word[1:]
    return word[:1].lower() + word[1:]


# Games repeat themselves -- "Take cover!", "Reloading!", the quest line read
# again on the way back through the room -- and a sentence already translated
# is answered from here for nothing. It is also what keeps one shout from
# being rendered two ways in the same fight: the first answer is the answer.
TRANSLATION_MEMORY = 512


class TranslationMemory:
    """The sentences this session has translated, the newest kept."""

    def __init__(self, capacity=TRANSLATION_MEMORY):
        self._kept = collections.OrderedDict()
        self._capacity = capacity

    @staticmethod
    def _key(sentence):
        return " ".join(sentence.split())

    def get(self, sentence):
        key = self._key(sentence)
        if key not in self._kept:
            return None
        self._kept.move_to_end(key)
        return self._kept[key]

    def put(self, sentence, translated):
        key = self._key(sentence)
        self._kept[key] = translated
        self._kept.move_to_end(key)
        while len(self._kept) > self._capacity:
            self._kept.popitem(last=False)

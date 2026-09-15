# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

"""Persistent, line-delimited JSON worker for Marian and Silero inference."""

import argparse
import collections
import json
import os
import re
import pathlib
import sys
import wave

import numpy as np

# torch and transformers are imported inside main(): together they account for
# most of the startup, and importing them here would leave the application
# without a sign of life for the first ten seconds.


def use_utf8_streams():
    """Pipes default to the Windows ANSI code page, which mangles Cyrillic.

    The Dart side reads this process as UTF-8, so a translated phrase would be
    dropped on decoding while the ASCII handshake still succeeded.
    """
    for stream in (sys.stdin, sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass


def reply(value):
    sys.stdout.write(json.dumps(value, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def report_progress(value, stage):
    """Announces the step that is about to run, with its share of the startup.

    The shares come from measuring a warm start: importing torch and
    transformers takes far longer than loading the models themselves. The
    stage is a code, not a sentence: the application writes it out in
    whichever language its interface is set to.
    """
    reply({"type": "progress", "value": value, "stage": stage})


def change_speed(samples, speed, sample_rate):
    """Scales speech duration without shifting pitch (WSOLA).

    Silero has no rate control, so the synthesized waveform is retimed here.
    A speed above 1.0 shortens the phrase.
    """
    if samples.size == 0 or abs(speed - 1.0) < 0.01:
        return samples
    frame = max(256, int(sample_rate * 0.04))
    hop_out = frame // 2
    hop_in = max(1, int(round(hop_out * speed)))
    search = max(1, int(sample_rate * 0.005))
    window = np.hanning(frame).astype(np.float32)
    capacity = int(samples.size / speed) + frame
    output = np.zeros(capacity, dtype=np.float32)
    weights = np.zeros(capacity, dtype=np.float32)

    read = 0
    offset = 0
    write = 0
    while True:
        start = read + offset
        if start + frame > samples.size or write + frame > capacity:
            break
        output[write:write + frame] += samples[start:start + frame] * window
        weights[write:write + frame] += window
        write += hop_out

        # The frame that would naturally follow the one just written. The next
        # analysis frame is picked near the ideal position so that it continues
        # this waveform with the least discontinuity.
        natural = samples[start + hop_out:start + hop_out + frame]
        if natural.size < frame:
            break
        read += hop_in
        low = max(0, read - search)
        high = min(samples.size - frame, read + search)
        if high <= low:
            offset = 0
            continue
        scores = np.correlate(samples[low:high + frame], natural, mode="valid")
        offset = low + int(np.argmax(scores)) - read

    filled = np.flatnonzero(weights > 1e-3)
    if filled.size == 0:
        return samples
    output = output[filled[0]:filled[-1] + 1]
    output /= weights[filled[0]:filled[-1] + 1]
    return np.clip(output, -1.0, 1.0)


def median_f0(samples, rate, low=70.0, high=350.0, clarity=0.35):
    """Median fundamental of the voiced frames, or None when there are none.

    Autocorrelation over short frames is enough for the only question asked
    of it — whether the speaker reads as a man or a woman — and costs a
    fraction of a millisecond next to recognition.
    """
    frame = int(rate * 0.04)
    hop = int(rate * 0.02)
    if len(samples) < frame:
        return None
    window = np.hanning(frame)
    min_lag, max_lag = int(rate / high), int(rate / low)
    energies, picks = [], []
    for start in range(0, len(samples) - frame, hop):
        block = samples[start : start + frame]
        energy = float(np.sqrt(np.mean(block**2)))
        block = (block - block.mean()) * window
        spectrum = np.fft.rfft(block, n=2 * frame)
        correlation = np.fft.irfft(spectrum * np.conj(spectrum))[:frame]
        if correlation[0] <= 0:
            continue
        segment = correlation[min_lag : max_lag + 1]
        if not len(segment):
            continue
        lag = int(np.argmax(segment)) + min_lag
        if correlation[lag] / correlation[0] < clarity:
            continue
        energies.append(energy)
        picks.append(rate / lag)
    if not picks:
        return None
    # Quiet frames are mostly room tone and music; weight the answer towards
    # the frames that actually carry speech.
    floor = np.median(energies) * 0.5
    strong = [f for f, e in zip(picks, energies) if e >= floor]
    return float(np.median(strong or picks))


def voice_for_character(kept, gender, index, by_gender):
    """The voice one of the player's own cards is read in.

    The card decides, and never the character it stands in for: a man speaks
    for a woman and a woman for a man wherever the player has said so. It
    names its own voice, or at least the gender it was recorded in; a voice
    this package does not ship is passed over. With neither — imported, or
    recorded in a line that fell between the two genders — any voice will
    serve, so long as the same card always earns the same one. None when the
    package ships no voices at all.
    """
    if kept in by_gender["male"] or kept in by_gender["female"]:
        return kept
    candidates = by_gender.get(gender or "", []) or by_gender["male"] + by_gender["female"]
    return candidates[index % len(candidates)] if candidates else None


def request_speed(request, fallback):
    """The pace this one line asks to be read at.

    The queue of lines waiting for the voice is a moment's business rather
    than a setting, so the pace travels with the line instead of being fixed
    when the worker starts. Anything unreadable leaves the session's own.
    """
    try:
        return min(2.0, max(0.5, float(request["speed"])))
    except (KeyError, TypeError, ValueError):
        return fallback


def read_wave_mono(path):
    """Reads a 16-bit PCM WAV as float32 in [-1, 1], mixed down to mono."""
    with wave.open(path, "rb") as stream:
        if stream.getsampwidth() != 2:
            return None, 0
        rate = stream.getframerate()
        raw = stream.readframes(stream.getnframes())
        channels = stream.getnchannels()
    samples = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
    if channels > 1:
        samples = samples.reshape(-1, channels).mean(axis=1)
    return samples, rate


def build_voice(converter, paths):
    """One fingerprint for a character, from several recordings of them.

    The recordings are averaged rather than picked between. Leaving each of
    36 measured clips out in turn, the held-out clip is closer to the
    average of the rest than to any single other clip of the same character
    36 times out of 36, by 0.076 on average: what several files buy is the
    centre of a voice instead of the quirks of one line of it. (The game's
    own bank still never averages -- there the voices are founded by the
    pipeline and a fingerprint that wandered would stand for a character
    nobody chose. Here the player says which files are one person.)

    The average is the plain one, in the scale the encoder answers in. A
    card's vector is handed to the converter as the timbre to re-voice
    against, and that is a vector with a length as well as a direction: the
    encoder answers around 12 to 14, and the same average at length one
    turns a voice into nobody -- converting one character into another with
    it lands at 0.05 to 0.13 of the character aimed at, further away than
    leaving the clip alone. Averaged as it comes, it lands at 0.75 to 0.90.

    What comes back says how well the files agreed, so the player can see
    the fingerprint was taken from one voice and not from two.
    """
    measured = []
    skipped = []
    for path in paths:
        try:
            samples, rate = read_wave_mono(path)
        except (OSError, wave.Error, ValueError):
            samples, rate = None, 0
        if samples is None or rate <= 0 or len(samples) < rate * SHORTEST_CLIP:
            skipped.append(path)
            continue
        # Kept as the encoder gave it. The card's vector is not only
        # something to recognize a speaker by -- it is the conditioning the
        # converter is re-voiced against -- and that one has a length as
        # well as a direction.
        fingerprint = converter.embed(samples, rate).flatten().float().cpu().numpy()
        measured.append((path, fingerprint, len(samples) / rate))
    if not measured:
        raise RuntimeError("none of the files held enough voice to measure")

    vectors = np.stack([vector for _, vector, _ in measured])

    def unit(matrix):
        """The same vectors at length one, which is what comparing them
        means; the average itself is never kept this way."""
        lengths = np.linalg.norm(matrix, axis=-1, keepdims=True)
        return matrix / np.where(lengths == 0, 1.0, lengths)

    def agreement(matrix, average):
        return unit(matrix) @ unit(average)

    # Held against the average of them all, anything that is not a voice
    # falls far below the rest; then the average is taken again without it.
    against = agreement(vectors, vectors.mean(axis=0))
    kept = [index for index, score in enumerate(against) if score >= STRANGE_FILE]
    if not kept:
        raise RuntimeError("the files do not sound like one voice")
    skipped += [measured[index][0] for index in range(len(measured)) if index not in kept]
    vectors = vectors[kept]
    average = vectors.mean(axis=0)
    against = agreement(vectors, average)

    # The clip that stands closest to the result is the one the card keeps
    # to play back: what the player hears is the recording the fingerprint
    # is nearest to, not a clip chosen for being first.
    anchor = kept[int(np.argmax(against))]
    genders = [speaker_gender(measured[index][0]) for index in kept]
    heard = [gender for gender in genders if gender]
    return {
        "vector": [round(float(value), 6) for value in average],
        "gender": max(set(heard), key=heard.count) if heard else None,
        "seconds": round(sum(measured[index][2] for index in kept), 2),
        "used": len(kept),
        "skipped": skipped,
        "agreement": round(float(against.mean()), 3),
        "weakest": round(float(against.min()), 3),
        "together": bool(float(against.mean()) >= LOOSE_SET),
        "anchor": measured[anchor][0],
    }


# Two or more Latin letters in a translated line means a name came through
# untranslated, and the voice does not read Latin: measured, Silero drops the
# word without a sound -- "Добро пожаловать в Rapture." speaks for the same 0.95 s as
# "Добро пожаловать." alone -- and raises on a line that is Latin end to end,
# which reaches the player as a failure rather than as a line.
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


def readable(translated, source, translate, glossary=None):
    """[translated] with whatever the translator left in Latin script written
    so that the voice can say it."""
    if len(LATIN_RUN.findall(translated)) > 2:
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
        if not path:
            return
        try:
            with open(path, encoding="utf-8") as source:
                self.replace(json.load(source))
        except (OSError, ValueError):
            # A damaged file is a glossary the player has not written yet.
            pass

    @staticmethod
    def _key(source):
        return " ".join(str(source).lower().split())

    def replace(self, written):
        """Reads what the interface keeps, which is also what it sends when
        the player edits an entry while a session runs."""
        names, phrases, words = {}, {}, []
        for entry in (written or {}).get("entries") or []:
            source = str(entry.get("source") or "").strip()
            reading = str(entry.get("reading") or "").strip()
            if not source or not reading:
                continue
            kind = entry.get("kind")
            if kind == "word":
                # Compiled once: this runs over every line, and a word is
                # looked for whether or not it is there.
                words.append((re.compile(rf"\b{re.escape(source)}\b", re.IGNORECASE), reading))
            elif kind == "phrase":
                phrases[self._key(source)] = reading
            else:
                names[self._key(source)] = reading
        self.names, self.phrases, self.words = names, phrases, words

    def reading(self, word):
        """How the player says this Latin word, or None."""
        return self.names.get(self._key(word))

    def said(self, sentence):
        """The player's own translation of this sentence, or None."""
        return self.phrases.get(self._key(sentence))

    def worded(self, text):
        """[text] with the words the player renamed said their way.

        The whole word and nothing less, with the capital it was found under
        kept: a word at the head of a sentence is still at the head of it.
        """
        for pattern, reading in self.words:
            text = pattern.sub(lambda found: _like(reading, found.group(0)), text)
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

# Between the highest male and the lowest female voice measured in the Silero
# packages there is a wide gap; anything inside it is left undecided rather
# than guessed.
MALE_BELOW_HZ = 155.0
FEMALE_ABOVE_HZ = 175.0


def speaker_gender(path):
    """"male", "female", or None when the audio does not say."""
    try:
        samples, rate = read_wave_mono(path)
    except (OSError, wave.Error, ValueError):
        return None
    if samples is None or rate <= 0 or not len(samples):
        return None
    pitch = median_f0(samples, rate)
    if pitch is None:
        return None
    if pitch < MALE_BELOW_HZ:
        return "male"
    if pitch > FEMALE_ABOVE_HZ:
        return "female"
    return None


# A file dropped onto a card is kept unless it is plainly not a voice at
# all. Measured over 36 clips of five characters, decoded from ogg at the
# rate the capture works at: two clips of one character meet anywhere from
# 0.57 to 0.94, two clips of different characters at up to 0.80. The two
# spreads overlap, so no threshold tells a stranger from an odd line of the
# right character, and pretending otherwise would throw away good
# recordings. What a threshold does catch is audio that is not a voice at
# all -- music, a room, silence with a cough in it -- which never came near
# this number.
STRANGE_FILE = 0.45

# Under this the set does not hold together, and the player is told so
# rather than handed a fingerprint of nobody. One character's own clips sit
# at 0.875 to 0.932 around their average; two characters mixed by mistake,
# at 0.746 to 0.864.
LOOSE_SET = 0.80

# A clip shorter than this says nothing about a voice. It is what the
# capture keeps a segment from.
SHORTEST_CLIP = 0.35

# A line joins a stored voice from this cosine between fingerprints up.
# Measured on the OpenVoice demo speakers: two noisy lines of one person met
# at 0.86 and above, the closest two different people at 0.79. A miss only
# stores the same voice twice, while a false match would voice a character
# in someone else's timbre, so the bar sits above the rivals.
BANK_MATCH = 0.80

# Only a line this long founds a new voice: a shorter one gives a
# fingerprint that wanders, and it would then stand for the character.
BANK_MIN_SECONDS = 1.5

# A long game still fits; past this, new voices are used but not kept.
BANK_LIMIT = 256

# A segment shorter than this is one person talking: looking for a second
# voice in it would cost more than it could buy.
SPLIT_MIN_SECONDS = 3.0

# The stretch a voice is measured over, and how far that window steps.
SPLIT_WINDOW_SECONDS = 1.5
SPLIT_HOP_SECONDS = 0.5

# Neighbouring windows this far apart in cosine are two different people.
# Loose enough that the same voice raised or lowered stays one person.
SPLIT_DISTANCE = 0.25

# Neither side of a cut may be shorter than this, or recognition is handed
# half a word.
SPLIT_MIN_PIECE_SECONDS = 1.0

# How far around a change a quieter place to cut is looked for.
SPLIT_SNAP_SECONDS = 0.4


def speaker_cuts(converter, samples, rate):
    """The seconds where the voice in a recording changes.

    Windows of the recording are embedded with the same reference encoder
    that tells the characters apart, and a pair of neighbours far enough
    apart in cosine marks a change. Each cut is then moved to the quietest
    moment around it, so that a word is not sliced in half.
    """
    seconds = len(samples) / rate
    if seconds < SPLIT_MIN_SECONDS:
        return []
    window = int(rate * SPLIT_WINDOW_SECONDS)
    hop = int(rate * SPLIT_HOP_SECONDS)
    starts = list(range(0, max(1, len(samples) - window + 1), hop))
    if len(starts) < 2:
        return []
    vectors = []
    for start in starts:
        block = samples[start : start + window]
        fingerprint = converter.embed(block, rate).flatten().float().cpu().numpy()
        norm = float(np.linalg.norm(fingerprint)) or 1.0
        vectors.append(fingerprint / norm)
    cuts = []
    for index in range(1, len(vectors)):
        if 1.0 - float(np.dot(vectors[index - 1], vectors[index])) < SPLIT_DISTANCE:
            continue
        # The change happened somewhere in the overlap of the two windows.
        boundary = (starts[index] + window // 2) / rate
        cut = quietest_moment(samples, rate, boundary)
        if cut - (cuts[-1] if cuts else 0.0) < SPLIT_MIN_PIECE_SECONDS:
            continue
        if seconds - cut < SPLIT_MIN_PIECE_SECONDS:
            continue
        cuts.append(cut)
    return cuts


def quietest_moment(samples, rate, around):
    """The second nearest [around] where the recording is quietest."""
    frame = max(1, int(rate * 0.02))
    first = max(0, int((around - SPLIT_SNAP_SECONDS) * rate))
    last = min(len(samples) - frame, int((around + SPLIT_SNAP_SECONDS) * rate))
    if last <= first:
        return around
    quietest, lowest = around, None
    for start in range(first, last, frame):
        block = samples[start : start + frame]
        energy = float(np.sqrt(np.mean(block**2)))
        if lowest is None or energy < lowest:
            quietest, lowest = (start + frame / 2) / rate, energy
    return quietest


class VoiceBank:
    """The voices of one game's characters, kept between sessions.

    Every character holds a fingerprint, the gender heard in the line that
    founded them, and the Silero voice they were given. Nothing is averaged:
    the first clear line of a character stands for them, so their timbre,
    their gender and their voice stay the same from line to line and from one
    session to the next.
    """

    def __init__(self, path):
        # Without a path the bank lives for the session only: it still tells
        # speakers apart, and nothing is written.
        self.path = pathlib.Path(path) if path else None
        self.voices = []
        # One entry per voice: {"gender": str|None, "voice": str|None}.
        self.details = []
        if self.path is None:
            return
        try:
            data = json.loads(self.path.read_text(encoding="utf-8"))
            for voice in data.get("voices", []):
                # Version 1 wrote bare fingerprints; a bank from it keeps its
                # characters and earns their genders and voices again.
                detail = voice if isinstance(voice, dict) else {}
                vector = np.asarray(detail.get("vector", voice), dtype=np.float32)
                if vector.ndim == 1 and vector.size and np.all(np.isfinite(vector)):
                    self.voices.append(vector)
                    self.details.append(
                        {
                            "gender": detail.get("gender") or None,
                            "voice": detail.get("voice") or None,
                        }
                    )
        except (OSError, ValueError, AttributeError, TypeError):
            # A missing or damaged bank starts empty; the next voice rewrites it.
            self.voices = []
            self.details = []

    def __len__(self):
        return len(self.voices)

    def voice_of(self, index):
        """The Silero voice this character was given, if they have one."""
        return self.details[index]["voice"] if 0 <= index < len(self.details) else None

    def spoken_by(self, gender):
        """How many characters already read in a voice of [gender]."""
        return sum(1 for detail in self.details if detail["gender"] == gender)

    def remember(self, index, gender, voice):
        """Keeps the gender and voice a character's first clear line earned."""
        if not 0 <= index < len(self.details):
            return
        self.details[index] = {"gender": gender, "voice": voice}
        self.save()

    def nearest(self, vector):
        """The index of the stored voice closest to [vector] and its cosine."""
        best, score = None, -1.0
        norm = float(np.linalg.norm(vector)) or 1.0
        for index, voice in enumerate(self.voices):
            if voice.shape != vector.shape:
                continue
            value = float(np.dot(voice, vector)) / ((float(np.linalg.norm(voice)) or 1.0) * norm)
            if value > score:
                best, score = index, value
        return best, score

    def add(self, vector):
        self.voices.append(np.asarray(vector, dtype=np.float32))
        self.details.append({"gender": None, "voice": None})
        self.save()

    def save(self):
        if self.path is None:
            return
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            temporary = self.path.with_suffix(".tmp")
            voices = [
                {
                    "vector": [round(float(value), 6) for value in voice],
                    "gender": detail["gender"],
                    "voice": detail["voice"],
                }
                for voice, detail in zip(self.voices, self.details)
            ]
            temporary.write_text(json.dumps({"version": 2, "voices": voices}), encoding="utf-8")
            # Replaced in one step, so a crash mid-write leaves the old bank.
            os.replace(temporary, self.path)
        except OSError as error:
            # The voice still serves this session; losing the file must not
            # cost the line.
            sys.stderr.write(f"voice bank not saved: {error}\n")


class CharacterCast:
    """The characters the player recorded and named on the characters screen.

    They are shared by every game and matched before the game's own bank, and
    nothing here ever changes them: the player owns these cards, and a card
    the worker rewrote would drift away from what was recorded.
    """

    def __init__(self, path):
        self.entries = []
        if not path:
            return
        try:
            data = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return
        for entry in data.get("characters", []) if isinstance(data, dict) else []:
            if not isinstance(entry, dict):
                continue
            vector = np.asarray(entry.get("vector", []), dtype=np.float32)
            if vector.ndim != 1 or not vector.size or not np.all(np.isfinite(vector)):
                continue
            self.entries.append(
                {
                    "id": str(entry.get("id", "")),
                    "gender": entry.get("gender") or None,
                    "voice": entry.get("voice") or None,
                    # The card the player asked to be read in place of this
                    # one, wherever it is recognized.
                    "voicedBy": entry.get("voicedBy") or None,
                    "vector": vector,
                }
            )

    def __len__(self):
        return len(self.entries)

    def nearest(self, vector):
        """The character closest to [vector] and their cosine."""
        best, score = None, -1.0
        norm = float(np.linalg.norm(vector)) or 1.0
        for index, entry in enumerate(self.entries):
            kept = entry["vector"]
            if kept.shape != vector.shape:
                continue
            value = float(np.dot(kept, vector)) / ((float(np.linalg.norm(kept)) or 1.0) * norm)
            if value > score:
                best, score = index, value
        return best, score

    def identifier(self, index):
        return self.entries[index]["id"]

    def voice_of(self, index):
        return self.entries[index]["voice"]

    def gender_of(self, index):
        return self.entries[index]["gender"]

    def vector_of(self, index):
        return self.entries[index]["vector"]

    def voiced_by(self, index):
        """The card standing in for this one, if the player named one."""
        return self.entries[index]["voicedBy"] if 0 <= index < len(self.entries) else None

    def voice_instead(self, identifier, target):
        """Keeps a substitution the player made while this session runs."""
        for entry in self.entries:
            if entry["id"] == identifier:
                entry["voicedBy"] = target or None

    def index_of(self, identifier):
        """Where the card with this id sits, or None when it is not in the cast."""
        for index, entry in enumerate(self.entries):
            if entry["id"] == identifier:
                return index
        return None


def main():
    use_utf8_streams()
    parser = argparse.ArgumentParser()
    # Not needed by --embed-only, which loads the converter and nothing else.
    parser.add_argument("--translation-model", default="")
    parser.add_argument("--tts-model", default="")
    # Answer fingerprint requests and nothing else: the characters screen
    # records a voice without waiting a minute for Marian and Silero.
    parser.add_argument("--embed-only", action="store_true")
    # Answer preview requests: the speech model and the converter, without
    # the translator. The characters screen plays a sample of a voice with
    # it, which has nothing to translate.
    parser.add_argument("--speech-only", action="store_true")
    # The player's own characters, kept for every game rather than one.
    parser.add_argument("--characters", default="")
    # The names and phrases the player has written down, in one file for
    # every game the way the cast is.
    parser.add_argument("--glossary", default="")
    parser.add_argument("--work-directory", required=True)
    parser.add_argument("--threads", type=int, default=4)
    parser.add_argument("--speed", type=float, default=1.0)
    parser.add_argument("--speaker", default="xenia")
    parser.add_argument("--sample-rate", type=int, default=24000)
    parser.add_argument("--device", default="cpu", choices=["cpu", "cuda"])
    parser.add_argument("--extra-packages", default="")
    # Models that serve several target languages need one named in front of
    # the text, for example ">>rus<<".
    parser.add_argument("--translation-prefix", default="")
    # With --follow-speaker the voice is chosen per phrase from these two
    # lists, by the pitch of the original; otherwise --speaker is used as is.
    parser.add_argument("--follow-speaker", action="store_true")
    parser.add_argument("--male-voices", default="")
    parser.add_argument("--female-voices", default="")
    # The OpenVoice tone converter's directory. It is what hears who is
    # speaking, so it is loaded to tell the characters apart even when their
    # timbre is not carried over.
    parser.add_argument("--voice-converter", default="")
    # Carry the original's timbre onto the voice, which is the converter's
    # other half. Without it the converter only says who is speaking.
    parser.add_argument("--revoice", action="store_true")
    # The converter is placed apart from the translator: on the CPU it is
    # the slow half of a line, on a GPU next to nothing.
    parser.add_argument("--converter-device", default="cpu", choices=["cpu", "cuda"])
    # The game's voice bank. With it, a character met before is voiced with
    # the fingerprint kept for them instead of the one of the current line.
    parser.add_argument("--voice-bank", default="")
    # The cards taken out of the mix on the graph, by id, comma separated.
    # Each of them is read as it is heard: it lends its voice to nobody and
    # nobody stands in for it. Who stands in for whom is still in the cards;
    # none of it is applied to these while they are cut.
    parser.add_argument("--as-heard", default="")
    args = parser.parse_args()

    # Not a constant: a card may be cut from the mix and joined back to it
    # while the session runs, and the worker is told rather than restarted.
    as_heard = {name for name in args.as_heard.split(",") if name}

    speed = min(2.0, max(0.5, args.speed))

    # CUDA torch is installed next to the models instead of over the bundled
    # CPU build, so it has to win the import before torch is first touched.
    if args.extra_packages and pathlib.Path(args.extra_packages).is_dir():
        sys.path.insert(0, args.extra_packages)

    report_progress(0.10, "torch")
    import torch

    torch.set_num_threads(max(1, args.threads))
    # A CUDA build that cannot see the card is a working CPU build. Falling
    # back beats refusing to start over a driver the user cannot fix here.
    device = torch.device("cuda" if args.device == "cuda" and torch.cuda.is_available() else "cpu")
    # Translation has its own library now, so it has its own answer to where
    # it runs: it starts where torch did and drops to the processor on its
    # own if the card is not there for it.
    translation_device = device.type
    tokenizer = None
    translator = None
    tts = None
    voices = []
    speaker = args.speaker

    # Recording a character's voice needs the converter alone; loading the
    # translator and the speech model for it would cost the minute this
    # screen is meant to avoid.
    if not args.embed_only:
        # A voice preview has nothing to translate: it speaks a line the
        # application already wrote, so the translator is left out and the
        # screen waits seconds instead of a minute. Dubbing into English
        # leaves it out for the other reason -- whisper was asked for English
        # and handed it over, so no model is named and none is loaded.
        if not args.speech_only and args.translation_model:
            report_progress(0.35, "transformers")
            import ctranslate2
            from transformers import MarianTokenizer

            report_progress(0.80, "translator")
            # The tokenizer is still Marian's: the text has to be cut into the
            # pieces these weights were trained on. The weights themselves are
            # int8 CTranslate2 rather than a PyTorch checkpoint -- the same
            # model, read in about half the time and half the disk.
            tokenizer = MarianTokenizer.from_pretrained(
                args.translation_model, local_files_only=True
            )
            # A card the library cannot start on is a working CPU, the way a
            # CUDA torch that cannot see the card is.
            try:
                translator = ctranslate2.Translator(
                    args.translation_model,
                    device=translation_device,
                    compute_type="auto",
                    inter_threads=1,
                    intra_threads=max(1, args.threads),
                )
            except (RuntimeError, ValueError):
                translation_device = "cpu"
                translator = ctranslate2.Translator(
                    args.translation_model,
                    device="cpu",
                    compute_type="auto",
                    inter_threads=1,
                    intra_threads=max(1, args.threads),
                )

        report_progress(0.90, "speech")
        tts = torch.package.PackageImporter(args.tts_model).load_pickle("tts_models", "model")
        tts.to(torch.device("cpu"))
        # Loading the Silero package drops torch to a single thread, and that
        # holds for everything after it: the translator ran on one core, and
        # the voice converter took three times as long. The count goes back.
        torch.set_num_threads(max(1, args.threads))
        # Every Silero language ships its own voices. Falling back keeps an
        # unknown name from turning the whole language into a runtime error.
        voices = list(getattr(tts, "speakers", None) or [])
        speaker = args.speaker if args.speaker in voices else (voices[0] if voices else args.speaker)

    # The Silero voice picked below stays the base: the converter only moves
    # the original speaker's timbre onto it.
    converter = None
    bank = None
    if args.voice_converter:
        report_progress(0.95, "converter")
        sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
        from tone_converter import ToneConverter

        # The same fallback as the translator's: a card torch cannot see
        # leaves the converter on the CPU rather than the pipeline stopped.
        converter_device = torch.device(
            "cuda" if args.converter_device == "cuda" and torch.cuda.is_available() else "cpu"
        )
        converter = ToneConverter(args.voice_converter, converter_device)
        if args.voice_bank:
            bank = VoiceBank(args.voice_bank)

    # The catalogue names the voices, but only the package knows which of them
    # it really ships, so the two are intersected before anything is chosen.
    def available(names):
        return [name for name in names.split(",") if name and (not voices or name in voices)]

    by_gender = {
        "male": available(args.male_voices),
        "female": available(args.female_voices),
    }
    memory = TranslationMemory()
    glossary = Glossary(args.glossary)

    def translated_sentences(pieces):
        """Every one of [pieces] translated, in a single pass of the model."""
        asked = []
        for piece in pieces:
            prefix = args.translation_prefix
            prompt = f"{prefix} {piece}".strip() if prefix else piece
            # CTranslate2 works in tokens rather than in ids, so the tokenizer
            # is asked for both directions around it.
            asked.append(tokenizer.convert_ids_to_tokens(tokenizer.encode(prompt)))
        answered = translator.translate_batch(asked, beam_size=1, max_decoding_length=160)
        return [
            tokenizer.decode(
                tokenizer.convert_tokens_to_ids(one.hypotheses[0]), skip_special_tokens=True
            ).strip()
            for one in answered
        ]

    def translate(source):
        """[source] in the dubbing language, a sentence at a time."""
        pieces = sentences(source)
        # The player's own answer stands above both the model and what it
        # said last time, and is never written into the memory: it is already
        # an answer, and keeping it there would only age it.
        said = [glossary.said(piece) or memory.get(piece) for piece in pieces]
        asking = [piece for piece, kept in zip(pieces, said) if kept is None]
        if asking:
            answers = iter(translated_sentences(asking))
            for index, kept in enumerate(said):
                if kept is None:
                    said[index] = next(answers)
                    memory.put(pieces[index], said[index])
        return " ".join(piece for piece in said if piece)

    # Whether the dubbing language is written in Latin itself, asked of the
    # translator once. A Latin run means nothing in a German line, where every
    # word is one, and everything in a Russian line, where the voice cannot
    # read it -- and the rule that catches it ran over both, putting every
    # German line through the model a second time to throw the answer away.
    dubbed_in_latin = translator is None or bool(LATIN_RUN.search(translate("Open the door.")))

    following = args.follow_speaker and by_gender["male"] and by_gender["female"]
    # Sticky: an unclear phrase keeps the voice the last clear one settled on,
    # so a noisy line does not flip the character mid-conversation.
    current_voice = speaker

    # The timbre of the last phrase that had a voice in it. A line of music or
    # a short grunt keeps it, the same way the automatic choice keeps its voice.
    current_timbre = None

    # The characters this game's lines have been matched to — kept in its bank,
    # or in one that lasts only this session.
    speakers = bank if bank is not None else VoiceBank(None)

    # The player's own characters, recognized in whichever game they speak.
    cast = CharacterCast(args.characters)

    # Whose voice reads whom, as the player assigned it for this game.

    def speaker_key(kind, index):
        """What a line of this speaker is reported as, which is also what a
        replacement is made against."""
        if index is None:
            return None
        if kind == "character":
            return f"character:{cast.identifier(index)}"
        if kind == "voice":
            return f"timbre:{index}"
        return None

    def cut_from_mix(identifier):
        """Whether the card named is out of the mix on the graph."""
        return identifier is not None and identifier in as_heard

    def read_as(kind, index):
        """The character who reads this speaker: the card the graph gave them
        away to, or the speaker themselves.

        Only the voice and the timbre change. Who was heard is reported as it
        was heard, so the scene list keeps one row per voice of the game
        rather than gaining the character it is read in.
        """
        own = cast.identifier(index) if kind == "character" and index is not None else None
        # A card cut out of the mix speaks for itself and for nobody else.
        if cut_from_mix(own):
            return kind, index
        target = cast.voiced_by(index) if kind == "character" and index is not None else None
        # Nor does a card that was cut stand in for anybody.
        if cut_from_mix(target):
            return kind, index
        if target is None:
            return kind, index
        at = cast.index_of(target)
        # A card deleted since the assignment leaves the voice as itself.
        return ("character", at) if at is not None else (kind, index)

    def identify(request):
        """The character this line belongs to and the fingerprint read from
        it, as (index, fingerprint).

        The kind is "character" for one of the player's own cards, "voice"
        for a speaker of this game's bank. All three are None without the
        converter, which is what hears who is speaking, and for a line too
        short or too unvoiced to place.
        """
        source = request.get("wave")
        if converter is None or not source:
            return None, None, None
        try:
            samples, rate = read_wave_mono(source)
        except (OSError, wave.Error, ValueError):
            return None, None, None
        if (
            samples is None
            or rate <= 0
            or len(samples) < rate // 2
            or median_f0(samples, rate) is None
        ):
            return None, None, None
        fingerprint = converter.embed(samples, rate)
        # A character the player recorded answers before the game's own bank:
        # they named this voice, so it is theirs whichever game it speaks in.
        named, score = cast.nearest(fingerprint.flatten().float().cpu().numpy())
        if named is not None and score >= BANK_MATCH:
            return "character", named, fingerprint
        # A short line nobody matched could be anyone.
        return "voice", speaker_of(fingerprint, len(samples) / rate), fingerprint

    def speaker_of(fingerprint, seconds):
        """The index of the voice this line belongs to; a new one is kept first."""
        vector = fingerprint.flatten().float().cpu().numpy()
        index, score = speakers.nearest(vector)
        if index is not None and score >= BANK_MATCH:
            return index
        if seconds >= BANK_MIN_SECONDS and len(speakers) < BANK_LIMIT:
            speakers.add(vector)
            return len(speakers) - 1
        return None

    def voice_for(request, kind, index):
        """The voice this line is read in.

        One of the player's cards is read in its own voice, whoever it is
        standing in for; a character of the game's bank keeps the voice their
        first clear line earned, so the same person is never read by two
        voices; and a line belonging to nobody falls back to the gender heard
        in the line itself.
        """
        nonlocal current_voice
        if not following:
            return speaker
        if kind == "character" and index is not None:
            chosen = voice_for_character(
                cast.voice_of(index), cast.gender_of(index), index, by_gender
            )
            if chosen is not None:
                current_voice = chosen
                return chosen
        if kind == "voice" and index is not None:
            kept = speakers.voice_of(index)
            # A bank filled for another language package names voices this
            # one does not ship.
            if kept in by_gender["male"] or kept in by_gender["female"]:
                current_voice = kept
                return kept
        source = request.get("wave")
        gender = speaker_gender(source) if source else None
        if gender is None:
            return current_voice
        candidates = by_gender[gender]
        if index is None or kind != "voice":
            # Keep the configured voice when it already matches the gender.
            current_voice = speaker if speaker in candidates else candidates[0]
            return current_voice
        # A voice of their own: two men in a scene are read by different
        # voices, and the list wraps once the cast outgrows it.
        current_voice = candidates[speakers.spoken_by(gender) % len(candidates)]
        speakers.remember(index, gender, current_voice)
        return current_voice

    def timbre_for(fingerprint, kind, index):
        """The timbre to re-voice a line in: the character's kept one, or the
        fingerprint of the line itself."""
        nonlocal current_timbre
        if fingerprint is None:
            return current_timbre
        current_timbre = fingerprint
        if kind == "character" and index is not None:
            kept = torch.from_numpy(cast.vector_of(index)).reshape(fingerprint.shape)
            current_timbre = kept.to(device=fingerprint.device, dtype=fingerprint.dtype)
            return current_timbre
        if kind == "voice" and bank is not None and index is not None:
            kept = torch.from_numpy(bank.voices[index]).reshape(fingerprint.shape)
            current_timbre = kept.to(device=fingerprint.device, dtype=fingerprint.dtype)
        return current_timbre

    pathlib.Path(args.work_directory).mkdir(parents=True, exist_ok=True)
    # The device is reported back rather than assumed: a CUDA build that fell
    # back to the CPU must not leave the interface claiming the GPU is in use.
    ready = {"type": "ready", "device": translation_device}
    if converter is not None:
        ready["converterDevice"] = converter.device.type
    reply(ready)

    for raw_line in sys.stdin:
        # A malformed line must not take the worker down with it: the pipeline
        # would then look alive while every later phrase is lost.
        line = raw_line.strip().lstrip("\ufeff")
        if not line:
            continue
        try:
            request = json.loads(line)
            request_id = request["id"]
        except (ValueError, KeyError) as error:
            reply({"type": "error", "message": f"malformed request: {error}"})
            continue
        try:
            # The voice in a recording, as the characters screen keeps it.
            recorded = request.get("fingerprint")
            if recorded:
                if converter is None:
                    raise RuntimeError("the voice converter is not loaded")
                heard, rate = read_wave_mono(recorded)
                if heard is None or rate <= 0 or not len(heard):
                    raise RuntimeError(f"unreadable recording: {recorded}")
                vector = converter.embed(heard, rate).flatten().float().cpu().numpy()
                reply(
                    {
                        "id": request_id,
                        "vector": [round(float(value), 6) for value in vector],
                        "gender": speaker_gender(recorded),
                        "seconds": round(len(heard) / rate, 2),
                    }
                )
                continue
            # A card built from the files the player dropped onto it.
            gathered = request.get("voiceFrom")
            if gathered:
                if converter is None:
                    raise RuntimeError("the voice converter is not loaded")
                reply({"id": request_id, **build_voice(converter, [str(p) for p in gathered])})
                continue
            # A card read in another's voice from now on, as the characters
            # screen has just been told. The cast was read at start, so a
            # session already running is told rather than left behind.
            substitution = request.get("voicedBy")
            if substitution is not None:
                cast.voice_instead(
                    str(substitution.get("character", "")),
                    str(substitution.get("target", "")),
                )
                reply({"id": request_id, "voiced": True})
                continue
            # The cards taken out of the mix on the graph, as the canvas
            # now draws them. The cards keep who stands in for whom either
            # way; this is only which of it is applied.
            # What the player wrote down, as they wrote it: the file is read
            # when a session starts, so this is what carries an entry added
            # while one runs. A line already dubbed is not dubbed again, but
            # the next time the game says it, it is said their way.
            written_down = request.get("glossary")
            if written_down is not None:
                glossary.replace(written_down)
                reply({"id": request_id, "glossary": len(glossary)})
                continue
            heard_as_itself = request.get("asHeard")
            if heard_as_itself is not None:
                as_heard = {str(name) for name in heard_as_itself}
                reply({"id": request_id, "asHeard": sorted(as_heard)})
                continue
            # Who is speaking, and nothing else. Live asks this before the
            # dubbing itself runs, so the player can hand out the voices of
            # a scene while only the converter is loaded.
            heard_line = request.get("listen")
            if heard_line:
                if converter is None:
                    raise RuntimeError("the voice converter is not loaded")
                kind, index, _ = identify({"wave": heard_line})
                answer = {"id": request_id, "speaker": speaker_key(kind, index)}
                # The card the graph gave this one away to, if it did and if
                # the cast is in the mix at all.
                read_kind, read_index = read_as(kind, index)
                if (read_kind, read_index) != (kind, index):
                    answer["readAs"] = speaker_key(read_kind, read_index)
                try:
                    samples, rate = read_wave_mono(heard_line)
                    answer["seconds"] = round(len(samples) / rate, 2) if rate else 0
                except (OSError, wave.Error, ValueError):
                    answer["seconds"] = 0
                reply(answer)
                continue
            # A sample of one voice, which the characters screen plays so the
            # player can hear a card before a word of the game is dubbed.
            sample = request.get("preview")
            if sample is not None:
                if tts is None:
                    raise RuntimeError("the speech model is not loaded")
                chosen = str(sample.get("voice") or speaker)
                if voices and chosen not in voices:
                    chosen = speaker
                audio = tts.apply_tts(
                    text=str(sample.get("text", "")).strip(),
                    speaker=chosen,
                    sample_rate=args.sample_rate,
                    put_accent=True,
                    put_yo=True,
                )
                samples = audio.clamp(-1, 1).to(torch.float32).cpu().numpy()
                rate = args.sample_rate
                # The card's own timbre over that voice, which is what the
                # dubbing will do with it.
                vector = sample.get("vector")
                if converter is not None and vector:
                    timbre = torch.from_numpy(
                        np.asarray(vector, dtype=np.float32)
                    ).reshape(1, -1, 1)
                    samples, rate = converter.convert(
                        samples, rate, timbre.to(device=converter.device, dtype=torch.float32)
                    )
                samples = change_speed(samples, request_speed(request, speed), rate)
                pcm = np.clip(samples * 32767.0, -32768, 32767).astype(np.int16).tobytes()
                output = pathlib.Path(args.work_directory) / f"preview-{request_id}.wav"
                with wave.open(str(output), "wb") as stream:
                    stream.setnchannels(1)
                    stream.setsampwidth(2)
                    stream.setframerate(rate)
                    stream.writeframes(pcm)
                reply({"id": request_id, "wave": str(output), "voice": chosen})
                continue
            # Where does the voice change? Asked before recognition, so each
            # speaker's half is recognized and voiced on its own.
            listening = request.get("diarize")
            if listening:
                cuts = []
                if converter is not None:
                    try:
                        heard, rate = read_wave_mono(listening)
                    except (OSError, wave.Error, ValueError):
                        heard, rate = None, 0
                    if heard is not None and rate > 0 and len(heard):
                        cuts = speaker_cuts(converter, heard, rate)
                reply({"id": request_id, "cuts": [round(cut, 3) for cut in cuts]})
                continue
            text = request["text"].strip()
            # Text read off the screen in the dubbing language itself has
            # nothing to be translated and is voiced as it is, and so is
            # everything in a session started without a translator at all.
            if request.get("translate", True) and translator is not None:
                translated = translate(text)
                # A capitalised name is occasionally carried over untranslated,
                # and a voice that reads no Latin cannot say it.
                if not dubbed_in_latin and LATIN_TEXT.search(translated):
                    translated = readable(translated, text, translate, glossary)
            else:
                translated = text
            # Whatever is about to be said, translated here or read off the
            # screen already in the dubbing language: these are words of that
            # language either way.
            translated = glossary.worded(translated)
            # Who is speaking is settled first: the character decides both the
            # voice they are read in and the timbre laid over it.
            heard_kind, heard_index, fingerprint = identify(request)
            kind, index = read_as(heard_kind, heard_index)
            chosen = voice_for(request, kind, index)
            audio = tts.apply_tts(
                text=translated,
                speaker=chosen,
                sample_rate=args.sample_rate,
                put_accent=True,
                put_yo=True,
            )
            samples = audio.clamp(-1, 1).to(torch.float32).cpu().numpy()
            rate = args.sample_rate
            timbre = timbre_for(fingerprint, kind, index) if args.revoice else None
            if timbre is not None:
                # The converter answers at its own rate; the file is written at it.
                samples, rate = converter.convert(samples, rate, timbre)
            # Hurried while other lines are already waiting for the voice,
            # so that the dubbing does not fall further behind the game.
            samples = change_speed(samples, request_speed(request, speed), rate)
            pcm = np.clip(samples * 32767.0, -32768, 32767).astype(np.int16).tobytes()
            output = pathlib.Path(args.work_directory) / f"speech-{request_id}.wav"
            with wave.open(str(output), "wb") as stream:
                stream.setnchannels(1)
                stream.setsampwidth(2)
                stream.setframerate(rate)
                stream.writeframes(pcm)
            answer = {
                "id": request_id,
                "translated": translated,
                "wave": str(output),
                "voice": chosen,
                "cloned": timbre is not None,
            }
            # Reported as it was heard, not as it was read: the scene list
            # offers a replacement against the voice of the game.
            heard = speaker_key(heard_kind, heard_index)
            if heard is not None:
                answer["speaker"] = heard
                if (kind, index) != (heard_kind, heard_index) and index is not None:
                    answer["readAs"] = f"character:{cast.identifier(index)}"
            elif converter is None:
                # Nothing heard who is speaking, so the Silero voice is all
                # that tells lines apart: men from women and nothing more.
                answer["speaker"] = f"voice:{chosen}"
            if bank is not None:
                answer["bankSize"] = len(bank)
            reply(answer)
        except Exception as error:
            reply({"id": request_id, "error": str(error)})


if __name__ == "__main__":
    main()

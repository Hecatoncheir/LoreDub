# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

"""Who is speaking: the voices a game's bank keeps, the player's own cast,
a card built from files, and the voice package a session reads in."""

import json
import os
import pathlib
import sys

import numpy as np

from audio import (
    as_vector,
    read_clip,
    speaker_gender,
)


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


def most_heard(genders, tie=None):
    """The gender most of [genders] were heard as, or [tie] where two are
    heard as often -- rather than whichever a set happened to hand back
    first, which changed from one run of the worker to the next."""
    heard = [gender for gender in genders if gender]
    if not heard:
        return None
    counts = {gender: heard.count(gender) for gender in heard}
    top = max(counts.values())
    leaders = [gender for gender, count in counts.items() if count == top]
    if len(leaders) == 1:
        return leaders[0]
    return tie if tie in leaders else leaders[0]


def nearest(vectors, vector):
    """The index of the one of [vectors] closest to [vector], and its cosine;
    None where no vector has its shape."""
    best, score = None, -1.0
    norm = float(np.linalg.norm(vector)) or 1.0
    for index, kept in enumerate(vectors):
        if kept.shape != vector.shape:
            continue
        value = float(np.dot(kept, vector)) / ((float(np.linalg.norm(kept)) or 1.0) * norm)
        if value > score:
            best, score = index, value
    return best, score


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
    measured, skipped = measure_clips(converter, paths)
    kept = without_strangers(measured)
    skipped += [measured[index][0] for index in range(len(measured)) if index not in kept]
    return voice_report(measured, kept, skipped)


def measure_clips(converter, paths):
    """The fingerprint and length of every one of [paths] that holds enough
    voice to measure, as (path, fingerprint, seconds), and the ones that do
    not."""
    measured = []
    skipped = []
    for path in paths:
        samples, rate = read_clip(path)
        if samples is None or len(samples) < rate * SHORTEST_CLIP:
            skipped.append(path)
            continue
        # Kept as the encoder gave it. The card's vector is not only
        # something to recognize a speaker by -- it is the conditioning the
        # converter is re-voiced against -- and that one has a length as
        # well as a direction.
        fingerprint = as_vector(converter.embed(samples, rate))
        measured.append((path, fingerprint, len(samples) / rate))
    if not measured:
        raise RuntimeError("none of the files held enough voice to measure")
    return measured, skipped


def unit(matrix):
    """The same vectors at length one, which is what comparing them means;
    the average itself is never kept this way."""
    lengths = np.linalg.norm(matrix, axis=-1, keepdims=True)
    return matrix / np.where(lengths == 0, 1.0, lengths)


def agreement(matrix, average):
    """How close each of [matrix] stands to [average], as a cosine."""
    return unit(matrix) @ unit(average)


def without_strangers(measured):
    """The indices of the clips that sound like the rest. Held against the
    average of them all, anything that is not a voice falls far below it."""
    vectors = np.stack([vector for _, vector, _ in measured])
    against = agreement(vectors, vectors.mean(axis=0))
    kept = [index for index, score in enumerate(against) if score >= STRANGE_FILE]
    if not kept:
        raise RuntimeError("the files do not sound like one voice")
    return kept


def voice_report(measured, kept, skipped):
    """The card the [kept] clips make, averaged again without the strangers,
    and how well they agreed."""
    vectors = np.stack([measured[index][1] for index in kept])
    average = vectors.mean(axis=0)
    against = agreement(vectors, average)
    # The clip that stands closest to the result is the one the card keeps
    # to play back: what the player hears is the recording the fingerprint
    # is nearest to, not a clip chosen for being first.
    anchor = kept[int(np.argmax(against))]
    genders = {index: speaker_gender(measured[index][0]) for index in kept}
    return {
        "vector": [round(float(value), 6) for value in average],
        "gender": most_heard(list(genders.values()), tie=genders[anchor]),
        "seconds": round(sum(measured[index][2] for index in kept), 2),
        "used": len(kept),
        "skipped": skipped,
        "agreement": round(float(against.mean()), 3),
        "weakest": round(float(against.min()), 3),
        "together": bool(float(against.mean()) >= LOOSE_SET),
        "anchor": measured[anchor][0],
    }


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


class VoiceBank:
    """The voices of one game's characters, kept between sessions.

    Every character holds a fingerprint, the gender heard in the line that
    founded them, and the voice they were given. Nothing is averaged:
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
        """The voice this character was given, if they have one."""
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
        return nearest(self.voices, vector)

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
        return nearest([entry["vector"] for entry in self.entries], vector)

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


def load_voice(path, threads, device):
    """The voice the package asks for.

    Which wrapper reads a speech package is the package's own answer rather
    than a flag from the application: a Kokoro one carries its voices in
    `voices.bin` beside the model, a Vosk one a `config.json` and a
    `dictionary`. Both are named by their first file, `model.onnx`, so the
    name says nothing.
    """
    directory = pathlib.Path(path)
    directory = directory.parent if directory.suffix == ".onnx" else directory
    if (directory / "voices.bin").is_file():
        from kokoro_voice import KokoroVoice

        return KokoroVoice(path, threads=threads, device=device)
    from vosk_voice import VoskVoice

    return VoskVoice(path, threads=threads, device=device)

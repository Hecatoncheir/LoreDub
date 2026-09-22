# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

"""Persistent, line-delimited JSON worker for Marian and the Vosk-TTS voice."""

import argparse
import json
import os
import pathlib
import sys
import wave

import numpy as np

# The worker's own modules sit beside it. The embedded interpreter's ._pth
# file turns off putting the script's directory on the path, so it is put
# there by hand, before the first of them is imported.
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from dubbing_text import (
    Glossary,
    LATIN_RUN,
    LATIN_TEXT,
    TranslationMemory,
    readable,
    sentences,
)

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


# Where the replies go. The protocol is the process's stdout and nothing
# else writes to it: claim_protocol() moves sys.stdout onto stderr, so a
# library that prints -- a warning, a progress bar without a line ending --
# lands among the diagnostics rather than inside the next reply.
PROTOCOL = sys.stdout


def claim_protocol():
    """Keeps stdout for replies alone, and sends every other print to stderr."""
    global PROTOCOL
    PROTOCOL = sys.stdout
    sys.stdout = sys.stderr


def reply(value):
    PROTOCOL.write(json.dumps(value, ensure_ascii=False) + "\n")
    PROTOCOL.flush()


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

    The voice's own rate is left alone, so the synthesized waveform is
    retimed here.
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


# How far a line's pace may be taken either way: past these the WSOLA
# retiming is heard as the voice stuttering or smearing.
SLOWEST_SPEED = 0.5
FASTEST_SPEED = 2.0


def clamped_speed(value):
    return min(FASTEST_SPEED, max(SLOWEST_SPEED, value))


def request_speed(request, fallback):
    """The pace this one line asks to be read at.

    The queue of lines waiting for the voice is a moment's business rather
    than a setting, so the pace travels with the line instead of being fixed
    when the worker starts. Anything unreadable leaves the session's own.
    """
    try:
        return clamped_speed(float(request["speed"]))
    except (KeyError, TypeError, ValueError):
        return fallback


def write_wave(path, samples, rate):
    """[samples] in [-1, 1] written as 16-bit mono PCM at [rate]."""
    pcm = np.clip(samples * 32767.0, -32768, 32767).astype(np.int16).tobytes()
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(rate)
        stream.writeframes(pcm)


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


def read_clip(path):
    """The recording at [path] as (samples, rate), or (None, 0) when there is
    nothing in it to hear: missing, damaged, not 16-bit, or empty."""
    try:
        samples, rate = read_wave_mono(path)
    except (OSError, wave.Error, ValueError):
        return None, 0
    if samples is None or rate <= 0 or not len(samples):
        return None, 0
    return samples, rate


def as_vector(fingerprint):
    """What the encoder answered, as the flat array it is kept and compared as."""
    return fingerprint.flatten().float().cpu().numpy()


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


# Between the highest male and the lowest female voice measured in the Silero
# packages LoreDub used to carry there is a wide gap; anything inside it is left undecided rather
# than guessed.
MALE_BELOW_HZ = 155.0
FEMALE_ABOVE_HZ = 175.0


def gender_of_pitch(pitch):
    """"male", "female", or None for a pitch between the two, or none."""
    if pitch is None:
        return None
    if pitch < MALE_BELOW_HZ:
        return "male"
    if pitch > FEMALE_ABOVE_HZ:
        return "female"
    return None


def speaker_gender(path):
    """"male", "female", or None when the audio does not say."""
    samples, rate = read_clip(path)
    return gender_of_pitch(median_f0(samples, rate)) if samples is not None else None


class Heard:
    """The recording a line came with, read and measured once, and only if
    something asks: who is speaking and which voice reads them both want the
    samples and the pitch, and each read the file and measured it for itself."""

    def __init__(self, source):
        self.source = source or None
        self._clip = None
        self._pitch = None
        self._measured = False

    @property
    def clip(self):
        if self._clip is None:
            self._clip = read_clip(self.source) if self.source else (None, 0)
        return self._clip

    @property
    def pitch(self):
        if not self._measured:
            samples, rate = self.clip
            self._pitch = median_f0(samples, rate) if samples is not None else None
            self._measured = True
        return self._pitch

    @property
    def gender(self):
        return gender_of_pitch(self.pitch)


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
        fingerprint = as_vector(converter.embed(block, rate))
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


def parse_arguments(argv=None):
    parser = argparse.ArgumentParser()
    # Not needed by --embed-only, which loads the converter and nothing else.
    parser.add_argument("--translation-model", default="")
    parser.add_argument("--tts-model", default="")
    # Answer fingerprint requests and nothing else: the characters screen
    # records a voice without waiting a minute for Marian and the voice.
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
    parser.add_argument("--speaker", default="female_1")
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
    # The voice has its own answer too: measured, Vosk reads a line in 280 to
    # 330 ms on the card against 850 to 920 on twelve processor threads.
    parser.add_argument("--speech-device", default="cpu", choices=["cpu", "cuda"])
    # The game's voice bank. With it, a character met before is voiced with
    # the fingerprint kept for them instead of the one of the current line.
    parser.add_argument("--voice-bank", default="")
    # The cards taken out of the mix on the graph, by id, comma separated.
    # Each of them is read as it is heard: it lends its voice to nobody and
    # nobody stands in for it. Who stands in for whom is still in the cards;
    # none of it is applied to these while they are cut.
    parser.add_argument("--as-heard", default="")
    return parser.parse_args(argv)


class Models:
    """What a session loaded, and where each part of it runs."""

    def __init__(self, args):
        # CUDA torch is installed next to the models instead of over the
        # bundled CPU build, so it has to win the import before torch is first
        # touched.
        if args.extra_packages and pathlib.Path(args.extra_packages).is_dir():
            sys.path.insert(0, args.extra_packages)

        report_progress(0.10, "torch")
        import torch

        self.torch = torch
        torch.set_num_threads(max(1, args.threads))
        # A CUDA build that cannot see the card is a working CPU build.
        # Falling back beats refusing to start over a driver the user cannot
        # fix here.
        device = torch.device("cuda" if args.device == "cuda" and torch.cuda.is_available() else "cpu")
        # Translation has its own library now, so it has its own answer to
        # where it runs: it starts where torch did and drops to the processor
        # on its own if the card is not there for it.
        self.translation_device = device.type
        self.tokenizer = None
        self.translator = None
        self.tts = None
        self.speech_device = None
        self.voices = []
        self.speaker = args.speaker
        # Recording a character's voice needs the converter alone; loading
        # the translator and the speech model for it would cost the minute
        # this screen is meant to avoid.
        if not args.embed_only:
            # A voice preview has nothing to translate: it speaks a line the
            # application already wrote, so the translator is left out and the
            # screen waits seconds instead of a minute. Dubbing into English
            # leaves it out for the other reason -- whisper was asked for
            # English and handed it over, so no model is named and none is
            # loaded.
            if not args.speech_only and args.translation_model:
                self._load_translator(args)
            report_progress(0.90, "speech")
            # torch is imported already, so onnxruntime-gpu finds the CUDA and
            # cuDNN libraries it brought. Without the card -- or with the
            # processor's build of onnxruntime, which is all a machine without
            # the CUDA runtime has -- the voice falls back to the processor,
            # and the ready line says where it really is.
            self.tts = load_voice(args.tts_model, threads=args.threads, device=args.speech_device)
            self.speech_device = torch.device(self.tts.device)
            # An unknown name falls back to the package's first voice rather
            # than turning the whole session into a runtime error.
            self.voices = list(self.tts.speakers)
            if args.speaker not in self.voices and self.voices:
                self.speaker = self.voices[0]
        # The voice picked below stays the base: the converter only moves the
        # original speaker's timbre onto it.
        self.converter = None
        self.bank = None
        if args.voice_converter:
            report_progress(0.95, "converter")
            from tone_converter import ToneConverter

            # The same fallback as the translator's: a card torch cannot see
            # leaves the converter on the CPU rather than the pipeline stopped.
            converter_device = torch.device(
                "cuda" if args.converter_device == "cuda" and torch.cuda.is_available() else "cpu"
            )
            self.converter = ToneConverter(args.voice_converter, converter_device)
            if args.voice_bank:
                self.bank = VoiceBank(args.voice_bank)

    def _load_translator(self, args):
        report_progress(0.35, "transformers")
        import ctranslate2
        from transformers import MarianTokenizer

        report_progress(0.80, "translator")
        # The tokenizer is still Marian's: the text has to be cut into the
        # pieces these weights were trained on. The weights themselves are
        # int8 CTranslate2 rather than a PyTorch checkpoint -- the same model,
        # read in about half the time and half the disk.
        self.tokenizer = MarianTokenizer.from_pretrained(args.translation_model, local_files_only=True)

        def translator_on(device):
            return ctranslate2.Translator(
                args.translation_model,
                device=device,
                compute_type="auto",
                inter_threads=1,
                intra_threads=max(1, args.threads),
            )

        # A card the library cannot start on is a working CPU, the way a CUDA
        # torch that cannot see the card is.
        try:
            self.translator = translator_on(self.translation_device)
        except (RuntimeError, ValueError):
            self.translation_device = "cpu"
            self.translator = translator_on("cpu")

    def ready_line(self):
        """The handshake. The device is reported back rather than assumed: a
        CUDA build that fell back to the CPU must not leave the interface
        claiming the GPU is in use."""
        ready = {"type": "ready", "device": self.translation_device}
        if self.speech_device is not None:
            ready["speechDevice"] = self.speech_device.type
        if self.converter is not None:
            ready["converterDevice"] = self.converter.device.type
        return ready


# The longest reply the translator writes for one sentence, in tokens: past
# it a sentence is being repeated back rather than translated.
MAX_DECODING_TOKENS = 160


class Translation:
    """A line in the dubbing language, a sentence at a time: the player's own
    answer first, then what was said last time, then the model."""

    def __init__(self, models, prefix, glossary):
        self._tokenizer = models.tokenizer
        self._translator = models.translator
        self._prefix = prefix
        self._glossary = glossary
        self._memory = TranslationMemory()
        # Whether the dubbing language is written in Latin itself, asked of
        # the translator once. A Latin run means nothing in a German line,
        # where every word is one, and everything in a Russian line, where the
        # voice cannot read it -- and the rule that catches it ran over both,
        # putting every German line through the model a second time to throw
        # the answer away. The model is asked directly rather than through
        # [translate]: the player's glossary answers first there, and a probe
        # line the player wrote down -- or silenced -- would decide the script
        # of every line after.
        self.dubbed_in_latin = self._translator is None or bool(
            LATIN_RUN.search(self._sentences(["Open the door."])[0])
        )

    @property
    def available(self):
        return self._translator is not None

    def _sentences(self, pieces):
        """Every one of [pieces] translated, in a single pass of the model."""
        asked = []
        for piece in pieces:
            prompt = f"{self._prefix} {piece}".strip() if self._prefix else piece
            # CTranslate2 works in tokens rather than in ids, so the tokenizer
            # is asked for both directions around it.
            asked.append(self._tokenizer.convert_ids_to_tokens(self._tokenizer.encode(prompt)))
        answered = self._translator.translate_batch(
            asked, beam_size=1, max_decoding_length=MAX_DECODING_TOKENS
        )
        return [
            self._tokenizer.decode(
                self._tokenizer.convert_tokens_to_ids(one.hypotheses[0]), skip_special_tokens=True
            ).strip()
            for one in answered
        ]

    def translate(self, source):
        """[source] in the dubbing language, a sentence at a time."""
        pieces = sentences(source)
        # The player's own answer stands above both the model and what it
        # said last time, and is never written into the memory: it is already
        # an answer, and keeping it there would only age it. Asked rather
        # than taken with `or`: a silenced phrase answers with an empty
        # string on purpose, and `or` would fall through to the model.
        said = []
        for piece in pieces:
            written = self._glossary.said(piece)
            said.append(written if written is not None else self._memory.get(piece))
        asking = [piece for piece, kept in zip(pieces, said) if kept is None]
        if asking:
            answers = iter(self._sentences(asking))
            for index, kept in enumerate(said):
                if kept is None:
                    said[index] = next(answers)
                    self._memory.put(pieces[index], said[index])
        return " ".join(piece for piece in said if piece)

    def line(self, text):
        """[text] as it is to be said: translated, what was left in Latin
        written out, and the words the player renamed said their way."""
        translated = self.translate(text)
        # A capitalised name is occasionally carried over untranslated, and a
        # voice that reads no Latin cannot say it.
        if not self.dubbed_in_latin and LATIN_TEXT.search(translated):
            translated = readable(translated, text, self.translate, self._glossary)
        return translated


class Casting:
    """Who is speaking a line, whose voice reads it and in which timbre.

    The converter is what hears who is speaking; without it nobody is placed
    and the voice follows the pitch of each line alone. What it settles is
    sticky: an unclear phrase keeps the voice and the timbre the last clear
    one had, so a noisy line does not flip a character mid-conversation.
    """

    def __init__(self, args, models):
        self._torch = models.torch
        self._converter = models.converter
        self._bank = models.bank
        self.voices = models.voices
        # The voice a line is read in where nothing chooses another.
        self.speaker = models.speaker

        # The catalogue names the voices, but only the package knows which of
        # them it really ships, so the two are intersected before anything is
        # chosen.
        def available(names):
            return [name for name in names.split(",") if name and (not self.voices or name in self.voices)]

        self.by_gender = {"male": available(args.male_voices), "female": available(args.female_voices)}
        self._following = args.follow_speaker and self.by_gender["male"] and self.by_gender["female"]
        self._current_voice = self.speaker
        # The timbre of the last phrase that had a voice in it. A line of
        # music or a short grunt keeps it, the same way the automatic choice
        # keeps its voice.
        self._current_timbre = None
        # The characters this game's lines have been matched to -- kept in its
        # bank, or in one that lasts only this session.
        self.speakers = self._bank if self._bank is not None else VoiceBank(None)
        # The player's own characters, recognized in whichever game they speak.
        self.cast = CharacterCast(args.characters)
        # Not a constant: a card may be cut from the mix and joined back to it
        # while the session runs, and the worker is told rather than restarted.
        self.as_heard = {name for name in args.as_heard.split(",") if name}

    def use_voice(self, name):
        """Reads the lines that follow in [name], where the package has it."""
        if name in self.voices:
            self.speaker = name
            self._current_voice = name
        return self.speaker

    def speaker_key(self, kind, index):
        """What a line of this speaker is reported as, which is also what a
        replacement is made against."""
        if index is None:
            return None
        if kind == "character":
            return f"character:{self.cast.identifier(index)}"
        if kind == "voice":
            return f"timbre:{index}"
        return None

    def _cut_from_mix(self, identifier):
        """Whether the card named is out of the mix on the graph."""
        return identifier is not None and identifier in self.as_heard

    def read_as(self, kind, index):
        """The character who reads this speaker: the card the graph gave them
        away to, or the speaker themselves.

        Only the voice and the timbre change. Who was heard is reported as it
        was heard, so the scene list keeps one row per voice of the game
        rather than gaining the character it is read in.
        """
        is_card = kind == "character" and index is not None
        own = self.cast.identifier(index) if is_card else None
        # A card cut out of the mix speaks for itself and for nobody else.
        if self._cut_from_mix(own):
            return kind, index
        target = self.cast.voiced_by(index) if is_card else None
        # Nor does a card that was cut stand in for anybody.
        if target is None or self._cut_from_mix(target):
            return kind, index
        at = self.cast.index_of(target)
        # A card deleted since the assignment leaves the voice as itself.
        return ("character", at) if at is not None else (kind, index)

    def identify(self, heard):
        """The speaker of the recording [heard] and the fingerprint read from
        it, as (kind, index, fingerprint).

        The kind is "character" for one of the player's own cards, "voice" for
        a speaker of this game's bank. All three are None without the
        converter, which is what hears who is speaking, and for a line too
        short or too unvoiced to place.
        """
        if self._converter is None or heard.source is None:
            return None, None, None
        samples, rate = heard.clip
        # Half a second, and a voice in it: anything less could be anyone.
        if samples is None or len(samples) < rate // 2 or heard.pitch is None:
            return None, None, None
        fingerprint = self._converter.embed(samples, rate)
        # A character the player recorded answers before the game's own bank:
        # they named this voice, so it is theirs whichever game it speaks in.
        named, score = self.cast.nearest(as_vector(fingerprint))
        if named is not None and score >= BANK_MATCH:
            return "character", named, fingerprint
        # A short line nobody matched could be anyone.
        return "voice", self._speaker_of(fingerprint, len(samples) / rate), fingerprint

    def _speaker_of(self, fingerprint, seconds):
        """The index of the voice this line belongs to; a new one is kept first."""
        vector = as_vector(fingerprint)
        index, score = self.speakers.nearest(vector)
        if index is not None and score >= BANK_MATCH:
            return index
        if seconds >= BANK_MIN_SECONDS and len(self.speakers) < BANK_LIMIT:
            self.speakers.add(vector)
            return len(self.speakers) - 1
        return None

    def voice_for(self, heard, kind, index):
        """The voice a line recorded as [heard] is read in.

        One of the player's cards is read in its own voice, whoever it is
        standing in for; a character of the game's bank keeps the voice their
        first clear line earned, so the same person is never read by two
        voices; and a line belonging to nobody falls back to the gender heard
        in the line itself.
        """
        if not self._following:
            return self.speaker
        if kind == "character" and index is not None:
            chosen = voice_for_character(
                self.cast.voice_of(index), self.cast.gender_of(index), index, self.by_gender
            )
            if chosen is not None:
                self._current_voice = chosen
                return chosen
        if kind == "voice" and index is not None:
            kept = self.speakers.voice_of(index)
            # A bank filled for another language package names voices this
            # one does not ship.
            if kept in self.by_gender["male"] or kept in self.by_gender["female"]:
                self._current_voice = kept
                return kept
        gender = heard.gender
        if gender is None:
            return self._current_voice
        candidates = self.by_gender[gender]
        if index is None or kind != "voice":
            # Keep the configured voice when it already matches the gender.
            self._current_voice = self.speaker if self.speaker in candidates else candidates[0]
            return self._current_voice
        # A voice of their own: two men in a scene are read by different
        # voices, and the list wraps once the cast outgrows it.
        self._current_voice = candidates[self.speakers.spoken_by(gender) % len(candidates)]
        self.speakers.remember(index, gender, self._current_voice)
        return self._current_voice

    def timbre_for(self, fingerprint, kind, index):
        """The timbre to re-voice a line in: the character's kept one, or the
        fingerprint of the line itself."""
        if fingerprint is None:
            return self._current_timbre
        self._current_timbre = fingerprint
        kept = None
        if kind == "character" and index is not None:
            kept = self.cast.vector_of(index)
        elif kind == "voice" and self._bank is not None and index is not None:
            kept = self._bank.voices[index]
        if kept is not None:
            timbre = self._torch.from_numpy(kept).reshape(fingerprint.shape)
            self._current_timbre = timbre.to(device=fingerprint.device, dtype=fingerprint.dtype)
        return self._current_timbre


def needs_converter(handler):
    """A request only the voice converter can answer."""

    def answer(session, request_id, value, request):
        if session.models.converter is None:
            raise RuntimeError("the voice converter is not loaded")
        return handler(session, request_id, value, request)

    return answer


class Session:
    """The requests of one session, each answered by the handler its key
    names -- a line to dub where none does."""

    def __init__(self, args):
        self.args = args
        self.models = Models(args)
        self.glossary = Glossary(args.glossary)
        self.translation = Translation(self.models, args.translation_prefix, self.glossary)
        self.casting = Casting(args, self.models)
        self.speed = clamped_speed(args.speed)
        self.work = pathlib.Path(args.work_directory)
        self.work.mkdir(parents=True, exist_ok=True)

    def answer(self, request):
        """The reply to [request], an object carrying its id."""
        request_id = request["id"]
        for key, handler in HANDLERS:
            if request.get(key) is not None:
                return handler(self, request_id, request[key], request)
        return self.dub(request_id, request)

    @needs_converter
    def fingerprint(self, request_id, recorded, _):
        """The voice in a recording, as the characters screen keeps it."""
        heard = Heard(recorded)
        samples, rate = heard.clip
        if samples is None:
            raise RuntimeError(f"unreadable recording: {recorded}")
        vector = as_vector(self.models.converter.embed(samples, rate))
        return {
            "id": request_id,
            "vector": [round(float(value), 6) for value in vector],
            "gender": heard.gender,
            "seconds": round(len(samples) / rate, 2),
        }

    @needs_converter
    def voice_from(self, request_id, gathered, _):
        """A card built from the files the player dropped onto it."""
        return {"id": request_id, **build_voice(self.models.converter, [str(path) for path in gathered])}

    def voiced_by(self, request_id, substitution, _):
        """A card read in another's voice from now on, as the characters
        screen has just been told. The cast was read at start, so a session
        already running is told rather than left behind."""
        self.casting.cast.voice_instead(
            str(substitution.get("character", "")), str(substitution.get("target", ""))
        )
        return {"id": request_id, "voiced": True}

    def glossary_written(self, request_id, written_down, _):
        """What the player wrote down, as they wrote it: the file is read when
        a session starts, so this is what carries an entry added while one
        runs. A line already dubbed is not dubbed again, but the next time the
        game says it, it is said their way."""
        self.glossary.replace(written_down)
        return {"id": request_id, "glossary": len(self.glossary)}

    def use_voice(self, request_id, chosen_voice, _):
        """The voice the dubbing reads in, changed while it runs: the player
        picks another on the screen page or in the settings, and the next line
        is read in it rather than at the next start. A name this package does
        not ship is left alone -- the answer says which voice is in use."""
        return {"id": request_id, "speaker": self.casting.use_voice(str(chosen_voice))}

    def as_heard(self, request_id, heard_as_itself, _):
        """The cards taken out of the mix on the graph, as the canvas now
        draws them. The cards keep who stands in for whom either way; this is
        only which of it is applied."""
        self.casting.as_heard = {str(name) for name in heard_as_itself}
        return {"id": request_id, "asHeard": sorted(self.casting.as_heard)}

    @needs_converter
    def listen(self, request_id, heard_line, _):
        """Who is speaking, and nothing else. Live asks this before the
        dubbing itself runs, so the player can hand out the voices of a scene
        while only the converter is loaded."""
        casting = self.casting
        heard = Heard(heard_line)
        kind, index, _ = casting.identify(heard)
        answer = {"id": request_id, "speaker": casting.speaker_key(kind, index)}
        # The card the graph gave this one away to, if it did and if the cast
        # is in the mix at all.
        read_kind, read_index = casting.read_as(kind, index)
        if (read_kind, read_index) != (kind, index):
            answer["readAs"] = casting.speaker_key(read_kind, read_index)
        samples, rate = heard.clip
        answer["seconds"] = round(len(samples) / rate, 2) if samples is not None else 0
        return answer

    def preview(self, request_id, sample, request):
        """A sample of one voice, which the characters screen plays so the
        player can hear a card before a word of the game is dubbed."""
        if self.models.tts is None:
            raise RuntimeError("the speech model is not loaded")
        casting = self.casting
        chosen = str(sample.get("voice") or casting.speaker)
        if casting.voices and chosen not in casting.voices:
            chosen = casting.speaker
        # The card's own timbre over that voice, which is what the dubbing
        # will do with it.
        timbre = None
        vector = sample.get("vector")
        if self.models.converter is not None and vector:
            torch = self.models.torch
            timbre = torch.from_numpy(np.asarray(vector, dtype=np.float32)).reshape(1, -1, 1)
            timbre = timbre.to(device=self.models.converter.device, dtype=torch.float32)
        output = self.speak(
            str(sample.get("text", "")).strip(), chosen, timbre, request, f"preview-{request_id}.wav"
        )
        return {"id": request_id, "wave": str(output), "voice": chosen}

    def diarize(self, request_id, listening, _):
        """Where does the voice change? Asked before recognition, so each
        speaker's half is recognized and voiced on its own."""
        cuts = []
        if self.models.converter is not None:
            samples, rate = read_clip(listening)
            if samples is not None:
                cuts = speaker_cuts(self.models.converter, samples, rate)
        return {"id": request_id, "cuts": [round(cut, 3) for cut in cuts]}

    def dub(self, request_id, request):
        """A line of the game, translated where it has to be and voiced in the
        voice and timbre of whoever said it."""
        text = request["text"].strip()
        # Text read off the screen in the dubbing language itself has nothing
        # to be translated and is voiced as it is, and so is everything in a
        # session started without a translator at all.
        if request.get("translate", True) and self.translation.available:
            translated = self.translation.line(text)
        else:
            translated = text
        # Whatever is about to be said, translated here or read off the screen
        # already in the dubbing language: these are words of that language
        # either way.
        translated = self.glossary.worded(translated)
        # A line the player silenced has nothing left to say. It is answered
        # rather than voiced, so the interface can show what was passed over
        # instead of leaving a silence with no reason.
        if not translated.strip():
            return {"id": request_id, "translated": "", "silenced": True}
        # Who is speaking is settled first: the character decides both the
        # voice they are read in and the timbre laid over it.
        casting = self.casting
        heard = Heard(request.get("wave"))
        heard_kind, heard_index, fingerprint = casting.identify(heard)
        kind, index = casting.read_as(heard_kind, heard_index)
        chosen = casting.voice_for(heard, kind, index)
        timbre = casting.timbre_for(fingerprint, kind, index) if self.args.revoice else None
        output = self.speak(translated, chosen, timbre, request, f"speech-{request_id}.wav")
        answer = {
            "id": request_id,
            "translated": translated,
            "wave": str(output),
            "voice": chosen,
            "cloned": timbre is not None,
        }
        # Reported as it was heard, not as it was read: the scene list offers
        # a replacement against the voice of the game.
        heard = casting.speaker_key(heard_kind, heard_index)
        if heard is not None:
            answer["speaker"] = heard
            if (kind, index) != (heard_kind, heard_index) and index is not None:
                answer["readAs"] = f"character:{casting.cast.identifier(index)}"
        elif self.models.converter is None:
            # Nothing heard who is speaking, so the voice is all that tells
            # lines apart: men from women and nothing more.
            answer["speaker"] = f"voice:{chosen}"
        if self.models.bank is not None:
            answer["bankSize"] = len(self.models.bank)
        return answer

    def speak(self, text, voice, timbre, request, name):
        """[text] read in [voice], over [timbre] where there is one, at the
        pace [request] asks for, written to [name] in the work directory."""
        audio = self.models.tts.apply_tts(
            text=text,
            speaker=voice,
            sample_rate=self.args.sample_rate,
            put_accent=True,
            put_yo=True,
        )
        samples = audio.clamp(-1, 1).to(self.models.torch.float32).cpu().numpy()
        rate = self.args.sample_rate
        if timbre is not None:
            # The converter answers at its own rate; the file is written at it.
            samples, rate = self.models.converter.convert(samples, rate, timbre)
        # Hurried while other lines are already waiting for the voice, so that
        # the dubbing does not fall further behind the game.
        samples = change_speed(samples, request_speed(request, self.speed), rate)
        output = self.work / name
        write_wave(output, samples, rate)
        return output


# Which handler answers a request, by the key it carries, in the order they
# are asked. A key that is there is asked for, whatever it holds: an empty
# recording is answered as one that cannot be read, where it used to fall
# through to the line path and come back as a missing "text".
HANDLERS = (
    ("fingerprint", Session.fingerprint),
    ("voiceFrom", Session.voice_from),
    ("voicedBy", Session.voiced_by),
    ("glossary", Session.glossary_written),
    ("speaker", Session.use_voice),
    ("asHeard", Session.as_heard),
    ("listen", Session.listen),
    ("preview", Session.preview),
    ("diarize", Session.diarize),
)


def main():
    use_utf8_streams()
    claim_protocol()
    session = Session(parse_arguments())
    reply(session.models.ready_line())
    for raw_line in sys.stdin:
        # A malformed line must not take the worker down with it: the pipeline
        # would then look alive while every later phrase is lost.
        line = raw_line.strip().lstrip("﻿")
        if not line:
            continue
        try:
            request = json.loads(line)
            # A list, a number or null is JSON too, and indexing one by "id"
            # raised a TypeError nothing caught, which ended the worker.
            if not isinstance(request, dict):
                raise ValueError(f"a request is an object, not {type(request).__name__}")
            request_id = request["id"]
        except (ValueError, KeyError) as error:
            reply({"type": "error", "message": f"malformed request: {error}"})
            continue
        try:
            reply(session.answer(request))
        except Exception as error:
            reply({"id": request_id, "error": str(error)})


if __name__ == "__main__":
    main()

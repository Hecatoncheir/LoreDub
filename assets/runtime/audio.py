# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

"""The worker's sound: WAV files read and written, a line retimed, the
pitch of a voice, and where in a recording the speaker changes."""

import wave

import numpy as np


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
    strong = [f for f, e in zip(picks, energies, strict=True) if e >= floor]
    return float(np.median(strong or picks))


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

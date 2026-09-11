# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

"""Persistent, line-delimited JSON worker for Marian and Silero inference."""

import argparse
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


# Two or more Latin letters in a translated line means a name came through
# untranslated, which the speech model cannot read.
LATIN_RUN = re.compile(r"[A-Za-z]{2,}")

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


def main():
    use_utf8_streams()
    parser = argparse.ArgumentParser()
    parser.add_argument("--translation-model", required=True)
    parser.add_argument("--tts-model", required=True)
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
    args = parser.parse_args()

    speed = min(2.0, max(0.5, args.speed))

    # CUDA torch is installed next to the models instead of over the bundled
    # CPU build, so it has to win the import before torch is first touched.
    if args.extra_packages and pathlib.Path(args.extra_packages).is_dir():
        sys.path.insert(0, args.extra_packages)

    report_progress(0.10, "torch")
    import torch

    report_progress(0.35, "transformers")
    from transformers import MarianMTModel, MarianTokenizer

    report_progress(0.80, "translator")
    torch.set_num_threads(max(1, args.threads))
    # A CUDA build that cannot see the card is a working CPU build. Falling
    # back beats refusing to start over a driver the user cannot fix here.
    device = torch.device("cuda" if args.device == "cuda" and torch.cuda.is_available() else "cpu")
    tokenizer = MarianTokenizer.from_pretrained(args.translation_model, local_files_only=True)
    translator = MarianMTModel.from_pretrained(args.translation_model, local_files_only=True)
    translator.eval()
    translator.to(device)

    report_progress(0.90, "speech")
    tts = torch.package.PackageImporter(args.tts_model).load_pickle("tts_models", "model")
    tts.to(torch.device("cpu"))
    # Loading the Silero package drops torch to a single thread, and that
    # holds for everything after it: the translator ran on one core, and the
    # voice converter took three times as long. The requested count goes back.
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
    def translate(source):
        prompt = f"{args.translation_prefix} {source}".strip() if args.translation_prefix else source
        inputs = tokenizer([prompt], return_tensors="pt", padding=True).to(device)
        with torch.inference_mode():
            generated = translator.generate(**inputs, num_beams=1, max_new_tokens=160)
        return tokenizer.batch_decode(generated, skip_special_tokens=True)[0].strip()

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

    def identify(request):
        """The character this line belongs to and the fingerprint read from
        it, as (index, fingerprint).

        Both are None without the converter, which is what hears who is
        speaking, and for a line too short or too unvoiced to place.
        """
        source = request.get("wave")
        if converter is None or not source:
            return None, None
        try:
            samples, rate = read_wave_mono(source)
        except (OSError, wave.Error, ValueError):
            return None, None
        if (
            samples is None
            or rate <= 0
            or len(samples) < rate // 2
            or median_f0(samples, rate) is None
        ):
            return None, None
        fingerprint = converter.embed(samples, rate)
        # A short line nobody matched could be anyone.
        return speaker_of(fingerprint, len(samples) / rate), fingerprint

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

    def voice_for(request, index):
        """The voice this line is read in.

        A character keeps the voice their first clear line earned, so the same
        person is never read by two voices; a line belonging to nobody falls
        back to the gender heard in the line itself.
        """
        nonlocal current_voice
        if not following:
            return speaker
        if index is not None:
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
        if index is None:
            # Keep the configured voice when it already matches the gender.
            current_voice = speaker if speaker in candidates else candidates[0]
            return current_voice
        # A voice of their own: two men in a scene are read by different
        # voices, and the list wraps once the cast outgrows it.
        current_voice = candidates[speakers.spoken_by(gender) % len(candidates)]
        speakers.remember(index, gender, current_voice)
        return current_voice

    def timbre_for(fingerprint, index):
        """The timbre to re-voice a line in: the character's kept one, or the
        fingerprint of the line itself."""
        nonlocal current_timbre
        if fingerprint is None:
            return current_timbre
        current_timbre = fingerprint
        if bank is not None and index is not None:
            kept = torch.from_numpy(bank.voices[index]).reshape(fingerprint.shape)
            current_timbre = kept.to(device=fingerprint.device, dtype=fingerprint.dtype)
        return current_timbre

    pathlib.Path(args.work_directory).mkdir(parents=True, exist_ok=True)
    # The device is reported back rather than assumed: a CUDA build that fell
    # back to the CPU must not leave the interface claiming the GPU is in use.
    ready = {"type": "ready", "device": device.type}
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
            text = request["text"].strip()
            # Text read off the screen in the dubbing language itself has
            # nothing to be translated and is voiced as it is.
            if request.get("translate", True):
                translated = translate(text)
                # A capitalised name is occasionally carried over untranslated,
                # and the speech model cannot read Latin script. Asking again
                # without the capitals costs one extra pass on the rare line
                # that needs it, and gives back something that can be spoken.
                if LATIN_RUN.search(translated):
                    retry = translate(text.lower())
                    if not LATIN_RUN.search(retry):
                        translated = retry
            else:
                translated = text
            # Who is speaking is settled first: the character decides both the
            # voice they are read in and the timbre laid over it.
            index, fingerprint = identify(request)
            chosen = voice_for(request, index)
            audio = tts.apply_tts(
                text=translated,
                speaker=chosen,
                sample_rate=args.sample_rate,
                put_accent=True,
                put_yo=True,
            )
            samples = audio.clamp(-1, 1).to(torch.float32).cpu().numpy()
            rate = args.sample_rate
            timbre = timbre_for(fingerprint, index) if args.revoice else None
            if timbre is not None:
                # The converter answers at its own rate; the file is written at it.
                samples, rate = converter.convert(samples, rate, timbre)
            samples = change_speed(samples, speed, rate)
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
            if index is not None:
                answer["speaker"] = f"timbre:{index}"
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

# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

"""Persistent, line-delimited JSON worker for Marian and Silero inference."""

import argparse
import json
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
    # Every Silero language ships its own voices. Falling back keeps an
    # unknown name from turning the whole language into a runtime error.
    voices = list(getattr(tts, "speakers", None) or [])
    speaker = args.speaker if args.speaker in voices else (voices[0] if voices else args.speaker)

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

    def voice_for(request):
        nonlocal current_voice
        if not following:
            return speaker
        source = request.get("wave")
        gender = speaker_gender(source) if source else None
        if gender is None:
            return current_voice
        # Keep the configured voice when it already matches the gender.
        candidates = by_gender[gender]
        current_voice = speaker if speaker in candidates else candidates[0]
        return current_voice

    pathlib.Path(args.work_directory).mkdir(parents=True, exist_ok=True)
    # The device is reported back rather than assumed: a CUDA build that fell
    # back to the CPU must not leave the interface claiming the GPU is in use.
    reply({"type": "ready", "device": device.type})

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
            translated = translate(text)
            # A capitalised name is occasionally carried over untranslated,
            # and the speech model cannot read Latin script. Asking again
            # without the capitals costs one extra pass on the rare line that
            # needs it, and gives back something that can be spoken.
            if LATIN_RUN.search(translated):
                retry = translate(text.lower())
                if not LATIN_RUN.search(retry):
                    translated = retry
            chosen = voice_for(request)
            audio = tts.apply_tts(
                text=translated,
                speaker=chosen,
                sample_rate=args.sample_rate,
                put_accent=True,
                put_yo=True,
            )
            samples = audio.clamp(-1, 1).to(torch.float32).cpu().numpy()
            samples = change_speed(samples, speed, args.sample_rate)
            pcm = np.clip(samples * 32767.0, -32768, 32767).astype(np.int16).tobytes()
            output = pathlib.Path(args.work_directory) / f"speech-{request_id}.wav"
            with wave.open(str(output), "wb") as stream:
                stream.setnchannels(1)
                stream.setsampwidth(2)
                stream.setframerate(args.sample_rate)
                stream.writeframes(pcm)
            reply(
                {
                    "id": request_id,
                    "translated": translated,
                    "wave": str(output),
                    "voice": chosen,
                }
            )
        except Exception as error:
            reply({"id": request_id, "error": str(error)})


if __name__ == "__main__":
    main()

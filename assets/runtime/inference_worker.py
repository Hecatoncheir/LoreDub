# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

"""Persistent, line-delimited JSON worker for Marian and Silero inference."""

import argparse
import json
import pathlib
import sys
import wave

import numpy as np
import torch
from transformers import MarianMTModel, MarianTokenizer


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
    args = parser.parse_args()

    speed = min(2.0, max(0.5, args.speed))
    torch.set_num_threads(max(1, args.threads))
    tokenizer = MarianTokenizer.from_pretrained(args.translation_model, local_files_only=True)
    translator = MarianMTModel.from_pretrained(args.translation_model, local_files_only=True)
    translator.eval()
    tts = torch.package.PackageImporter(args.tts_model).load_pickle("tts_models", "model")
    tts.to(torch.device("cpu"))
    pathlib.Path(args.work_directory).mkdir(parents=True, exist_ok=True)
    reply({"type": "ready"})

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
            reply({"type": "error", "message": f"Некорректный запрос: {error}"})
            continue
        try:
            text = request["text"].strip()
            inputs = tokenizer([text], return_tensors="pt", padding=True)
            with torch.inference_mode():
                generated = translator.generate(**inputs, num_beams=1, max_new_tokens=160)
            translated = tokenizer.batch_decode(generated, skip_special_tokens=True)[0].strip()
            audio = tts.apply_tts(
                text=translated,
                speaker=args.speaker,
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
            reply({"id": request_id, "translated": translated, "wave": str(output)})
        except Exception as error:
            reply({"id": request_id, "error": str(error)})


if __name__ == "__main__":
    main()

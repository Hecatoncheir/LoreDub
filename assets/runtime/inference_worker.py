# Copyright (c) 2026 GameLingo contributors.
# SPDX-License-Identifier: MIT

"""Persistent, line-delimited JSON worker for Marian and Silero inference."""

import argparse
import json
import pathlib
import sys
import wave

import torch
from transformers import MarianMTModel, MarianTokenizer


def reply(value):
    sys.stdout.write(json.dumps(value, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--translation-model", required=True)
    parser.add_argument("--tts-model", required=True)
    parser.add_argument("--work-directory", required=True)
    parser.add_argument("--threads", type=int, default=4)
    parser.add_argument("--speaker", default="xenia")
    parser.add_argument("--sample-rate", type=int, default=24000)
    args = parser.parse_args()

    torch.set_num_threads(max(1, args.threads))
    tokenizer = MarianTokenizer.from_pretrained(args.translation_model, local_files_only=True)
    translator = MarianMTModel.from_pretrained(args.translation_model, local_files_only=True)
    translator.eval()
    tts = torch.package.PackageImporter(args.tts_model).load_pickle("tts_models", "model")
    tts.to(torch.device("cpu"))
    pathlib.Path(args.work_directory).mkdir(parents=True, exist_ok=True)
    reply({"type": "ready"})

    for raw_line in sys.stdin:
        request = json.loads(raw_line)
        request_id = request["id"]
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
            pcm = (audio.clamp(-1, 1) * 32767).to(torch.int16).cpu().numpy().tobytes()
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

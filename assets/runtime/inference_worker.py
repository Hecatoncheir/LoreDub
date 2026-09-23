# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

"""Persistent, line-delimited JSON worker for Marian and the Vosk-TTS voice."""

import argparse
import json
import os
import pathlib
import shutil
import sys

import numpy as np

# The worker's own modules sit beside it. The embedded interpreter's ._pth
# file turns off putting the script's directory on the path, so it is put
# there by hand, before the first of them is imported.
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from audio import (
    Heard,
    as_vector,
    change_speed,
    clamped_speed,
    read_clip,
    request_speed,
    speaker_cuts,
    write_wave,
)
from dubbing_text import (
    LATIN_RUN,
    LATIN_TEXT,
    Glossary,
    TranslationMemory,
    readable,
    sentences,
)
from llm_translation import (
    ALL_LAYERS,
    LlamaServer,
    LlmTranslation,
    language_model_in,
    layers_for_card,
)
from protocol import (
    claim_protocol,
    reply,
    report_progress,
    use_utf8_streams,
)
from voices import (
    BANK_LIMIT,
    BANK_MATCH,
    BANK_MIN_SECONDS,
    CLONE_SECONDS,
    CharacterCast,
    VoiceBank,
    build_voice,
    load_voice,
    reference_clips,
    voice_for_character,
)

# torch and transformers are imported inside main(): together they account for
# most of the startup, and importing them here would leave the application
# without a sign of life for the first ten seconds.

# Where the worker runs from, which is where the application put the clips
# a voice that clones reads its fixed voices from.
WORKER_DIRECTORY = pathlib.Path(__file__).resolve().parent



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
    # Where llama.cpp's server stands, for a translator that is a language
    # model -- a `.gguf` in --translation-model -- rather than Marian. Which
    # build it is, CPU, Vulkan or CUDA, is the application's choice, and
    # --translation-backend is what it reports back as the device.
    parser.add_argument("--llama-server", default="")
    parser.add_argument("--translation-backend", default="cpu", choices=["cpu", "vulkan", "cuda"])
    # One of llama.cpp's built-in chat templates, where the model's own
    # cannot be rendered from a plain message; empty leaves the model's own.
    parser.add_argument("--chat-template", default="")
    # The language the game speaks, where whisper was not asked to turn it
    # into English, and the language the dubbing is in. The language model
    # is told both; a line arrives with its own where whisper heard one.
    parser.add_argument("--source-language", default="en")
    parser.add_argument("--language", default="ru")
    return parser.parse_args(argv)


class Models:
    """What a session loaded, and where each part of it runs."""

    def __init__(self, args):
        # CUDA torch is installed next to the models instead of over the
        # bundled CPU build, so it has to win the import before torch is first
        # touched. Several directories may be named, separated the way PATH
        # is, the first of them winning; the application names one.
        for extra in reversed(args.extra_packages.split(os.pathsep)):
            if extra and pathlib.Path(extra).is_dir():
                sys.path.insert(0, extra)

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
        # A translator that is a language model: llama.cpp's server, and
        # the client that asks it. Marian leaves both empty.
        self.llama = None
        self.llm = None
        self.tts = None
        self.speech_device = None
        self.voices = []
        self.speaker = args.speaker
        # A translator that is a language model is loaded last of all, once
        # the voice and the converter hold what they will of the card; its
        # weights are kept until then.
        language_model = None
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
                language_model = language_model_in(args.translation_model)
                if language_model is None:
                    self._load_marian(args)
            report_progress(0.90, "speech")
            # torch is imported already, so onnxruntime-gpu finds the CUDA and
            # cuDNN libraries it brought. Without the card -- or with the
            # processor's build of onnxruntime, which is all a machine without
            # the CUDA runtime has -- the voice falls back to the processor,
            # and the ready line says where it really is.
            self.tts = load_voice(
                args.tts_model,
                threads=args.threads,
                device=args.speech_device,
                language=args.language,
                # The clips shipped beside the worker, which a voice that
                # clones reads its fixed voices from.
                references=reference_clips(WORKER_DIRECTORY / "references"),
            )
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
        if language_model is not None:
            self._load_language_model(args, language_model)

    def _load_marian(self, args):
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

    def _load_language_model(self, args, weights):
        """llama.cpp's server over [weights], started beside the worker and
        ended with it, after everything else: the build the application
        named is offered the card for every layer while the weights fit
        what the voice and the converter left free past whisper's share
        (`layers_for_card`), and keeps them on the processor otherwise --
        a model the card cannot hold is paged through system memory rather
        than refused, and a line then took minutes. The device reported is
        the one the model got."""
        report_progress(0.97, "translator")
        layers = ALL_LAYERS
        if args.translation_backend == "cuda":
            layers = layers_for_card(self._free_card_memory(), os.path.getsize(weights))
        self.llama = LlamaServer(
            args.llama_server,
            weights,
            threads=args.threads,
            log=pathlib.Path(args.work_directory) / "llama-server.log",
            chat_template=args.chat_template,
            layers=layers,
        )
        self.llm = self.llama.start()
        self.translation_device = args.translation_backend if self.llama.on_card else "cpu"

    def _free_card_memory(self):
        """What the card has left, in bytes, or None where torch cannot see
        one."""
        if not self.torch.cuda.is_available():
            return None
        free, _total = self.torch.cuda.mem_get_info()
        return free

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
        asking = [piece for piece, kept in zip(pieces, said, strict=True) if kept is None]
        if asking:
            answers = iter(self._sentences(asking))
            for index, kept in enumerate(said):
                if kept is None:
                    said[index] = next(answers)
                    self._memory.put(pieces[index], said[index])
        return " ".join(piece for piece in said if piece)

    def line(self, text, spoken_by=None, spoken=None):
        """[text] as it is to be said: translated, what was left in Latin
        written out, and the words the player renamed said their way.
        Marian can be told neither who is speaking nor what language, so
        [spoken_by] and [spoken] are the language model's alone."""
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
        # For a voice that clones: the clip each speaker of the game is read
        # from, kept in the work directory since the capture's own files do
        # not stay, and the one the last line was read from.
        self._clips = {}
        self._current_reference = None
        self._work = pathlib.Path(args.work_directory)
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

    def reference_for(self, heard, kind, index, transcript=""):
        """The clip a line of this speaker is read from, for a voice that
        clones, with what is said in it: one of the player's cards from its
        own recording -- or, with none, from the fixed voice the card is
        read in, which is None here; a speaker of the game from the longest
        clear line of theirs heard so far, the way the bank keeps their
        fingerprint; and a line belonging to nobody from itself, or from the
        last clip where it brought none. [transcript] is what [heard] says,
        where whisper wrote it down as heard rather than in English.
        """
        if kind == "character" and index is not None:
            clip = self.cast.clip_of(index)
            return (clip, "") if clip is not None else None
        if heard.source is None:
            return self._current_reference
        kept = self._clips.get((kind, index)) if index is not None else None
        seconds = heard.seconds
        if index is not None and (kept is None or (kept[1] < CLONE_SECONDS < seconds)):
            kept = (self._keep_clip(heard.source, kind, index), seconds, transcript)
            self._clips[(kind, index)] = kept
        self._current_reference = (kept[0], kept[2]) if kept is not None else (heard.source, transcript)
        return self._current_reference

    def _keep_clip(self, source, kind, index):
        """A copy of [source] that outlives the capture's own file."""
        kept = self._work / f"reference-{kind}-{index}.wav"
        shutil.copyfile(source, kept)
        return str(kept)


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
        # A language model is told the scene, the glossary and the speaker
        # with every line; Marian takes a sentence and nothing else.
        self.translation = (
            LlmTranslation(self.models.llm, args.source_language, args.language, self.glossary)
            if self.models.llm is not None
            else Translation(self.models, args.translation_prefix, self.glossary)
        )
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
        # will do with it: its recording, for a voice that clones, and its
        # fingerprint through the converter for the others.
        timbre = None
        clip = str(sample.get("clip") or "")
        reference = (clip, "") if clip else None
        vector = sample.get("vector")
        if not self._clones and self.models.converter is not None and vector:
            torch = self.models.torch
            timbre = torch.from_numpy(np.asarray(vector, dtype=np.float32)).reshape(1, -1, 1)
            timbre = timbre.to(device=self.models.converter.device, dtype=torch.float32)
        output = self.speak(
            str(sample.get("text", "")).strip(),
            chosen,
            timbre,
            request,
            f"preview-{request_id}.wav",
            reference=reference,
        )
        return {"id": request_id, "wave": str(output), "voice": chosen}

    @property
    def _clones(self):
        """Whether the voice reads in the timbre it is handed itself, leaving
        the converter to tell the characters apart and nothing more."""
        return bool(getattr(self.models.tts, "clones", False))

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
        heard = Heard(request.get("wave"))
        # Text read off the screen in the dubbing language itself has nothing
        # to be translated and is voiced as it is, and so is everything in a
        # session started without a translator at all. The language model is
        # told who is speaking -- the gender heard in the line, which the
        # grammar of the dubbing language may need -- and what language,
        # where whisper said; Marian is told neither and is not made to
        # measure the line for it.
        if request.get("translate", True) and self.translation.available:
            spoken_by = heard.gender if self.models.llm is not None and heard.source else None
            translated = self.translation.line(text, spoken_by=spoken_by, spoken=request.get("spoken"))
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
        # voice they are read in and the timbre laid over it -- or, for a
        # voice that clones, the clip it is read from.
        casting = self.casting
        heard_kind, heard_index, fingerprint = casting.identify(heard)
        kind, index = casting.read_as(heard_kind, heard_index)
        chosen = casting.voice_for(heard, kind, index)
        reference = timbre = None
        if self.args.revoice and self._clones:
            # Whisper's transcript of the clip conditions the reading on it,
            # where the text is that transcript rather than its translation.
            transcript = text if request.get("transcript") else ""
            reference = casting.reference_for(heard, kind, index, transcript)
        elif self.args.revoice:
            timbre = casting.timbre_for(fingerprint, kind, index)
        output = self.speak(
            translated, chosen, timbre, request, f"speech-{request_id}.wav", reference=reference
        )
        answer = {
            "id": request_id,
            "translated": translated,
            "wave": str(output),
            "voice": chosen,
            "cloned": timbre is not None or reference is not None,
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

    def speak(self, text, voice, timbre, request, name, reference=None):
        """[text] read in [voice], over [timbre] where there is one, at the
        pace [request] asks for, written to [name] in the work directory.
        A voice that clones reads from [reference] -- a clip and what is
        said in it -- instead, or from the clip that stands for [voice]
        where a line brings none, and the converter is not asked to move
        what the voice read as already."""
        if self._clones:
            clip, transcript = reference if reference is not None else (None, "")
            audio = self.models.tts.apply_tts(
                text=text,
                speaker=voice,
                sample_rate=self.args.sample_rate,
                reference=clip,
                reference_text=transcript,
            )
            timbre = None
        else:
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
    try:
        serve(session)
    finally:
        # The language model's server is tied to this process on Windows and
        # dies with it; ended here as well, a worker that leaves quietly
        # leaves nothing behind on any other system.
        if session.models.llama is not None:
            session.models.llama.stop()


def serve(session):
    """Answers every request on stdin until it closes."""
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

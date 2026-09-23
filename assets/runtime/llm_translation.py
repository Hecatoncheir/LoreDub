# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

"""The dubbing language through a language model.

llama.cpp's server is started beside the worker and asked over HTTP, one
line at a time, with the scene around it: the last lines of the dialogue,
the player's glossary where the line touches it, and who is speaking -- a
man or a woman, which is what Russian needs to put a verb in the past
tense. Marian (`Translation` in the worker) translates a sentence alone and
can be told none of it.

Nothing here needs numpy or torch, so the pieces are tested on any Python.
"""

import collections
import json
import pathlib
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request

from dubbing_text import LATIN_RUN, LATIN_TEXT, TranslationMemory, readable, sentences

# How the model is told the languages: by name, the way its instruction
# data named them, rather than by the codes the application keeps.
LANGUAGE_NAMES = {
    "en": "English",
    "ru": "Russian",
    "uk": "Ukrainian",
    "de": "German",
    "fr": "French",
    "es": "Spanish",
    "it": "Italian",
    "pt": "Portuguese",
    "pl": "Polish",
    "ja": "Japanese",
    "ko": "Korean",
    "zh": "Chinese",
}

# How many lines of the scene travel with a request. Enough for a pronoun
# to find what it stands for, few enough that the prompt stays short.
SCENE_LINES = 4

# The longest answer asked for, in tokens: a line of dialogue is short, and
# past this the model is elaborating rather than translating.
ANSWER_LIMIT = 512

# What a model puts in front of an answer when it did not listen: dropped.
ANSWER_LABELS = ("translation:", "перевод:", "translated text:", "output:")


def language_name(code):
    """The name a model knows a language by, or the code where none is known."""
    if not code:
        return "English"
    return LANGUAGE_NAMES.get(str(code).lower().split("-")[0].split("_")[0], str(code))


def language_model_in(directory):
    """The weights of a language model in [directory] -- a `.gguf`, the one
    file llama.cpp reads -- or None where the directory holds another kind
    of translator."""
    if not directory:
        return None
    found = sorted(pathlib.Path(directory).glob("*.gguf"))
    return found[0] if found else None


def translation_messages(text, source, target, scene=(), hints=(), spoken_by=None):
    """The one user turn a line is translated from.

    Worded the way TranslateGemma was tuned on, so that model reads it as
    the instruction it knows; the scene, the glossary and the speaker stand
    between the instruction and the line, where a general model reads them
    as conditions on the answer.
    """
    parts = [
        f"You are a professional {source} to {target} translator. Your goal is to accurately "
        f"convey the meaning and nuances of the original {source} text while adhering to "
        f"{target} grammar, vocabulary, and cultural sensitivities. Produce only the {target} "
        "translation, without any additional explanations or commentary. The text is one "
        "line of dialogue from a video game."
    ]
    if scene:
        parts.append(
            "Earlier lines of the same scene, for context only, already translated:\n"
            + "\n".join(f"{source}: {said}\n{target}: {read}" for said, read in scene)
        )
    if hints:
        parts.append(
            "Render these names and terms exactly as given, declined as the grammar requires:\n"
            + "\n".join(f"{word} -> {reading}" for word, reading in hints)
        )
    # Worded plainly on purpose. Measured over five first-person lines with
    # TranslateGemma 4B: this puts three of them in the feminine, where a
    # longer wording that also asked for the person addressed to be left
    # alone put none, and a bare "The speaker is a woman." one. What it
    # cannot do is keep the feminine to the speaker: "you said" follows on
    # occasion, which Marian, always in the masculine, never gets right either.
    if spoken_by == "female":
        parts.append(
            f"The line is spoken by a woman: use the feminine forms where {target} requires "
            "them for the speaker."
        )
    elif spoken_by == "male":
        parts.append(
            f"The line is spoken by a man: use the masculine forms where {target} requires "
            "them for the speaker."
        )
    parts.append(f"Please translate the following {source} text into {target}:\n\n{text}")
    return [{"role": "user", "content": "\n\n".join(parts)}]


def clean_answer(answer, text=""):
    """[answer] as the line it was meant to be: a label or the quotes a
    model wrapped it in taken off, and the whitespace collapsed."""
    said = " ".join(str(answer or "").split())
    lowered = said.lower()
    for label in ANSWER_LABELS:
        if lowered.startswith(label):
            said = said[len(label) :].strip()
            break
    quotes = (('"', '"'), ("«", "»"), ("“", "”"), ("'", "'"))
    for opening, closing in quotes:
        wrapped = len(said) > 1 and said[0] == opening and said[-1] == closing
        if wrapped and not (text.startswith(opening) and text.endswith(closing)):
            said = said[1:-1].strip()
            break
    return said


def answer_limit(text):
    """How many tokens a translation of [text] may take: a few per word, so
    a runaway answer ends rather than fills the context."""
    return min(ANSWER_LIMIT, 48 + 6 * len(text.split()))


def free_port():
    """A port nothing listens on right now."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.bind(("127.0.0.1", 0))
        return probe.getsockname()[1]


class LlamaClient:
    """llama.cpp's server over HTTP: the health it reports and the chat it answers."""

    def __init__(self, url, timeout=120.0):
        self.url = url.rstrip("/")
        self._timeout = timeout

    def healthy(self):
        """Whether the server has its model loaded and is answering."""
        try:
            with urllib.request.urlopen(f"{self.url}/health", timeout=5) as response:
                return response.status == 200
        except (urllib.error.URLError, OSError, ValueError):
            return False

    def chat(self, messages, max_tokens=ANSWER_LIMIT):
        """The assistant's answer to [messages], greedy, as one string."""
        body = json.dumps(
            {
                "messages": messages,
                "temperature": 0,
                "max_tokens": max_tokens,
                "stream": False,
            }
        ).encode("utf-8")
        request = urllib.request.Request(
            f"{self.url}/v1/chat/completions",
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(request, timeout=self._timeout) as response:
            answered = json.loads(response.read().decode("utf-8"))
        choices = answered.get("choices") or []
        if not choices:
            raise RuntimeError("the language model answered nothing")
        return str((choices[0].get("message") or {}).get("content") or "")


GIGABYTE = 1 << 30

# Every layer llama.cpp can be asked to put on the card.
ALL_LAYERS = 99

# What the card is asked to keep free past the model, measured at the moment
# the decision is made, with the voice and the converter just loaded: about
# 1.5 GB for whisper's build over a segment, and 2 GB the voice itself takes
# on under the lines -- its activations and the allocator's cache -- that it
# does not hold yet when asked. On the 12 GB card, 1.5 GB alone let the
# model on beside a voice at 5 GB, and the three met at 11.7 GB under the
# first lines: one line voiced in 70 s, seventeen segments waiting.
CARD_RESERVE = int(3.5 * GIGABYTE)

# What the model takes over its weights: its context and compute buffers.
MODEL_ROOM = 1.15


def layers_for_card(free_bytes, model_bytes, reserve_bytes=CARD_RESERVE, room=MODEL_ROOM):
    """How many layers the server is offered the card for: every one while
    the weights, with their room, fit what is free past [reserve_bytes], and
    none otherwise. A model that does not fit is not refused by the driver
    but paged through system memory, where a line took minutes rather than a
    tenth of a second and the display driver went down with it; on the
    processor the same line takes a few seconds. A card torch cannot see
    ([free_bytes] None) is left to the build's own fallback."""
    if free_bytes is None:
        return ALL_LAYERS
    return ALL_LAYERS if free_bytes - reserve_bytes >= model_bytes * room else 0


class LlamaServer:
    """llama.cpp's server as a child of the worker, ended with it.

    The executable is found in [directory], the model under [model]. Which
    build stands in the directory -- CPU, Vulkan or CUDA -- is the
    application's choice; [layers] of the model are offered to the card
    (every one unless the worker measured that they would not fit,
    `layers_for_card`), and a build without one keeps them on the processor.
    """

    def __init__(
        self,
        directory,
        model,
        threads=4,
        context=2048,
        log=None,
        chat_template="",
        layers=ALL_LAYERS,
    ):
        self._directory = pathlib.Path(directory)
        self._model = pathlib.Path(model)
        self._threads = max(1, int(threads))
        self._context = int(context)
        self._layers = int(layers)
        self._log = pathlib.Path(log) if log else None
        # One of llama.cpp's built-in templates, named where the one the
        # model carries cannot be rendered from a plain message: Gemma's
        # translation tuning expects a message of its own shape, and the
        # built-in `gemma` template wraps the same turns around ours.
        self._chat_template = chat_template
        self._process = None
        self._job = None
        self.client = None

    @property
    def executable(self):
        name = "llama-server.exe" if sys.platform == "win32" else "llama-server"
        return self._directory / name

    @property
    def on_card(self):
        """Whether the model was offered the card at all."""
        return self._layers > 0

    def command(self, port):
        return [
            str(self.executable),
            "-m",
            str(self._model),
            "--host",
            "127.0.0.1",
            "--port",
            str(port),
            "-c",
            str(self._context),
            "-ngl",
            str(self._layers),
            "-t",
            str(self._threads),
            "-np",
            "1",
            *(
                ["--no-jinja", "--chat-template", self._chat_template]
                if self._chat_template
                else ["--jinja"]
            ),
            "--no-webui",
        ]

    def start(self, wait=300.0):
        """Starts the server and returns its client once it answers, or
        raises with what the server wrote when it did not."""
        if not self.executable.is_file():
            raise RuntimeError(f"llama-server is not at {self.executable}")
        if not self._model.is_file():
            raise RuntimeError(f"the language model is not at {self._model}")
        port = free_port()
        output = open(self._log, "ab") if self._log else subprocess.DEVNULL
        flags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        try:
            self._process = subprocess.Popen(
                self.command(port),
                stdin=subprocess.DEVNULL,
                stdout=output,
                stderr=subprocess.STDOUT,
                cwd=str(self._directory),
                creationflags=flags,
            )
        finally:
            if output is not subprocess.DEVNULL:
                output.close()
        self._job = _ended_with_this_process(self._process)
        self.client = LlamaClient(f"http://127.0.0.1:{port}")
        deadline = time.monotonic() + wait
        while time.monotonic() < deadline:
            if self._process.poll() is not None:
                raise RuntimeError(
                    f"llama-server ended with code {self._process.returncode}: {self._log_tail()}"
                )
            if self.client.healthy():
                return self.client
            time.sleep(0.25)
        self.stop()
        raise RuntimeError(f"llama-server did not answer within {wait:.0f} s")

    def stop(self):
        if self._process is not None and self._process.poll() is None:
            self._process.kill()
            try:
                self._process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                pass
        self._process = None

    def _log_tail(self):
        if self._log is None or not self._log.is_file():
            return ""
        try:
            return self._log.read_text(encoding="utf-8", errors="replace")[-2000:]
        except OSError:
            return ""


def _ended_with_this_process(process):
    """Ties [process] to this one on Windows, so that the worker being
    killed -- which is how the application stops it -- takes the server
    down with it rather than leaving it holding the card. Answers the job
    handle, which has to stay alive, or None where it could not be made."""
    if sys.platform != "win32":
        return None
    import ctypes
    from ctypes import wintypes

    class IoCounters(ctypes.Structure):
        _fields_ = [(name, ctypes.c_ulonglong) for name in ("r", "w", "o", "rb", "wb", "ob")]

    class BasicLimits(ctypes.Structure):
        _fields_ = [
            ("PerProcessUserTimeLimit", ctypes.c_longlong),
            ("PerJobUserTimeLimit", ctypes.c_longlong),
            ("LimitFlags", wintypes.DWORD),
            ("MinimumWorkingSetSize", ctypes.c_size_t),
            ("MaximumWorkingSetSize", ctypes.c_size_t),
            ("ActiveProcessLimit", wintypes.DWORD),
            ("Affinity", ctypes.c_size_t),
            ("PriorityClass", wintypes.DWORD),
            ("SchedulingClass", wintypes.DWORD),
        ]

    class ExtendedLimits(ctypes.Structure):
        _fields_ = [
            ("BasicLimitInformation", BasicLimits),
            ("IoInfo", IoCounters),
            ("ProcessMemoryLimit", ctypes.c_size_t),
            ("JobMemoryLimit", ctypes.c_size_t),
            ("PeakProcessMemoryUsed", ctypes.c_size_t),
            ("PeakJobMemoryUsed", ctypes.c_size_t),
        ]

    kernel = ctypes.windll.kernel32
    job = kernel.CreateJobObjectW(None, None)
    if not job:
        return None
    limits = ExtendedLimits()
    limits.BasicLimitInformation.LimitFlags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
    extended_limit_information = 9
    kernel.SetInformationJobObject(
        job, extended_limit_information, ctypes.byref(limits), ctypes.sizeof(limits)
    )
    if not kernel.AssignProcessToJobObject(job, wintypes.HANDLE(process._handle)):
        kernel.CloseHandle(job)
        return None
    return job


class LlmTranslation:
    """A line in the dubbing language, whole, with the scene it belongs to.

    The player's own answer to a sentence still stands above the model, and
    a line already translated is answered from memory; only what neither
    knows is asked, and asked with the last lines of the scene, the glossary
    entries the line touches and the speaker's gender in front of it.
    """

    def __init__(self, client, source, target, glossary):
        self._client = client
        self._source = language_name(source)
        self._target = language_name(target)
        self._glossary = glossary
        self._memory = TranslationMemory()
        self._scene = collections.deque(maxlen=SCENE_LINES)
        # Whether the dubbing language is written in Latin, asked of the
        # model once, the way the Marian path asks it: the probe goes to
        # the model directly, past the glossary, so a line the player wrote
        # down cannot decide the script of every line after.
        self.dubbed_in_latin = bool(LATIN_RUN.search(self._ask("Open the door.")))

    @property
    def available(self):
        return True

    def _ask(self, text, spoken_by=None, source=None):
        messages = translation_messages(
            text,
            source or self._source,
            self._target,
            scene=tuple(self._scene),
            hints=tuple(self._glossary.mentioned(text)),
            spoken_by=spoken_by,
        )
        return clean_answer(self._client.chat(messages, max_tokens=answer_limit(text)), text)

    def _answered(self, text, spoken_by, source):
        """[text] from memory, or from the model and then into it. The
        memory is kept by who spoke as well as by what was said: the same
        line in a woman's mouth and in a man's are two lines of the
        dubbing language."""
        key = f"{spoken_by}:{text}" if spoken_by else text
        kept = self._memory.get(key)
        if kept is None:
            kept = self._ask(text, spoken_by, source)
            self._memory.put(key, kept)
        return kept

    def translate(self, text, spoken_by=None, source=None):
        """[text] in the dubbing language: whole where the player wrote
        down none of its sentences, and sentence by sentence where they did."""
        pieces = sentences(text)
        said = [self._glossary.said(piece) for piece in pieces]
        if all(answer is None for answer in said):
            return self._answered(text, spoken_by, source)
        for index, piece in enumerate(pieces):
            if said[index] is None:
                said[index] = self._answered(piece, spoken_by, source)
        return " ".join(piece for piece in said if piece)

    def line(self, text, spoken_by=None, spoken=None):
        """[text] as it is to be said, and remembered as a line of the scene.

        [spoken] is the language the line was heard in, where whisper told
        it: a line already in the dubbing language is said as it is.
        """
        source = language_name(spoken) if spoken else self._source
        if source == self._target:
            return text
        translated = self.translate(text, spoken_by, source)
        if not self.dubbed_in_latin and LATIN_TEXT.search(translated):
            translated = readable(translated, text, self.translate, self._glossary)
        if translated:
            self._scene.append((text, translated))
        return translated

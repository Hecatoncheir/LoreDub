# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

"""The language-model translator's pieces, which need no numpy or torch:
the prompt a line is asked with, the answer cleaned, the client over a
server that answers in a thread, and the translation around them.

python -m unittest discover -s test/runtime
"""

import http.server
import json
import pathlib
import sys
import threading
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "assets" / "runtime"))

from dubbing_text import Glossary  # noqa: E402
from llm_translation import (  # noqa: E402
    ALL_LAYERS,
    GIGABYTE,
    LlamaClient,
    LlamaServer,
    LlmTranslation,
    answer_limit,
    clean_answer,
    language_name,
    layers_for_card,
    translation_messages,
)


class LanguageNameTest(unittest.TestCase):
    def test_names_a_code_and_keeps_an_unknown_one(self):
        self.assertEqual(language_name("ru"), "Russian")
        self.assertEqual(language_name("en-US"), "English")
        self.assertEqual(language_name("pt_BR"), "Portuguese")
        self.assertEqual(language_name("xx"), "xx")
        self.assertEqual(language_name(""), "English")


class MessagesTest(unittest.TestCase):
    def test_asks_for_the_line_alone_when_there_is_nothing_else(self):
        (message,) = translation_messages("Open the door.", "English", "Russian")
        self.assertEqual(message["role"], "user")
        self.assertIn("professional English to Russian translator", message["content"])
        self.assertTrue(message["content"].endswith("into Russian:\n\nOpen the door."))
        self.assertNotIn("spoken by", message["content"])
        self.assertNotIn("Earlier lines", message["content"])
        self.assertNotIn("names and terms", message["content"])

    def test_puts_the_scene_the_glossary_and_the_speaker_before_the_line(self):
        (message,) = translation_messages(
            "I went home.",
            "English",
            "Russian",
            scene=(("Where were you?", "Где ты была?"),),
            hints=(("Bob", "Боб"),),
            spoken_by="female",
        )
        content = message["content"]
        self.assertLess(content.index("Earlier lines"), content.index("Bob -> Боб"))
        self.assertLess(content.index("Bob -> Боб"), content.index("spoken by a woman"))
        self.assertLess(content.index("spoken by a woman"), content.index("I went home."))
        self.assertIn("English: Where were you?\nRussian: Где ты была?", content)

    def test_names_a_man_the_same_way(self):
        (message,) = translation_messages("I did it.", "English", "Russian", spoken_by="male")
        self.assertIn("spoken by a man", message["content"])


class CleanAnswerTest(unittest.TestCase):
    def test_drops_a_label_and_the_quotes_a_model_added(self):
        self.assertEqual(
            clean_answer('Translation: "Открой дверь."', "Open the door."), "Открой дверь."
        )
        self.assertEqual(clean_answer("«Открой дверь.»"), "Открой дверь.")

    def test_keeps_the_quotes_the_line_itself_had(self):
        self.assertEqual(clean_answer('"Открой дверь."', '"Open the door."'), '"Открой дверь."')

    def test_collapses_the_whitespace(self):
        self.assertEqual(clean_answer("  Открой \n дверь.  "), "Открой дверь.")

    def test_answer_limit_grows_with_the_line_and_stops(self):
        self.assertEqual(answer_limit("one two"), 60)
        self.assertEqual(answer_limit(" ".join(["word"] * 200)), 512)


class RecordingClient:
    """Stands in for the server: answers what it is told to, and keeps
    every prompt it was asked."""

    def __init__(self, answers):
        self.answers = list(answers)
        self.asked = []

    def chat(self, messages, max_tokens=0):
        self.asked.append(messages[0]["content"])
        return self.answers.pop(0)


def glossary_of(*entries):
    glossary = Glossary()
    glossary.replace({"entries": [dict(entry) for entry in entries]})
    return glossary


class LlmTranslationTest(unittest.TestCase):
    def test_probes_the_script_once_and_then_translates_whole_lines(self):
        client = RecordingClient(["Открой дверь.", "Я пошла домой."])
        translation = LlmTranslation(client, "en", "ru", Glossary())
        self.assertFalse(translation.dubbed_in_latin)
        self.assertTrue(translation.available)
        self.assertEqual(translation.line("I went home.", spoken_by="female"), "Я пошла домой.")
        self.assertIn("spoken by a woman", client.asked[1])
        self.assertTrue(client.asked[1].endswith("I went home."))

    def test_a_latin_dubbing_language_is_read_off_the_probe(self):
        translation = LlmTranslation(RecordingClient(["Open the door."]), "ru", "en", Glossary())
        self.assertTrue(translation.dubbed_in_latin)

    def test_the_players_phrase_stands_above_the_model_sentence_by_sentence(self):
        client = RecordingClient(["Открой дверь.", "Сейчас!"])
        glossary = glossary_of(
            {"kind": "phrase", "source": "Fire in the hole!", "reading": "Ложись!"}
        )
        translation = LlmTranslation(client, "en", "ru", glossary)
        self.assertEqual(translation.line("Fire in the hole! Now!"), "Ложись! Сейчас!")
        # Only the sentence the player did not write down was asked.
        self.assertEqual(len(client.asked), 2)
        self.assertTrue(client.asked[1].endswith("Now!"))

    def test_a_silenced_phrase_leaves_the_line(self):
        client = RecordingClient(["Открой дверь."])
        glossary = glossary_of({"kind": "phrase", "source": "Reloading!", "silent": True})
        translation = LlmTranslation(client, "en", "ru", glossary)
        self.assertEqual(translation.line("Reloading!"), "")
        self.assertEqual(len(client.asked), 1)

    def test_a_line_said_before_is_answered_from_memory(self):
        client = RecordingClient(["Открой дверь.", "В укрытие!"])
        translation = LlmTranslation(client, "en", "ru", Glossary())
        self.assertEqual(translation.line("Take cover!"), "В укрытие!")
        self.assertEqual(translation.line("Take cover!"), "В укрытие!")
        self.assertEqual(len(client.asked), 2)

    def test_the_scene_travels_with_the_next_line_and_names_are_hinted(self):
        client = RecordingClient(["Открой дверь.", "Боб здесь.", "Он ушёл."])
        glossary = glossary_of({"kind": "name", "source": "Bob", "reading": "Боб"})
        translation = LlmTranslation(client, "en", "ru", glossary)
        translation.line("Bob is here.")
        self.assertIn("Bob -> Боб", client.asked[1])
        translation.line("He left.")
        self.assertIn("English: Bob is here.\nRussian: Боб здесь.", client.asked[2])
        self.assertNotIn("Bob -> Боб", client.asked[2])

    def test_latin_left_in_the_answer_is_written_out(self):
        client = RecordingClient(["Открой дверь.", "Megaton ждёт."])
        translation = LlmTranslation(client, "en", "ru", Glossary())
        self.assertEqual(translation.line("Megaton is waiting."), "Мегатон ждёт.")


class FakeLlamaHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        self.send_response(200 if self.path == "/health" else 404)
        self.end_headers()
        self.wfile.write(b'{"status":"ok"}')

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        asked = json.loads(self.rfile.read(length).decode("utf-8"))
        self.server.asked.append(asked)
        answer = {"choices": [{"message": {"role": "assistant", "content": "Открой дверь."}}]}
        body = json.dumps(answer).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


class LlamaClientTest(unittest.TestCase):
    def setUp(self):
        self.server = http.server.HTTPServer(("127.0.0.1", 0), FakeLlamaHandler)
        self.server.asked = []
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.addCleanup(self.server.shutdown)
        self.client = LlamaClient(f"http://127.0.0.1:{self.server.server_port}")

    def test_reads_the_health_and_the_answer(self):
        self.assertTrue(self.client.healthy())
        messages = translation_messages("Open the door.", "English", "Russian")
        self.assertEqual(self.client.chat(messages, max_tokens=60), "Открой дверь.")
        (asked,) = self.server.asked
        self.assertEqual(asked["messages"], messages)
        self.assertEqual(asked["max_tokens"], 60)
        self.assertEqual(asked["temperature"], 0)

    def test_nothing_listening_is_not_healthy(self):
        self.assertFalse(LlamaClient("http://127.0.0.1:9").healthy())


class LlamaServerTest(unittest.TestCase):
    def test_refuses_to_start_without_the_executable(self):
        server = LlamaServer(ROOT / "nowhere", ROOT / "nowhere" / "model.gguf")
        with self.assertRaises(RuntimeError):
            server.start(wait=1)

    def test_offers_every_layer_to_the_card(self):
        server = LlamaServer("bin", "model.gguf", threads=6, context=4096)
        command = server.command(8080)
        self.assertEqual(command[command.index("-ngl") + 1], "99")
        self.assertEqual(command[command.index("-t") + 1], "6")
        self.assertEqual(command[command.index("-c") + 1], "4096")
        self.assertEqual(command[command.index("--port") + 1], "8080")
        self.assertIn("--no-webui", command)
        self.assertTrue(server.on_card)

    def test_keeps_the_layers_on_the_processor_when_told(self):
        server = LlamaServer("bin", "model.gguf", layers=0)
        self.assertEqual(server.command(8080)[server.command(8080).index("-ngl") + 1], "0")
        self.assertFalse(server.on_card)


class LayersForCardTest(unittest.TestCase):
    MODEL = int(2.5 * GIGABYTE)

    def test_offers_the_card_while_the_model_fits_past_the_reserve(self):
        # 7 GB free, 3.5 kept for whisper and the voice's growth: 3.5 left
        # for 2.5 with its room.
        self.assertEqual(layers_for_card(7 * GIGABYTE, self.MODEL), ALL_LAYERS)

    def test_keeps_the_model_on_the_processor_where_it_would_be_paged(self):
        # 6 GB free less the reserve is 2.5, under the 2.9 the model takes:
        # what the 12 GB card had after the voice, where the model was let
        # on and paged.
        self.assertEqual(layers_for_card(6 * GIGABYTE, self.MODEL), 0)
        self.assertEqual(layers_for_card(0, self.MODEL), 0)

    def test_the_reserve_and_the_room_are_the_caller_s(self):
        self.assertEqual(layers_for_card(3 * GIGABYTE, self.MODEL, reserve_bytes=0, room=1.0), ALL_LAYERS)
        self.assertEqual(layers_for_card(3 * GIGABYTE, self.MODEL, reserve_bytes=GIGABYTE, room=1.0), 0)

    def test_a_card_torch_cannot_see_is_left_to_the_build(self):
        self.assertEqual(layers_for_card(None, self.MODEL), ALL_LAYERS)

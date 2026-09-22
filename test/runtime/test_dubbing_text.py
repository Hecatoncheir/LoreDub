# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

"""The worker's text half, which needs no numpy or torch.

Run with any interpreter: python -m unittest discover -s test/runtime
"""

import json
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "assets" / "runtime"))

from dubbing_text import Glossary, TranslationMemory, readable, sentences, transliterated  # noqa: E402


class SentencesTest(unittest.TestCase):
    def test_cuts_a_line_where_each_sentence_ends(self):
        # Handed whole, Marian answered this with "Давай, давай, давай".
        self.assertEqual(
            sentences("Get to the chopper! Now! Go, go, go!"),
            ["Get to the chopper!", "Now!", "Go, go, go!"],
        )

    def test_leaves_a_line_thinking_aloud_in_one_piece(self):
        # A full stop before a small letter is a pause, not an end.
        self.assertEqual(sentences("I was... afraid."), ["I was... afraid."])

    def test_does_not_end_a_sentence_at_a_title_or_an_initial(self):
        self.assertEqual(sentences("Talk to Mr. Smith."), ["Talk to Mr. Smith."])
        self.assertEqual(sentences("J. Smith is here."), ["J. Smith is here."])

    def test_keeps_a_line_of_one_sentence(self):
        self.assertEqual(sentences("  The gate is sealed.  "), ["The gate is sealed."])


class GlossaryTest(unittest.TestCase):
    def test_files_every_shared_case_under_the_interfaces_key(self):
        # The interface's normalizedGlossaryKey reads the same file in its
        # own tests, which is what keeps the two rules one.
        fixture = json.loads((ROOT / "test" / "fixtures" / "glossary_keys.json").read_text(encoding="utf-8"))
        for case in fixture["cases"]:
            with self.subTest(source=case["source"]):
                self.assertEqual(Glossary._key(case["source"]), case["key"])

    def test_answers_a_phrase_heard_with_other_marks(self):
        glossary = Glossary()
        glossary.replace({"entries": [{"kind": "phrase", "source": "Fire in the hole!", "reading": "Граната!"}]})
        self.assertEqual(glossary.said("fire in the hole."), "Граната!")

    def test_a_silenced_phrase_is_said_as_nothing_rather_than_not_known(self):
        glossary = Glossary()
        glossary.replace({"entries": [{"kind": "phrase", "source": "Reloading!", "silent": True}]})
        self.assertEqual(glossary.said("Reloading!"), "")
        self.assertIsNone(glossary.said("We are reloading the truck."))

    def test_reads_a_file_of_the_wrong_shape_as_empty(self):
        for written in ([], 7, None, {"entries": {}}, {"entries": [1, "a", None]}):
            with self.subTest(written=written):
                glossary = Glossary()
                glossary.replace(written)
                self.assertEqual((glossary.names, glossary.phrases, glossary.words), ({}, {}, []))


class LatinTest(unittest.TestCase):
    def test_writes_a_name_out_in_cyrillic(self):
        written = transliterated("Rapture")
        self.assertTrue(written)
        self.assertFalse(any("a" <= letter.lower() <= "z" for letter in written))

    def test_leaves_a_translated_line_alone(self):
        self.assertEqual(readable("Ворота закрыты.", "The gate is sealed.", translate=None), "Ворота закрыты.")

    def test_writes_a_name_the_players_way_where_they_wrote_it_down(self):
        glossary = Glossary()
        glossary.replace({"entries": [{"kind": "name", "source": "Megaton", "reading": "Мегатонна"}]})
        self.assertEqual(
            readable("Добро пожаловать в Megaton.", "Welcome to Megaton.", translate=None, glossary=glossary),
            "Добро пожаловать в Мегатонна.",
        )

    def test_asks_again_for_a_line_passed_through_untranslated(self):
        asked = []

        def translate(text):
            asked.append(text)
            return "Иди на склад и найди ключ"

        answer = readable("Go to the storage and find the key", "Go to the storage and find the key", translate)
        self.assertEqual(asked, ["go to the storage and find the key"])
        self.assertEqual(answer, "Иди на склад и найди ключ")


class TranslationMemoryTest(unittest.TestCase):
    def test_answers_a_sentence_it_translated_before_however_it_was_spaced(self):
        memory = TranslationMemory()
        memory.put("Take cover!", "В укрытие!")
        self.assertEqual(memory.get("Take  cover!"), "В укрытие!")
        self.assertIsNone(memory.get("Reloading!"))

    def test_lets_the_oldest_go_once_it_is_full(self):
        memory = TranslationMemory(capacity=2)
        memory.put("one", "один")
        memory.put("two", "два")
        memory.get("one")  # asked for again, so it is the newest now
        memory.put("three", "три")
        self.assertIsNone(memory.get("two"))
        self.assertEqual(memory.get("one"), "один")


if __name__ == "__main__":
    unittest.main()

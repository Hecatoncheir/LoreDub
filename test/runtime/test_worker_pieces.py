# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

"""The worker's own small pieces. They import numpy with the worker, so they
run where the bundled interpreter does and are passed over elsewhere:

build/windows/x64/runner/Debug/runtime/python/python.exe -m unittest discover -s test/runtime
"""

import importlib.util
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "assets" / "runtime"))

HAS_NUMPY = importlib.util.find_spec("numpy") is not None
if HAS_NUMPY:
    import audio
    import inference_worker as worker
    import voices


@unittest.skipUnless(HAS_NUMPY, "the worker imports numpy")
class MostHeardTest(unittest.TestCase):
    def test_answers_the_gender_most_files_were_heard_as(self):
        self.assertEqual(voices.most_heard(["male", "female", "male", None]), "male")

    def test_settles_a_tie_by_the_clip_the_card_keeps(self):
        # Settled by a set's order, it came out one way in one run and the
        # other way in the next.
        for tie in ("male", "female"):
            with self.subTest(tie=tie):
                self.assertEqual(voices.most_heard(["male", "female"], tie=tie), tie)

    def test_hears_nobody_in_files_that_were_heard_as_nobody(self):
        self.assertIsNone(voices.most_heard([None, None]))


@unittest.skipUnless(HAS_NUMPY, "the worker imports numpy")
class SpeedTest(unittest.TestCase):
    def test_keeps_a_lines_pace_inside_what_the_retiming_can_take(self):
        self.assertEqual(audio.request_speed({"speed": 9}, 1.0), audio.FASTEST_SPEED)
        self.assertEqual(audio.request_speed({"speed": 0.1}, 1.0), audio.SLOWEST_SPEED)
        self.assertEqual(audio.request_speed({"speed": 1.3}, 1.0), 1.3)

    def test_falls_back_to_the_sessions_pace_on_anything_unreadable(self):
        for request in ({}, {"speed": "fast"}, {"speed": None}):
            with self.subTest(request=request):
                self.assertEqual(audio.request_speed(request, 1.1), 1.1)


@unittest.skipUnless(HAS_NUMPY, "the worker imports numpy")
class HandlersTest(unittest.TestCase):
    def test_names_a_handler_for_every_request_the_interface_sends(self):
        keys = [key for key, _ in worker.HANDLERS]
        for key in ("fingerprint", "voiceFrom", "voicedBy", "glossary", "speaker", "asHeard",
                    "listen", "preview", "diarize"):
            self.assertIn(key, keys)
        self.assertEqual(len(keys), len(set(keys)))


if __name__ == "__main__":
    unittest.main()

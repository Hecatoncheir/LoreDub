# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

"""The worker's own small pieces. They import numpy with the worker, which
CI installs beside the runner's Python; without it they are passed over:

python -m pip install numpy==2.2.6
python -m unittest discover -s test/runtime
"""

import importlib.util
import json
import pathlib
import sys
import tempfile
import types
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "assets" / "runtime"))

HAS_NUMPY = importlib.util.find_spec("numpy") is not None
if HAS_NUMPY:
    import numpy as np

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
class VoicePackagesTest(unittest.TestCase):
    def test_reads_the_reference_clips_with_their_transcripts(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            (root / "af_heart.wav").write_bytes(b"RIFF")
            (root / "af_heart.txt").write_text("The old keeper.\n", encoding="utf-8")
            (root / "ru_male_0.wav").write_bytes(b"RIFF")
            (root / "notes.txt").write_text("not a clip", encoding="utf-8")
            clips = voices.reference_clips(root)
        self.assertEqual(sorted(clips), ["af_heart", "ru_male_0"])
        self.assertEqual(clips["af_heart"], (str(root / "af_heart.wav"), "The old keeper."))
        self.assertEqual(clips["ru_male_0"][1], "")
        self.assertEqual(voices.reference_clips(pathlib.Path(directory) / "gone"), {})

    def test_tells_a_qwen_package_by_its_config(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            self.assertFalse(voices.is_qwen_package(root))
            (root / "config.json").write_text('{"model_type": "qwen3_tts"}', encoding="utf-8")
            self.assertTrue(voices.is_qwen_package(root))
            (root / "config.json").write_text('{"sample_rate": 22050}', encoding="utf-8")
            self.assertFalse(voices.is_qwen_package(root))

    def test_finds_a_cards_recording_beside_the_cast_file(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            cast_file = root / "characters.json"
            cast_file.write_text(
                json.dumps(
                    {
                        "characters": [
                            {"id": "guard", "vector": [0.1, 0.2]},
                            {"id": "smith", "vector": [0.3, 0.4]},
                        ]
                    }
                ),
                encoding="utf-8",
            )
            (root / "characters").mkdir()
            (root / "characters" / "guard.wav").write_bytes(b"RIFF")
            cast = voices.CharacterCast(str(cast_file))
            self.assertEqual(cast.clip_of(0), str(root / "characters" / "guard.wav"))
            self.assertIsNone(cast.clip_of(1))
        # A cast with no file has no recordings beside it either.
        self.assertEqual(len(voices.CharacterCast("")), 0)


@unittest.skipUnless(HAS_NUMPY, "the worker imports numpy")
class ReferenceForTest(unittest.TestCase):
    """The clip a voice that clones reads a speaker from."""

    def casting(self, work):
        args = types.SimpleNamespace(
            male_voices="",
            female_voices="",
            follow_speaker=False,
            characters="",
            as_heard="",
            work_directory=work,
        )
        models = types.SimpleNamespace(torch=None, converter=None, bank=None, voices=[], speaker="x")
        return worker.Casting(args, models)

    def clip(self, root, name, seconds):
        path = root / name
        audio.write_wave(path, np.zeros(int(16000 * seconds), dtype=np.float32), 16000)
        return str(path)

    def test_keeps_the_longest_clear_line_of_a_speaker_in_the_work_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            casting = self.casting(str(root / "work"))
            (root / "work").mkdir()
            short = self.clip(root, "short.wav", 1.0)
            longer = self.clip(root, "longer.wav", 3.5)
            first, said = casting.reference_for(audio.Heard(short), "voice", 3, "Go.")
            self.assertTrue(first.startswith(str(root / "work")))
            self.assertEqual(said, "Go.")
            # A longer line of the same speaker replaces a short one, and
            # brings what it says with it...
            second, said = casting.reference_for(audio.Heard(longer), "voice", 3, "Take cover!")
            self.assertEqual(second, first)
            self.assertEqual(said, "Take cover!")
            self.assertAlmostEqual(audio.Heard(second).seconds, 3.5, places=2)
            # ...and a shorter one after it does not.
            _, said = casting.reference_for(audio.Heard(short), "voice", 3, "Go.")
            self.assertEqual(said, "Take cover!")
            self.assertAlmostEqual(audio.Heard(second).seconds, 3.5, places=2)

    def test_a_line_belonging_to_nobody_reads_from_itself_or_the_last_clip(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            casting = self.casting(str(root / "work"))
            own = self.clip(root, "own.wav", 2.0)
            self.assertEqual(casting.reference_for(audio.Heard(own), "voice", None), (own, ""))
            self.assertEqual(casting.reference_for(audio.Heard(None), "voice", None), (own, ""))
            self.assertIsNone(self.casting(str(root)).reference_for(audio.Heard(None), None, None))


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

# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

"""The worker's sound: the retiming of a line, the pitch a voice is placed
by, and where a recording is cut between two speakers. They need numpy and
nothing more, which CI installs beside the runner's Python."""

import importlib.util
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "assets" / "runtime"))

HAS_NUMPY = importlib.util.find_spec("numpy") is not None
if HAS_NUMPY:
    import numpy as np

    import audio

RATE = 16000


def tone(hertz, seconds, rate=RATE, level=0.5):
    moments = np.arange(int(rate * seconds)) / rate
    return (level * np.sin(2 * np.pi * hertz * moments)).astype(np.float32)


def silence(seconds, rate=RATE):
    return np.zeros(int(rate * seconds), dtype=np.float32)


class Fingerprint:
    """What the converter's encoder hands back, as far as `as_vector` reads it."""

    def __init__(self, values):
        self._values = np.asarray(values, dtype=np.float32)

    def flatten(self):
        return self

    def float(self):
        return self

    def cpu(self):
        return self

    def numpy(self):
        return self._values


class PitchEncoder:
    """Tells a low voice from a high one by how often the block crosses zero,
    and says so all at once, as a real encoder does between two people."""

    def embed(self, block, rate):
        crossings = np.count_nonzero(np.diff(np.signbit(block))) / (len(block) / rate) / 2
        return Fingerprint([1.0, 0.0] if crossings < 225 else [0.0, 1.0])


@unittest.skipUnless(HAS_NUMPY, "the worker imports numpy")
class ChangeSpeedTest(unittest.TestCase):
    def test_leaves_a_line_at_its_own_pace_alone(self):
        samples = tone(200, 1.0)
        self.assertIs(audio.change_speed(samples, 1.0, RATE), samples)
        self.assertIs(audio.change_speed(samples, 1.005, RATE), samples)

    def test_leaves_nothing_as_nothing(self):
        empty = np.zeros(0, dtype=np.float32)
        self.assertEqual(audio.change_speed(empty, 1.5, RATE).size, 0)

    def test_a_faster_line_is_shorter_by_its_speed(self):
        retimed = audio.change_speed(tone(200, 2.0), 2.0, RATE)
        self.assertAlmostEqual(len(retimed) / RATE, 1.0, delta=0.1)

    def test_a_slower_line_is_longer_by_its_speed(self):
        retimed = audio.change_speed(tone(200, 1.0), 0.5, RATE)
        self.assertAlmostEqual(len(retimed) / RATE, 2.0, delta=0.15)

    def test_keeps_the_pitch_it_retimes(self):
        retimed = audio.change_speed(tone(200, 2.0), 1.5, RATE)
        self.assertAlmostEqual(audio.median_f0(retimed, RATE), 200, delta=5)

    def test_stays_inside_what_a_sample_can_hold(self):
        retimed = audio.change_speed(tone(200, 1.0, level=1.0), 1.3, RATE)
        self.assertLessEqual(float(np.max(np.abs(retimed))), 1.0)


@unittest.skipUnless(HAS_NUMPY, "the worker imports numpy")
class MedianF0Test(unittest.TestCase):
    def test_hears_the_pitch_of_a_low_voice(self):
        self.assertAlmostEqual(audio.median_f0(tone(120, 1.0), RATE), 120, delta=3)

    def test_hears_the_pitch_of_a_high_voice(self):
        self.assertAlmostEqual(audio.median_f0(tone(220, 1.0), RATE), 220, delta=4)

    def test_hears_nobody_in_silence(self):
        self.assertIsNone(audio.median_f0(silence(1.0), RATE))

    def test_hears_nobody_in_a_clip_shorter_than_a_frame(self):
        self.assertIsNone(audio.median_f0(tone(150, 0.01), RATE))

    def test_is_placed_by_the_loud_frames_rather_than_the_quiet_ones(self):
        # Room tone under the line is a pitch of its own, and quieter: counted
        # with the rest it would move the median to the 200 Hz stretch.
        samples = np.concatenate(
            [tone(300, 0.4, level=0.02), tone(120, 0.35, level=0.6), tone(200, 0.25, level=0.6)]
        )
        self.assertAlmostEqual(audio.median_f0(samples, RATE), 120, delta=4)

    def test_places_the_pitch_it_hears_as_a_gender(self):
        self.assertEqual(audio.gender_of_pitch(audio.median_f0(tone(120, 1.0), RATE)), "male")
        self.assertEqual(audio.gender_of_pitch(audio.median_f0(tone(220, 1.0), RATE)), "female")
        self.assertIsNone(audio.gender_of_pitch(audio.median_f0(tone(165, 1.0), RATE)))


@unittest.skipUnless(HAS_NUMPY, "the worker imports numpy")
class QuietestMomentTest(unittest.TestCase):
    def test_moves_to_the_pause_nearest_the_change(self):
        samples = np.concatenate([tone(150, 1.0), silence(0.06), tone(150, 1.0)])
        self.assertAlmostEqual(audio.quietest_moment(samples, RATE, 1.2), 1.03, delta=0.03)

    def test_looks_no_further_than_the_snap(self):
        samples = np.concatenate([tone(150, 1.0), silence(0.06), tone(150, 2.0)])
        moment = audio.quietest_moment(samples, RATE, 2.0)
        self.assertLessEqual(abs(moment - 2.0), audio.SPLIT_SNAP_SECONDS)

    def test_stays_put_where_there_is_nothing_around_to_look_at(self):
        self.assertEqual(audio.quietest_moment(tone(150, 0.01), RATE, 0.5), 0.5)


@unittest.skipUnless(HAS_NUMPY, "the worker imports numpy")
class SpeakerCutsTest(unittest.TestCase):
    def test_leaves_a_short_recording_whole(self):
        samples = np.concatenate([tone(120, 1.4), tone(300, 1.4)])
        self.assertEqual(audio.speaker_cuts(PitchEncoder(), samples, RATE), [])

    def test_leaves_one_voice_whole(self):
        self.assertEqual(audio.speaker_cuts(PitchEncoder(), tone(120, 6.0), RATE), [])

    def test_cuts_between_two_voices_in_the_pause_between_them(self):
        samples = np.concatenate([tone(120, 2.95), silence(0.1), tone(300, 2.95)])
        cuts = audio.speaker_cuts(PitchEncoder(), samples, RATE)
        self.assertEqual(len(cuts), 1)
        self.assertAlmostEqual(cuts[0], 3.0, delta=0.06)

    def test_cuts_nothing_that_would_leave_a_piece_under_a_second(self):
        samples = np.concatenate([tone(120, 4.4), silence(0.05), tone(300, 0.6)])
        self.assertEqual(audio.speaker_cuts(PitchEncoder(), samples, RATE), [])


if __name__ == "__main__":
    unittest.main()

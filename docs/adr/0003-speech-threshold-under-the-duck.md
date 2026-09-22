# 0003. The speech threshold follows the game down

Status: accepted. Code: `GameDucker`, `AppSettings.duckedVolume`, `ProcessLoopbackCapture::SetSpeechAttenuation`.

## Decision

Windows takes the process-loopback tap after the session volume, so the game
is never turned below `audibleDuck` (0.1), and whatever turns it down hands
the capture the factor it applied: the speech threshold is `kSpeechRms` times
that factor, not a fixed level. That is what makes `duckWhileSpeaking` -- a
duck that lasts a line, on by default -- safe.

## Why, measured

As it stood in `CLAUDE.md` when the decision was taken, numbers and
all; measure again before changing what it holds up.

How far the game is turned down while it is dubbed is `AppSettings`' business
rather than the slider's, because Windows takes the process-loopback tap
*after* the session volume `ld_set_process_volume` sets: turning the game
down turns the capture down with it. Measured against a tone of raw peak
2614, half volume gave 1308, 18% gave 472, and zero gave nothing at all — not
one segment in eight seconds. `duckedVolume` therefore holds `originalVolume`
to `audibleDuck` (0.1), the game's own sound being what the pipeline listens
to; both volume sliders — the settings screen and the output node — read
`audibleDuck`/`loudestDuck`/`duckDivisions`, so a number set on one can be
set again on the other. The screen session turns the game down the same
way, though it has no ear in it: a switch that silenced it outright was
offered there and is gone, nothing but that page could reach it. The pace sliders pair the same way over
`slowestSpeech`/`fastestSpeech`/`speechDivisions`, with `chosenSpeed` holding
a stored value inside them. `AppSettings.duckWhileSpeaking` replaces the
session-long duck with one that lasts a line: `PlaybackScheduler.onSpeaking`
reports the edges of the dubbing's own speech — consecutive lines are one
stretch, so the game is not lifted between two lines of a scene — and
`GameDucker` (`data/services/game_ducker.dart`) turns the game down and back.
It is the one place either duck is decided -- the session's, again on a
resume, and the line's -- which were spread over the repository and the
engine until a stopped session left the game quiet for good. It is on
by default, which the compensated speech threshold below is what makes safe.

Whatever turns the game down tells the capture, because the threshold that
decides what counts as speech is measured on the ducked signal:
`ld_set_process_volume` hands `ProcessLoopbackCapture::SetSpeechAttenuation`
the factor it applied, and the loop compares against `kSpeechRms` times that
factor. Fixed, the threshold grew stricter the quieter the game was put — a
tone giving three segments per window at full volume gave none at 18%, and
gives three again with the threshold following — so a player who turned the
game down was quietly turning recognition down with it. It is also what makes
`duckWhileSpeaking` safe: the drop lands in the middle of a captured phrase,
and a fixed threshold would read it as the phrase ending.

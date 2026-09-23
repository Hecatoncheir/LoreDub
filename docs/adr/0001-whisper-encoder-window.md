# 0001. Recognition shortens the encoder window to 1000 at most

Status: accepted. Code: `lib/src/data/services/whisper_runner.dart`, `AppSettings.roughRecognition`.

## Decision

whisper.cpp runs one-shot per segment. `AppSettings.roughRecognition` (off by
default) passes `-ac 1000`, which is as far as the window goes: 768 and 512
change what is said. `-fa` and the resident `whisper-server` stay unused --
neither is faster here.

## Why, measured

As it stood in `CLAUDE.md` when the decision was taken, numbers and
all; measure again before changing what it holds up.

Recognition was the larger half of the delay before a line is heard -- 1.33 s
of a 1.5 s chain on twelve CPU threads, against 0.06 for translation and
0.07 for the Silero voice of the time; Vosk, which replaced it, takes about
1 s a line of its own -- and nearly all of recognition is the encoder, which works over a
fixed window whatever the phrase is worth. `AppSettings.roughRecognition`
shortens that window with `-ac`: measured over nine clips, 1000 took 897 ms
rather than 1329 and said the same words on all nine, two differing only by
a comma. It is off by default and the number is not to be lowered without
measuring again -- 768 turned "struggling to reconcile" into "struggling the
reconciled", and 512 had whisper repeating a phrase back to itself, which
would then be translated and voiced. Two flags that look like they belong
here do nothing: `-fa` measured 1536 ms against 1328 over five runs, and the
resident `whisper-server` that ships in the same archive answered in
1301-1358 ms against the one-shot `whisper-cli`'s 1319-1348, spending the
model load it saves on its own upload.

## Measured later: the resident server

On 2026-09-23, on the RTX 3080 Ti with `large-v3-turbo` q5_0, `whisper-cli`
took about 3.5 s per phrase -- most of it loading the model again -- where
`whisper-server.exe` from the same build, kept running through the session,
answered a 5.8 s clip in 447 ms cold and 207-212 ms after. The server takes
`language`, `translate`, `suppress_non_speech` and `audio_ctx` per request
and returns the language it detected as a name in `verbose_json`. So the
server is taken up (`ResidentWhisper`, `whisper_server.dart`), behind the
same call the one-shot runner answered; `-fa` is on by default in the server
and was not measured apart.

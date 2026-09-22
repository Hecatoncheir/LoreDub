# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

"""How the worker speaks to the application: one JSON object a line on
stdout, which nothing else is let write to."""

import json
import sys


def use_utf8_streams():
    """Pipes default to the Windows ANSI code page, which mangles Cyrillic.

    The Dart side reads this process as UTF-8, so a translated phrase would be
    dropped on decoding while the ASCII handshake still succeeded.
    """
    for stream in (sys.stdin, sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass


# Where the replies go. The protocol is the process's stdout and nothing
# else writes to it: claim_protocol() moves sys.stdout onto stderr, so a
# library that prints -- a warning, a progress bar without a line ending --
# lands among the diagnostics rather than inside the next reply.
PROTOCOL = sys.stdout


def claim_protocol():
    """Keeps stdout for replies alone, and sends every other print to stderr."""
    global PROTOCOL
    PROTOCOL = sys.stdout
    sys.stdout = sys.stderr


def reply(value):
    PROTOCOL.write(json.dumps(value, ensure_ascii=False) + "\n")
    PROTOCOL.flush()


def report_progress(value, stage):
    """Announces the step that is about to run, with its share of the startup.

    The shares come from measuring a warm start: importing torch and
    transformers takes far longer than loading the models themselves. The
    stage is a code, not a sentence: the application writes it out in
    whichever language its interface is set to.
    """
    reply({"type": "progress", "value": value, "stage": stage})

# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

"""Converts the catalogue's Marian translators to CTranslate2 int8.

The models Helsinki-NLP publishes are PyTorch checkpoints meant for
transformers, which loads them in float32 and generates through Python. The
same weights under CTranslate2 read a line in about half the time and take
half the disk. The conversion is ours to make once per model rather than
every player's to make on every machine: it wants a transformers newer than
the shipped runtime carries, and it would cost each of them a minute and the
peak memory of a float32 load.

What it writes is what the catalogue then points at: the converted model, the
tokenizer files it still needs, a NOTICE naming the authors and the change --
CC-BY-4.0 asks for both -- and the catalogue entry itself, sizes and digests
filled in.

    python scripts/convert_translators.py --all --work build/translators
    python scripts/convert_translators.py --model Helsinki-NLP/opus-mt-en-de \
        --id marian-en-de --language de

Needs a Python with torch, transformers and ctranslate2 -- not the shipped
runtime, whose transformers is older than the converter expects:

    pip install -U transformers ctranslate2
"""

import argparse
import hashlib
import os
import pathlib
import shutil
import sys
import urllib.error
import urllib.request

HOST = "https://huggingface.co"

# The translators of the catalogue, in its order. English is not among them
# and never will be: whisper hands English over already, so that language is
# a voice with no translator behind it.
TRANSLATORS = [
    ("opus-mt-tc-big-en-zle", "ru", "Helsinki-NLP/opus-mt-tc-big-en-zle"),
    ("marian-en-de", "de", "Helsinki-NLP/opus-mt-en-de"),
    ("marian-en-es", "es", "Helsinki-NLP/opus-mt-en-es"),
    ("marian-en-fr", "fr", "Helsinki-NLP/opus-mt-en-fr"),
    ("marian-en-uk", "uk", "Helsinki-NLP/opus-mt-en-uk"),
]

# What the converter reads. Some models ship fewer of these, so one that is
# missing is not an error.
UPSTREAM_FILES = [
    "config.json",
    "generation_config.json",
    "pytorch_model.bin",
    "source.spm",
    "target.spm",
    "tokenizer_config.json",
    "vocab.json",
    "special_tokens_map.json",
]

# The converter writes the model alone; the tokenizer travels with it, the
# text still having to be cut into the pieces these weights were trained on.
TOKENIZER_FILES = ["source.spm", "target.spm", "vocab.json", "tokenizer_config.json"]

NOTICE = """\
{repository}

Translation model of the Helsinki-NLP / OPUS-MT project (Tiedemann &
Thottingal), published at {host}/{repository} under the Creative
Commons Attribution 4.0 International licence (CC-BY-4.0):
https://creativecommons.org/licenses/by/4.0/

Changed by the LoreDub contributors: converted from the PyTorch checkpoint to
the CTranslate2 model format with int8 quantization, by CTranslate2
{version}. The weights are otherwise those of the published model, and
nothing here restricts what the licence allows.
"""


def fetch(repository, name, into):
    """One file of a model repository, fetched once and kept."""
    target = into / name
    if target.exists():
        return target
    url = f"{HOST}/{repository}/resolve/main/{name}"
    print(f"  fetching {name}", flush=True)
    try:
        with urllib.request.urlopen(url) as response, open(target, "wb") as file:
            shutil.copyfileobj(response, file)
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None
        raise
    return target


def upstream_model(repository, work):
    directory = work / "upstream" / repository.split("/")[-1]
    directory.mkdir(parents=True, exist_ok=True)
    print(f"upstream {repository}", flush=True)
    for name in UPSTREAM_FILES:
        fetch(repository, name, directory)
    return directory


def convert(upstream, output, repository):
    import ctranslate2
    from ctranslate2.converters import TransformersConverter

    if output.exists():
        shutil.rmtree(output)
    print(f"converting -> {output.name}", flush=True)
    TransformersConverter(str(upstream)).convert(str(output), quantization="int8")
    for name in TOKENIZER_FILES:
        file = upstream / name
        if file.exists():
            shutil.copy2(file, output / name)
    (output / "NOTICE").write_text(
        NOTICE.format(repository=repository, host=HOST, version=ctranslate2.__version__),
        encoding="utf-8",
    )
    return output


def digest(path):
    hashed = hashlib.sha256()
    with open(path, "rb") as file:
        for block in iter(lambda: file.read(1 << 20), b""):
            hashed.update(block)
    return hashed.hexdigest()


def entry(identifier, language, directory):
    """The catalogue entry for a converted model, byte for byte."""
    files = sorted(path for path in directory.iterdir() if path.is_file())
    lines = [
        "  _converted(",
        f"    id: '{identifier}',",
        f"    language: '{language}',",
        "    files: const {",
    ]
    for path in files:
        lines.append(f"      '{path.name}': ({path.stat().st_size}, '{digest(path)}'),")
    lines.append("    },")
    lines.append("  ),")
    return "\n".join(lines)


def installed_models():
    """Where the application keeps what it downloaded, on this machine."""
    return pathlib.Path(os.environ["APPDATA"]) / "LoreDub contributors" / "LoreDub" / "models"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--all", action="store_true", help="every translator of the catalogue")
    parser.add_argument("--model", help="a HuggingFace repository, such as Helsinki-NLP/opus-mt-en-de")
    parser.add_argument("--id", help="the catalogue identifier to write it under")
    parser.add_argument("--language", help="the dubbing language it serves")
    parser.add_argument("--work", default="build/translators", help="where sources and results go")
    parser.add_argument(
        "--install",
        action="store_true",
        help="also put the result where the application looks, to try it on this machine",
    )
    arguments = parser.parse_args()

    try:
        import ctranslate2  # noqa: F401
        import transformers  # noqa: F401
    except ImportError as error:
        sys.exit(f"{error}. Install them first:\n    pip install -U transformers ctranslate2")

    if arguments.all:
        wanted = TRANSLATORS
    elif arguments.model and arguments.id and arguments.language:
        wanted = [(arguments.id, arguments.language, arguments.model)]
    else:
        sys.exit("either --all, or --model with --id and --language")

    work = pathlib.Path(arguments.work).resolve()
    (work / "upstream").mkdir(parents=True, exist_ok=True)
    entries = []
    for identifier, language, repository in wanted:
        upstream = upstream_model(repository, work)
        output = convert(upstream, work / identifier, repository)
        entries.append(entry(identifier, language, output))
        if arguments.install:
            target = installed_models() / identifier
            if target.exists():
                shutil.rmtree(target)
            shutil.copytree(output, target)
            print(f"  installed into {target}", flush=True)

    print("\n" + "\n\n".join(entries))


if __name__ == "__main__":
    main()

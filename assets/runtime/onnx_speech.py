# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

"""Where a voice runs.

Both voices are onnxruntime sessions, and the one rule they must not answer
differently is which device they are opened on: the card is reached through
onnxruntime-gpu, which the CUDA runtime installs beside torch and which finds
its CUDA and cuDNN libraries in the torch the worker imports first. The
processor's build of onnxruntime offers no such provider, and the voice stays
where it is.
"""


def providers_for(device):
    """Where to read, best first."""
    import onnxruntime

    if device == "cuda" and "CUDAExecutionProvider" in onnxruntime.get_available_providers():
        return ["CUDAExecutionProvider", "CPUExecutionProvider"]
    return ["CPUExecutionProvider"]

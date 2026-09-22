// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/model_package.dart';
import '../../domain/runtime_package.dart';

export '../../domain/runtime_package.dart' show torchCudaRuntimeId, whisperCudaRuntimeId;

const whisperCudaVersion = 'v1.8.2';

/// Read only: a list handed out to every screen must not be changed by one
/// of them under the others.
final runtimeCatalog = List<RuntimePackage>.unmodifiable(<RuntimePackage>[
  RuntimePackage(
    id: whisperCudaRuntimeId,
    kind: RuntimeInstallKind.archive,
    approximateBytes: 457274520,
    probeFileName: 'whisper-cli.exe',
    artifacts: [
      ModelArtifact(
        fileName: 'whisper-cublas-12.4.0-bin-x64.zip',
        url: Uri.parse(
          'https://github.com/ggml-org/whisper.cpp/releases/download/'
          '$whisperCudaVersion/whisper-cublas-12.4.0-bin-x64.zip',
        ),
        byteSize: 457274520,
        hash: '54a3c012e6c567e2e8bed874cdf49c55f018ec8d90bb5d5271568aa573291b2d',
      ),
    ],
  ),
  RuntimePackage(
    id: torchCudaRuntimeId,
    kind: RuntimeInstallKind.wheel,
    // The CUDA wheel carries its own cuDNN and cuBLAS, which is where the
    // bulk sits; the dependencies pip adds come to a few megabytes, and the
    // onnxruntime-gpu wheel to 215 more.
    approximateBytes: 2716982502 + 214923507,
    // onnxruntime-gpu is what reads the Vosk voice on the card, with the
    // CUDA 12 and cuDNN 9 libraries this torch brought -- measured, 280 to 330 ms
    // a line against 850 to 920 on twelve processor threads. It is the probe
    // because it is the newer half: a directory holding torch alone was put
    // there before the voice could use the card, and has it added.
    probeFileName: 'onnxruntime',
    previousProbeFileName: 'torch',
    // Built for the bundled Python. Another interpreter gets the index route.
    wheelPython: 'cp311',
    artifacts: [
      ModelArtifact(
        fileName: 'torch-2.7.1+cu126-cp311-cp311-win_amd64.whl',
        url: Uri.parse(
          'https://download.pytorch.org/whl/cu126/torch-2.7.1%2Bcu126-cp311-cp311-win_amd64.whl',
        ),
        byteSize: 2716982502,
        hash: 'f3af23387ac106b5b01dbef0eb021883e0c00ff4073477b7ce1cbade5ef5038d',
      ),
    ],
    companions: const ['onnxruntime-gpu==1.22.0'],
    pipArguments: const [
      '--index-url',
      'https://download.pytorch.org/whl/cu126',
      'torch==2.7.1+cu126',
    ],
  ),
]);

RuntimePackage? runtimePackageById(String id) {
  for (final package in runtimeCatalog) {
    if (package.id == id) return package;
  }
  return null;
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/model_package.dart';
import '../../domain/runtime_package.dart';

/// Where the GPU runtimes come from.
///
/// Only the two heavy ones are here. The Vulkan build of whisper.cpp is small
/// enough to ship with the installer, so it has no entry: nothing has to be
/// fetched before an AMD card can be used.
const whisperCudaRuntimeId = 'whisper-cuda';
const torchCudaRuntimeId = 'torch-cuda';

const whisperCudaVersion = 'v1.8.2';

final runtimeCatalog = <RuntimePackage>[
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
    // bulk sits; the dependencies pip adds come to a few megabytes.
    approximateBytes: 2716982502,
    probeFileName: 'torch',
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
    pipArguments: const [
      '--index-url',
      'https://download.pytorch.org/whl/cu126',
      'torch==2.7.1+cu126',
    ],
  ),
];

RuntimePackage? runtimePackageById(String id) {
  for (final package in runtimeCatalog) {
    if (package.id == id) return package;
  }
  return null;
}

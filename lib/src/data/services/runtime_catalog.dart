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
  const RuntimePackage(
    id: torchCudaRuntimeId,
    kind: RuntimeInstallKind.pip,
    // The CUDA wheels carry their own cuDNN and cuBLAS, which is where the
    // bulk sits; pip reports the exact figure while it works.
    approximateBytes: 2900000000,
    probeFileName: 'torch',
    pipArguments: [
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

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import '../../domain/model_package.dart';
import '../../domain/runtime_package.dart';

export '../../domain/runtime_package.dart'
    show llamaCudaRuntimeId, llamaVulkanRuntimeId, torchCudaRuntimeId, whisperCudaRuntimeId;

const whisperCudaVersion = 'v1.8.2';

/// The llama.cpp release the bundled CPU and Vulkan builds come from, which
/// the CUDA one has to match: `scripts/prepare_windows_runtime.ps1` fetches
/// the same tag.
const llamaVersion = 'b11118';
const _llamaReleases = 'https://github.com/ggml-org/llama.cpp/releases/download/$llamaVersion';

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
  // llama.cpp's CUDA build, for the translator that is a language model.
  // The release keeps the CUDA runtime in an archive of its own, so the two
  // are fetched together and unpacked into one directory; both keep their
  // files at the top, so there is nothing to lift.
  RuntimePackage(
    id: llamaCudaRuntimeId,
    kind: RuntimeInstallKind.archive,
    approximateBytes: 253782317 + 391443627,
    probeFileName: 'llama-server.exe',
    artifacts: [
      ModelArtifact(
        fileName: 'llama-$llamaVersion-bin-win-cuda-12.4-x64.zip',
        url: Uri.parse('$_llamaReleases/llama-$llamaVersion-bin-win-cuda-12.4-x64.zip'),
        byteSize: 253782317,
        hash: '09d262cb22c26d276a8c2cd38e0ddb405404c4c60e355c2ed96cda8e77538c59',
      ),
      ModelArtifact(
        fileName: 'cudart-llama-bin-win-cuda-12.4-x64.zip',
        url: Uri.parse('$_llamaReleases/cudart-llama-bin-win-cuda-12.4-x64.zip'),
        byteSize: 391443627,
        hash: '8c79a9b226de4b3cacfd1f83d24f962d0773be79f1e7b75c6af4ded7e32ae1d6',
      ),
    ],
  ),
]);

RuntimePackage? runtimePackageById(String id) {
  for (final package in runtimeCatalog) {
    if (package.id == id) return package;
  }
  return null;
}

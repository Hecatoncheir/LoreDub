// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

Future<void> main(List<String> arguments) async {
  await build(arguments, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final windows = input.config.code.targetOS == OS.windows;
    final builder = CBuilder.library(
      name: 'lore_dub_native',
      assetName: 'src/native/lore_dub_native.g.dart',
      sources: const [
        'native/lore_dub_native.cpp',
        'native/process_loopback_capture.cpp',
        'native/ocr_capture.cpp',
      ],
      includes: const ['native'],
      language: Language.cpp,
      std: 'c++20',
      flags: windows ? const ['/EHsc'] : const [],
      libraries: windows
          ? const [
              'ole32',
              'runtimeobject',
              'winmm',
              'mmdevapi',
              'user32',
              'gdi32',
              'windowsapp',
              'dxgi',
            ]
          : const [],
    );
    await builder.run(input: input, output: output);
  });
}

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
        'native/audio_decoder.cpp',
        'native/frame_overlay.cpp',
        'native/lore_dub_native.cpp',
        'native/process_loopback_capture.cpp',
        'native/ocr_capture.cpp',
        'native/snapshot_overlay.cpp',
      ],
      includes: const ['native'],
      language: Language.cpp,
      std: 'c++20',
      // Warnings at the fourth level and standard C++ rather than MSVC's
      // leniencies, sources read as UTF-8 (they hold Cyrillic in comments and
      // strings), and the SDL checks. The native tests build under the same
      // flags with /WX (tool/native_tests.ps1).
      flags: windows ? const ['/EHsc', '/W4', '/permissive-', '/utf-8', '/sdl'] : const [],
      // Once for every file, rather than a #define NOMINMAX in each that
      // must come before <windows.h> or std::max stops compiling.
      defines: windows
          ? const {'NOMINMAX': null, 'WIN32_LEAN_AND_MEAN': null, 'UNICODE': null, '_UNICODE': null}
          : const {},
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
              // Windows' own decoders, which is how a dropped ogg or mp3
              // becomes a recording the converter can measure.
              'mfplat',
              'mfreadwrite',
              'mfuuid',
            ]
          : const [],
    );
    await builder.run(input: input, output: output);
  });
}

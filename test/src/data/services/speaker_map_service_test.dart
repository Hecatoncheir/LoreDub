// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/speaker_map_service.dart';
import 'package:path/path.dart' as path;

import '../../../support/temporary_directory.dart';

void main() {
  late Directory temp;
  late SpeakerMapService service;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('lore_dub_speaker_map_');
    service = SpeakerMapService(root: () async => temp);
  });

  tearDown(() => deleteOnceReleased(temp));

  test('starts with nothing replaced and keeps what was written', () async {
    expect(await service.load('Skyrim.exe'), isEmpty, reason: 'no file yet');

    await service.save('Skyrim.exe', const {'timbre:2': 'a1'});

    expect(await service.load('Skyrim.exe'), {'timbre:2': 'a1'});
  });

  test('keeps one game apart from another', () async {
    await service.save('Skyrim.exe', const {'timbre:0': 'a1'});
    await service.save('Gothic.exe', const {'timbre:0': 'b2'});

    expect(await service.load('Skyrim.exe'), {'timbre:0': 'a1'});
    expect(await service.load('Gothic.exe'), {'timbre:0': 'b2'});
    expect(path.basename(await service.fileFor('Skyrim.exe')), 'skyrim.json');
  });

  test('reads nothing rather than refusing on a damaged file', () async {
    await File(await service.fileFor('Skyrim.exe')).writeAsString('{ not json');

    expect(await service.load('Skyrim.exe'), isEmpty);
  });

  test('the whole default output has a name of its own', () async {
    await service.save('', const {'timbre:1': 'a1'});

    expect(path.basename(await service.fileFor('')), 'system.json');
    expect(await service.load(''), {'timbre:1': 'a1'});
  });
}

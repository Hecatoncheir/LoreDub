// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lore_dub/src/data/repositories/app_repository.dart';
import 'package:lore_dub/src/data/repositories/model_repository.dart';
import 'package:lore_dub/src/data/repositories/runtime_repository.dart';
import 'package:lore_dub/src/data/repositories/update_repository.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/data/services/model_storage_service.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:lore_dub/src/data/services/notification_service.dart';
import 'package:lore_dub/src/data/services/runtime_storage_service.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/data/services/update_service.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/built_voice.dart';
import 'package:lore_dub/src/domain/character.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:lore_dub/src/domain/pipeline_state.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/characters_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/dashboard_cubits.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/downloads_cubit.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CastRepository repository;
  late DashboardCubits cubits;
  late CharactersCubit characters;

  setUp(() {
    repository = _CastRepository();
    cubits = DashboardCubits(
      repository,
      ModelRepository(ModelStorageService()),
      RuntimeRepository(RuntimeStorageService()),
      UpdateRepository(
        UpdateService(
          client: MockClient((_) async => http.Response('offline', 503)),
          // Read from the platform otherwise, which a unit test does not have.
          packageInfo: Future.value(
            PackageInfo(
              appName: 'LoreDub',
              packageName: 'lore_dub',
              version: '0.15.0',
              buildNumber: '20',
            ),
          ),
        ),
        NotificationService(plugin: FlutterLocalNotificationsPlugin()),
      ),
    );
    // Every package in place: a sample needs the speech model, and a
    // recording needs the converter.
    cubits.downloads.seed(
      DownloadsState(
        models: [
          for (final model in modelCatalog) ModelInstallState(model: model, installed: true),
        ],
      ),
    );
    characters = CharactersCubit(
      repository,
      // The real one goes looking for the application directory, which a
      // unit test does not have.
      _FixedModelRepository(),
      cubits.settings,
      cubits.downloads,
      cubits.shell,
    );
  });

  tearDown(() async {
    await characters.close();
    await cubits.dispose();
  });

  const guard = Character(id: 'a1', name: 'Стражник', vector: [0.2, 0.4]);

  test('adds a card, names it and throws it away again', () async {
    final added = await characters.add('Новый персонаж');
    expect(characters.state.characters.single.name, 'Новый персонаж');
    expect(repository.stored.characters.single.id, added.id, reason: 'written, not only shown');

    await characters.rename(added.id, 'Кузнец');
    expect(repository.stored.characters.single.name, 'Кузнец');

    await characters.remove(added.id);
    expect(characters.state.characters, isEmpty);
    expect(repository.stored.characters, isEmpty);
  });

  test('leaves a session the dubbing screens hold off this screen', () async {
    characters.seed(const CharactersState(loading: false));

    // One engine serves both screens; a live session is not this screen's to
    // show, and its record buttons open on nothing but a session of its own.
    characters.handleEvent({'type': 'state', 'state': 'listening', 'session': 'live'});

    expect(characters.state.running, isFalse);

    characters.handleEvent({'type': 'state', 'state': 'listening', 'session': 'characters'});

    expect(characters.state.running, isTrue);

    // The engine coming to rest names no session: it ends this one as well.
    characters.handleEvent({'type': 'state', 'state': 'idle'});

    expect(characters.state.running, isFalse);
  });

  group('a card built from files', () {
    setUp(() {
      characters.seed(const CharactersState(loading: false, characters: [guard]));
      repository.building = const BuiltVoice(
        vector: [0.1, 0.2],
        gender: 'male',
        seconds: 12.5,
        used: 3,
        skipped: ['C:/music.mp3'],
        agreement: 0.91,
        weakest: 0.84,
        anchor: 'C:/work/dropped_1.wav',
      );
    });

    test('measures every recording at once and keeps what came of it', () async {
      await characters.voiceFromFiles('a1', const [
        'C:/one.ogg',
        'C:/two.ogg',
        'C:/three.ogg',
        'C:/music.mp3',
      ]);

      expect(repository.builtFrom.single.length, 4, reason: 'all of them, in one go');
      expect(repository.stored.characters.single.vector, [0.1, 0.2]);
      expect(repository.stored.characters.single.gender, 'male');
      expect(repository.stored.characters.single.seconds, 12.5);
      // The clip the fingerprint stands closest to is what the card plays.
      expect(repository.kept['a1'], 'C:/work/dropped_1.wav');
      expect(characters.state.clips, contains('a1'));
      expect(characters.state.built?.used, 3);
      expect(characters.state.built?.skipped, ['C:/music.mp3']);
      expect(characters.state.builtId, 'a1');
      expect(characters.state.building, isFalse);
    });

    test('borrows a session of its own and puts it down again', () async {
      await characters.voiceFromFiles('a1', const ['C:/one.ogg']);

      expect(repository.fileSessionStarts, 1, reason: 'no game to listen to, only the converter');
      expect(repository.stops, 1, reason: 'and it is not left running');
    });

    test('measures through the session the screen is already recording with', () async {
      characters.seed(
        const CharactersState(
          loading: false,
          characters: [guard],
          status: PipelineStatus.listening,
        ),
      );

      await characters.voiceFromFiles('a1', const ['C:/one.ogg']);

      expect(repository.fileSessionStarts, 0);
      expect(repository.stops, 0, reason: "the player's own session is theirs to end");
    });

    test('leaves the card alone while another is being recorded', () async {
      characters.seed(
        const CharactersState(
          loading: false,
          characters: [guard],
          status: PipelineStatus.listening,
          recordingId: 'a1',
        ),
      );

      await characters.voiceFromFiles('a1', const ['C:/one.ogg']);

      expect(repository.builtFrom, isEmpty);
    });

    test('keeps the fingerprint even when the clip cannot be kept', () async {
      repository.building = const BuiltVoice(vector: [0.3], used: 1, seconds: 2);

      await characters.voiceFromFiles('a1', const ['C:/one.ogg']);

      expect(repository.stored.characters.single.vector, [0.3]);
      expect(characters.state.clips, isNot(contains('a1')), reason: 'no anchor, no play button');
    });
  });

  test('keeps the longest clear voice a recording heard', () async {
    characters.seed(
      const CharactersState(
        loading: false,
        status: PipelineStatus.listening,
        characters: [guard],
      ),
    );

    characters.startRecording('a1');
    expect(repository.recordings, [true]);

    // Too short to stand for anyone, then a clear line, then a shorter one.
    characters.handleEvent({
      'type': 'characterVoice',
      'vector': [9.0],
      'seconds': 0.8,
    });
    characters.handleEvent({
      'type': 'characterVoice',
      'vector': [0.7, 0.1],
      'gender': 'male',
      'seconds': 2.4,
    });
    characters.handleEvent({
      'type': 'characterVoice',
      'vector': [5.0],
      'seconds': 1.9,
    });

    await characters.stopRecording();

    expect(repository.recordings, [true, false]);
    final kept = characters.state.characters.single;
    expect(kept.vector, [0.7, 0.1]);
    expect(kept.gender, 'male');
    expect(kept.seconds, 2.4);
  });

  test('keeps the clip the card was recorded from, and plays it back', () async {
    characters.seed(
      const CharactersState(
        loading: false,
        status: PipelineStatus.listening,
        characters: [guard],
      ),
    );

    characters.startRecording('a1');
    characters.handleEvent({
      'type': 'characterVoice',
      'vector': [0.7, 0.1],
      'seconds': 2.4,
      'clip': r'C:\work\capture\segment-2.wav',
    });
    await characters.stopRecording();

    expect(repository.kept['a1'], r'C:\work\capture\segment-2.wav');
    expect(characters.state.canPlay('a1'), isTrue);

    await characters.playClip('a1');

    expect(repository.played, [r'C:\work\capture\segment-2.wav']);
    expect(characters.state.playingId, isNull, reason: 'it has finished sounding');
  });

  test('offers nothing to play for a card that came from a file', () async {
    characters.seed(const CharactersState(loading: false, characters: [guard]));

    expect(characters.state.canPlay('a1'), isFalse);

    await characters.playClip('a1');

    expect(repository.played, isEmpty);
  });

  test('takes the clip away with the card', () async {
    characters.seed(const CharactersState(loading: false, characters: [guard], clips: {'a1'}));
    repository.kept['a1'] = 'clip.wav';

    await characters.remove('a1');

    expect(repository.kept, isEmpty);
    expect(characters.state.clips, isEmpty);
  });

  test('speaks a sample in the voice the dubbing would read the card in', () async {
    characters.seed(const CharactersState(loading: false, characters: [guard]));

    await characters.preview('a1');

    expect(repository.previewStarts, 1, reason: 'the speech model is loaded once');
    expect(repository.spoken.single, contains('Стражник'));
    expect(characters.state.previewReady, isTrue);
    expect(characters.state.previewingId, isNull);

    await characters.preview('a1');

    expect(repository.previewStarts, 1, reason: 'the one after it waits for nothing');
    expect(repository.spoken.length, 2);
  });

  test('leaves the sample alone while the game is being listened to', () async {
    characters.seed(
      const CharactersState(
        loading: false,
        status: PipelineStatus.listening,
        characters: [guard],
      ),
    );

    await characters.preview('a1');

    expect(repository.spoken, isEmpty, reason: 'that worker has no speech model in it');
  });

  test('leaves the card alone when the recording heard nothing usable', () async {
    characters.seed(
      const CharactersState(
        loading: false,
        status: PipelineStatus.listening,
        characters: [guard],
      ),
    );

    characters.startRecording('a1');
    characters.handleEvent({
      'type': 'characterVoice',
      'vector': [9.0],
      'seconds': 0.5,
    });
    await characters.stopRecording();

    expect(characters.state.characters.single.vector, [0.2, 0.4], reason: 'as it was');
    expect(characters.state.recording, isFalse);
  });

  test('lays imported cards over the ones they came from', () async {
    characters.seed(const CharactersState(loading: false, characters: [guard]));
    repository.incoming = const CharacterLibrary(
      characters: [
        Character(id: 'a1', name: 'Стражник у ворот', vector: [0.9]),
        Character(id: 'b2', name: 'Кузнец', vector: [0.3]),
      ],
    );

    final added = await characters.import(['cast.json']);

    expect(added.characters, 2);
    expect(characters.state.characters.map((character) => character.name), [
      'Стражник у ворот',
      'Кузнец',
    ]);
  });

  test('gives a card another character to be read by, and takes it back', () async {
    characters.seed(
      const CharactersState(
        loading: false,
        characters: [
          guard,
          Character(id: 'b2', name: 'Кузнец', vector: [0.3]),
        ],
      ),
    );

    await characters.voiceAs('a1', 'b2');

    expect(characters.state.characters.first.voicedBy, 'b2');
    expect(repository.stored.characters.first.voicedBy, 'b2', reason: 'written, not only shown');

    await characters.voiceAs('a1', null);

    expect(characters.state.characters.first.voicedBy, isNull);
    expect(repository.stored.characters.first.voicedBy, isNull);
  });

  test('refuses to read a card by itself, which would say nothing', () async {
    characters.seed(const CharactersState(loading: false, characters: [guard]));

    await characters.voiceAs('a1', 'a1');

    expect(characters.state.characters.single.voicedBy, isNull);
  });

  test('collects cards into a pack and lets them out again', () async {
    characters.seed(
      const CharactersState(
        loading: false,
        characters: [
          guard,
          Character(id: 'b2', name: 'Кузнец', vector: [0.3]),
        ],
      ),
    );

    final pack = await characters.addPack('Таверна');
    await characters.addToPack(pack.id, 'a1');
    await characters.addToPack(pack.id, 'b2');
    // The same card dropped twice is in the pack once.
    await characters.addToPack(pack.id, 'a1');

    expect(characters.state.packs.single.characterIds, ['a1', 'b2']);
    expect(repository.stored.packs.single.name, 'Таверна', reason: 'written, not only shown');

    await characters.removeFromPack(pack.id, 'a1');

    expect(characters.state.packs.single.characterIds, ['b2']);
    expect(characters.state.characters.length, 2, reason: 'taken out of the pack, not the cast');
  });

  test('holds one card in as many packs as it was dropped into', () async {
    characters.seed(const CharactersState(loading: false, characters: [guard]));

    final tavern = await characters.addPack('Таверна');
    final prologue = await characters.addPack('Пролог');
    await characters.addToPack(tavern.id, 'a1');
    await characters.addToPack(prologue.id, 'a1');

    expect(characters.state.packs.map((pack) => pack.holds('a1')), [true, true]);
  });

  test('throwing a pack away leaves the cards it held', () async {
    characters.seed(const CharactersState(loading: false, characters: [guard]));
    final pack = await characters.addPack('Таверна');
    await characters.addToPack(pack.id, 'a1');

    await characters.removePack(pack.id);

    expect(characters.state.packs, isEmpty);
    expect(characters.state.characters.single.name, 'Стражник');
    expect(repository.stored.characters, hasLength(1));
  });

  test('a deleted card leaves the packs that held it', () async {
    characters.seed(const CharactersState(loading: false, characters: [guard]));
    final pack = await characters.addPack('Таверна');
    await characters.addToPack(pack.id, 'a1');

    await characters.remove('a1');

    expect(characters.state.packs.single.characterIds, isEmpty);
  });

  test('an imported pack brings its cards into the cast', () async {
    characters.seed(const CharactersState(loading: false));
    repository.incoming = const CharacterLibrary(
      characters: [
        Character(id: 'c3', name: 'Трактирщик', vector: [0.4]),
        Character(id: 'd4', name: 'Бард', vector: [0.6]),
      ],
      packs: [
        CharacterPack(id: 'p1', name: 'Таверна', characterIds: ['c3', 'd4']),
      ],
    );

    final added = await characters.import(['tavern.json']);

    expect((added.packs, added.characters), (1, 2));
    expect(characters.state.characters.map((character) => character.name), [
      'Трактирщик',
      'Бард',
    ]);
    expect(characters.state.packs.single.characterIds, ['c3', 'd4']);
  });

  test('names the cards a pack holds, in the order they were dropped in', () {
    const smith = Character(id: 'b2', name: 'Кузнец', vector: [0.3]);
    const state = CharactersState(
      loading: false,
      characters: [guard, smith],
      packs: [
        CharacterPack(id: 'p1', name: 'Таверна', characterIds: ['b2', 'gone', 'a1']),
      ],
    );

    expect(
      state.membersOf(state.packs.single).map((character) => character.name),
      ['Кузнец', 'Стражник'],
      reason: 'an id no card answers to is passed over',
    );
  });
}

/// The characters on disk, without a disk.
class _FixedModelRepository extends ModelRepository {
  _FixedModelRepository() : super(ModelStorageService());

  @override
  Future<String> directoryFor(ModelPackage model) async => 'models';
}

class _CastRepository extends AppRepository {
  _CastRepository() : super(NativeEngineService(), SettingsService());

  CharacterLibrary stored = CharacterLibrary.empty;
  CharacterLibrary incoming = CharacterLibrary.empty;
  final recordings = <bool>[];

  /// What a card built from files answers with, and what it was asked for.
  BuiltVoice building = const BuiltVoice();
  final builtFrom = <List<String>>[];
  int fileSessionStarts = 0;
  int stops = 0;

  /// The clips kept beside the cards, by card, and what was played.
  final kept = <String, String>{};
  final played = <String>[];
  final spoken = <String>[];
  int previewStarts = 0;

  @override
  Future<Set<String>> characterClips() async => kept.keys.toSet();

  @override
  Future<String?> characterClip(String id) async => kept[id];

  @override
  Future<void> keepCharacterClip(String id, String source) async => kept[id] = source;

  @override
  Future<void> removeCharacterClip(String id) async => kept.remove(id);

  @override
  Future<void> playWave(String wavePath) async => played.add(wavePath);

  @override
  Future<void> startVoiceFiles({
    required AppSettings settings,
    required String converterDirectory,
    required ComputeBackend converterBackend,
    required String runtimeDirectory,
  }) async => fileSessionStarts++;

  @override
  Future<BuiltVoice> buildVoice(List<String> paths) async {
    builtFrom.add(paths);
    return building;
  }

  @override
  Future<void> startVoicePreview({
    required AppSettings settings,
    required Map<String, String> modelDirectories,
    required String speaker,
    required ComputeBackend converterBackend,
    required String runtimeDirectory,
  }) async => previewStarts++;

  @override
  Future<void> previewVoice({
    required String text,
    required String voice,
    List<double> timbre = const [],
  }) async => spoken.add(text);

  @override
  Future<CharacterLibrary> loadCharacters() async => stored;

  @override
  Future<void> saveCharacters(CharacterLibrary library) async => stored = library;

  @override
  Future<CharacterLibrary> readCharacterFiles(List<String> sources) async => incoming;

  @override
  void recordCharacterVoice({required bool recording}) => recordings.add(recording);

  @override
  Future<void> stop() async => stops++;

  @override
  void dispose() {}
}

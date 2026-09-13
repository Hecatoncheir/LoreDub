// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/app_repository.dart';
import '../../../data/repositories/model_repository.dart';
import '../../../domain/character.dart';
import '../../../domain/compute_device.dart';
import '../../../domain/game_process.dart';
import '../../../domain/model_selection.dart';
import '../../../domain/pipeline_state.dart';
import 'downloads_cubit.dart';
import 'settings_cubit.dart';
import 'shell_cubit.dart';

/// The characters screen: the player's cast, and the session that records a
/// voice for one of them.
class CharactersState {
  const CharactersState({
    this.characters = const [],
    this.packs = const [],
    this.loading = true,
    this.status = PipelineStatus.idle,
    this.recordingId,
    this.heardSeconds = 0,
  });

  final List<Character> characters;

  /// The groups the cards are collected into. A character may be in several
  /// of them, and every character is in the cast whether a pack holds them
  /// or not.
  final List<CharacterPack> packs;

  /// Set until the file has been read once, so an empty screen does not
  /// claim the player has no characters before anyone looked.
  final bool loading;

  /// The recording session: idle until the screen starts it, listening once
  /// the converter is loaded and the game's audio is being captured.
  final PipelineStatus status;

  /// The character whose voice is being recorded, if any.
  final String? recordingId;

  /// How much speech the recording has heard, so the card can say whether
  /// there is enough of it yet.
  final double heardSeconds;

  bool get running => status == PipelineStatus.starting || status == PipelineStatus.listening;

  bool get recording => recordingId != null;

  /// The cards [pack] holds, in the order they were dropped into it. An id
  /// no card answers to is passed over rather than drawn as a gap.
  List<Character> membersOf(CharacterPack pack) => [
    for (final id in pack.characterIds)
      for (final character in characters)
        if (character.id == id) character,
  ];

  CharactersState copyWith({
    List<Character>? characters,
    List<CharacterPack>? packs,
    bool? loading,
    PipelineStatus? status,
    String? recordingId,
    bool clearRecordingId = false,
    double? heardSeconds,
  }) => CharactersState(
    characters: characters ?? this.characters,
    packs: packs ?? this.packs,
    loading: loading ?? this.loading,
    status: status ?? this.status,
    recordingId: clearRecordingId ? null : recordingId ?? this.recordingId,
    heardSeconds: heardSeconds ?? this.heardSeconds,
  );
}

class CharactersCubit extends Cubit<CharactersState> {
  CharactersCubit(
    this._appRepository,
    this._modelRepository,
    this._settings,
    this._downloads,
    this._errors,
  ) : super(const CharactersState());

  /// A recording keeps the clearest voice it has heard, not the last: a
  /// character founded on a half-word would answer for them ever after.
  static const enoughSeconds = 1.5;

  final AppRepository _appRepository;
  final ModelRepository _modelRepository;
  final SettingsCubit _settings;
  final DownloadsCubit _downloads;
  final FailureSink _errors;

  /// The best fingerprint this recording has heard so far.
  List<double>? _heard;
  String? _heardGender;

  ModelSelection get _selection =>
      ModelSelection(models: _downloads.state.models, settings: _settings.settings);

  /// Whether a voice can be recorded at all: the converter is what measures
  /// one, and it is downloaded on the models screen.
  bool get canRecord => _selection.voiceConverter?.installed ?? false;

  Future<void> load() async {
    try {
      final library = await _appRepository.loadCharacters();
      if (isClosed) return;
      emit(
        state.copyWith(
          characters: library.characters,
          packs: library.packs,
          loading: false,
        ),
      );
    } catch (exception) {
      if (isClosed) return;
      emit(state.copyWith(loading: false));
      _errors.report(exception);
    }
  }

  /// Adds an empty card for the player to name and record.
  Future<Character> add(String name) async {
    final character = Character(id: _newId(), name: name, vector: const []);
    await _write(characters: [...state.characters, character]);
    return character;
  }

  Future<void> rename(String id, String name) async {
    await _write(
      characters: [
        for (final character in state.characters)
          if (character.id == id) character.copyWith(name: name) else character,
      ],
    );
  }

  /// Reads [id] in [target]'s voice wherever they are recognized, or in
  /// their own again when [target] is null.
  ///
  /// This is the standing choice the card carries into every game; a game's
  /// own choice in Live overrides it. A card cannot be given its own voice,
  /// which would say nothing.
  Future<void> voiceAs(String id, String? target) async {
    if (id == target) return;
    await _write(
      characters: [
        for (final character in state.characters)
          if (character.id == id)
            character.copyWith(voicedBy: target, clearVoicedBy: target == null)
          else
            character,
      ],
    );
    // A session already running holds the cast it started with, so it is
    // told as well and the next line of this character is read anew.
    try {
      await _appRepository.voiceCharacterAs(id, target);
    } catch (exception) {
      _errors.report(exception);
    }
  }

  Future<void> remove(String id) async {
    if (state.recordingId == id) await stopRecording();
    await _write(
      characters: [
        for (final character in state.characters)
          if (character.id != id) character,
      ],
      // A card thrown away leaves every pack that held it, so no pack draws
      // a member that is no longer in the cast.
      packs: [
        for (final pack in state.packs) pack.withoutCharacter(id),
      ],
    );
  }

  /// Adds an empty pack for the player to name and drop cards into.
  Future<CharacterPack> addPack(String name) async {
    final pack = CharacterPack(id: _newId(), name: name);
    await _write(packs: [...state.packs, pack]);
    return pack;
  }

  Future<void> renamePack(String id, String name) async {
    await _write(
      packs: [
        for (final pack in state.packs)
          if (pack.id == id) pack.copyWith(name: name) else pack,
      ],
    );
  }

  /// Throws the group away and leaves the cards. The player recorded them;
  /// only the grouping was ever the pack's.
  Future<void> removePack(String id) async {
    await _write(
      packs: [
        for (final pack in state.packs)
          if (pack.id != id) pack,
      ],
    );
  }

  /// Puts [characterId] in [packId], where a card dropped on a pack lands.
  Future<void> addToPack(String packId, String characterId) async {
    if (!state.characters.any((character) => character.id == characterId)) return;
    await _write(
      packs: [
        for (final pack in state.packs)
          if (pack.id == packId) pack.withCharacter(characterId) else pack,
      ],
    );
  }

  Future<void> removeFromPack(String packId, String characterId) async {
    await _write(
      packs: [
        for (final pack in state.packs)
          if (pack.id == packId) pack.withoutCharacter(characterId) else pack,
      ],
    );
  }

  /// Lays imported cards and packs over the ones they came from. What comes
  /// back is how many of each were read, so the screen can say so.
  Future<({int characters, int packs})> import(List<String> files) async {
    try {
      final incoming = await _appRepository.readCharacterFiles(files);
      final characters = mergeCharacters(state.characters, incoming.characters);
      await _write(
        characters: characters,
        packs: prunePacks(mergePacks(state.packs, incoming.packs), characters),
      );
      return (characters: incoming.characters.length, packs: incoming.packs.length);
    } catch (exception) {
      _errors.report(exception);
      return (characters: 0, packs: 0);
    }
  }

  /// Writes one card, the whole cast, or a pack with the cards it holds.
  Future<void> export(
    String destination,
    List<Character> characters, {
    CharacterPack? pack,
  }) async {
    try {
      await _appRepository.exportCharacters(
        destination,
        CharacterLibrary(characters: characters, packs: [?pack]),
      );
    } catch (exception) {
      _errors.report(exception);
    }
  }

  /// Starts or ends the session the recordings listen through. [process] is
  /// the game to listen to, chosen on the screen.
  Future<void> toggleSession({required bool initializing, required GameProcess? process}) async {
    if (state.running) return stopSession();
    if (initializing || !canRecord) return;
    _errors.report(null);
    emit(state.copyWith(status: PipelineStatus.starting));
    try {
      final settings = _settings.settings;
      await _appRepository.startCharacterVoices(
        process: process,
        settings: settings,
        converterDirectory: await _modelRepository.directoryFor(
          _selection.voiceConverter!.model,
        ),
        converterBackend: settings.backendFor(
          ComputeStage.voiceConversion,
          _downloads.state.availability,
        ),
        runtimeDirectory: _downloads.state.runtimeDirectoryPath,
      );
    } catch (exception) {
      if (isClosed) return;
      emit(state.copyWith(status: PipelineStatus.error));
      _errors.report(exception);
    }
  }

  Future<void> stopSession() async {
    if (state.recording) await stopRecording();
    try {
      await _appRepository.stop();
    } catch (exception) {
      _errors.report(exception);
    }
    if (isClosed) return;
    emit(state.copyWith(status: PipelineStatus.idle));
  }

  /// Begins measuring what the game says for [id].
  void startRecording(String id) {
    if (!state.running || state.recording) return;
    _heard = null;
    _heardGender = null;
    _appRepository.recordCharacterVoice(recording: true);
    emit(state.copyWith(recordingId: id, heardSeconds: 0));
  }

  /// Keeps what was heard as the character's voice.
  Future<void> stopRecording() async {
    final id = state.recordingId;
    if (id == null) return;
    _appRepository.recordCharacterVoice(recording: false);
    final heard = _heard;
    emit(state.copyWith(clearRecordingId: true));
    if (heard == null) return;
    await _write(
      characters: [
        for (final character in state.characters)
          if (character.id == id)
            character.copyWith(
              vector: heard,
              gender: _heardGender,
              clearGender: _heardGender == null,
              seconds: state.heardSeconds,
            )
          else
            character,
      ],
    );
  }

  /// What the session reported: the state it is in, and the voices it heard
  /// while a card was recording.
  void handleEvent(Map<String, Object?> event) {
    switch (event['type']) {
      case 'state':
        final status = switch (event['state']) {
          'ready' || 'listening' => PipelineStatus.listening,
          'starting' => PipelineStatus.starting,
          _ => PipelineStatus.idle,
        };
        emit(state.copyWith(status: status));
      case 'characterVoice':
        if (!state.recording) return;
        final seconds = (event['seconds'] as num?)?.toDouble() ?? 0;
        // The longest clear line stands for the character: a fingerprint
        // taken from a grunt would answer for them ever after.
        if (seconds < enoughSeconds || seconds <= state.heardSeconds) return;
        _heard = [
          for (final value in event['vector'] as List<Object?>? ?? const [])
            if (value is num) value.toDouble(),
        ];
        _heardGender = event['gender'] as String?;
        emit(state.copyWith(heardSeconds: seconds));
    }
  }

  /// Shows the change at once and writes the file behind it; the cards and
  /// the packs go in one file, so both are written whichever changed.
  Future<void> _write({List<Character>? characters, List<CharacterPack>? packs}) async {
    emit(state.copyWith(characters: characters, packs: packs));
    try {
      await _appRepository.saveCharacters(
        CharacterLibrary(characters: state.characters, packs: state.packs),
      );
    } catch (exception) {
      _errors.report(exception);
    }
  }

  /// An id short enough to read in a file and never the same twice: two
  /// cards added in one microsecond — a pack and the card dropped into it —
  /// would otherwise answer to the same name.
  String _newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    _lastId = now > _lastId ? now : _lastId + 1;
    return _lastId.toRadixString(36);
  }

  int _lastId = 0;

  /// Stages a state a widget test wants to render without reading a file.
  @visibleForTesting
  void seed(CharactersState value) => emit(value);
}

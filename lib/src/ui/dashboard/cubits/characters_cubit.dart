// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as path;

import '../../../data/repositories/app_repository.dart';
import '../../../data/repositories/model_repository.dart';
import '../../../domain/built_voice.dart';
import '../../../domain/character.dart';
import '../../../domain/compute_device.dart';
import '../../../domain/game_process.dart';
import '../../../domain/model_package.dart';
import '../../../domain/model_selection.dart';
import '../../../domain/pipeline_state.dart';
import '../../../domain/voice_sample.dart';
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
    this.clips = const {},
    this.playingId,
    this.previewingId,
    this.previewReady = false,
    this.buildingId,
    this.builtId,
    this.built,
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

  /// The cards that kept the clip their voice was taken from, so it can be
  /// played back. A card imported from someone else's file has the
  /// fingerprint without the audio and is not in here.
  final Set<String> clips;

  /// The card whose clip is sounding right now.
  final String? playingId;

  /// The card whose voice is being measured from files dropped on it, and
  /// what came of the last such measurement. Both are the screen's own: the
  /// card keeps only the fingerprint.
  final String? buildingId;
  final String? builtId;
  final BuiltVoice? built;

  /// The card whose sample is being spoken — from the moment it is asked
  /// for, which on the first one means waiting for the speech model.
  final String? previewingId;

  /// Whether the speech model is loaded and a sample costs no waiting.
  final bool previewReady;

  bool get running => status == PipelineStatus.starting || status == PipelineStatus.listening;

  bool get recording => recordingId != null;

  /// Whether a card is being measured from files right now.
  bool get building => buildingId != null;

  /// Whether [id] has a clip of its own to play.
  bool canPlay(String id) => clips.contains(id);

  /// Nothing is played over anything else: one clip or one sample at a time.
  bool get sounding => playingId != null || previewingId != null;

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
    Set<String>? clips,
    String? playingId,
    bool clearPlayingId = false,
    String? previewingId,
    bool clearPreviewingId = false,
    String? buildingId,
    bool clearBuildingId = false,
    String? builtId,
    BuiltVoice? built,
    bool clearBuilt = false,
    bool? previewReady,
  }) => CharactersState(
    characters: characters ?? this.characters,
    packs: packs ?? this.packs,
    loading: loading ?? this.loading,
    status: status ?? this.status,
    recordingId: clearRecordingId ? null : recordingId ?? this.recordingId,
    heardSeconds: heardSeconds ?? this.heardSeconds,
    clips: clips ?? this.clips,
    playingId: clearPlayingId ? null : playingId ?? this.playingId,
    previewingId: clearPreviewingId ? null : previewingId ?? this.previewingId,
    buildingId: clearBuildingId ? null : buildingId ?? this.buildingId,
    builtId: clearBuilt ? null : builtId ?? this.builtId,
    built: clearBuilt ? null : built ?? this.built,
    previewReady: previewReady ?? this.previewReady,
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

  /// The file the clearest line was heard in, which is kept beside the card
  /// so the player can hear back what they recorded.
  String? _heardClip;

  ModelSelection get _selection =>
      ModelSelection(models: _downloads.state.models, settings: _settings.settings);

  /// Whether a voice can be recorded at all: the converter is what measures
  /// one, and it is downloaded on the models screen.
  bool get canRecord => _selection.voiceConverter?.installed ?? false;

  /// Whether a sample can be spoken: the speech model of the dubbing
  /// language is what says it.
  bool get canPreview => _selection.forTargetLanguage(ModelKind.speech)?.installed ?? false;

  /// Whether a sample will be spoken in the character's own timbre. Without
  /// «Original voice» the dubbing reads every card in a plain synthesized
  /// voice, and a card that says so spares the player wondering where the
  /// voice they recorded went.
  bool get carriesTimbre => _selection.clonesVoice;

  Future<void> load() async {
    try {
      final library = await _appRepository.loadCharacters();
      final clips = await _listClips();
      if (isClosed) return;
      emit(
        state.copyWith(
          characters: library.characters,
          packs: library.packs,
          clips: clips,
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

  /// Takes the whole cast out of the mix, or puts it back: the branch from
  /// the cards into the mix, cut or drawn on the graph.
  ///
  /// Nothing of the cards changes — who stands in for whom waits in them —
  /// so there is nothing to write; only a session already running has to be
  /// told, or it would go on reading the cast until the next start.
  Future<void> readAsHeard(bool value) async {
    try {
      await _appRepository.readAsHeard(value);
    } catch (exception) {
      _errors.report(exception);
    }
  }

  Future<void> remove(String id) async {
    if (state.recordingId == id) await stopRecording();
    await _dropClip(id);
    if (isClosed) return;
    emit(state.copyWith(clips: {...state.clips}..remove(id)));
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
    _recordingTicks?.cancel();
    _recordingTicks = null;
    _recordingSince = null;
    // Live calls this too, to take the worker over. Without a session of
    // this screen's there is nothing to end, and stopping the engine would
    // take down the one that is about to start.
    if (!state.running && !state.previewReady) return;
    if (state.recording) await stopRecording();
    try {
      await _appRepository.stop();
    } catch (exception) {
      _errors.report(exception);
    }
    if (isClosed) return;
    emit(state.copyWith(status: PipelineStatus.idle, previewReady: false));
  }

  /// Begins measuring what the game says for [id].
  ///
  /// The take runs until it is stopped: nothing in the game — a pause, a
  /// line that runs long — ends it, so what the card is measured from is
  /// everything heard in between. Three minutes is the ceiling, since a
  /// recording nobody stopped is a mistake rather than a wish.
  void startRecording(String id) {
    if (!state.running || state.recording) return;
    _heard = null;
    _heardGender = null;
    _heardClip = null;
    _heardSeconds = 0;
    unawaited(_appRepository.recordCharacterVoice(recording: true));
    // Nothing is measured until the take is stopped, so the card counts the
    // seconds itself rather than leaving the player without an answer.
    _recordingSince = DateTime.now();
    _recordingTicks?.cancel();
    _recordingTicks = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (isClosed || _recordingSince == null) return;
      emit(
        state.copyWith(
          heardSeconds: DateTime.now().difference(_recordingSince!).inMilliseconds / 1000,
        ),
      );
    });
    emit(state.copyWith(recordingId: id, heardSeconds: 0));
  }

  /// The clock the card counts a take by, and the ticks that show it.
  DateTime? _recordingSince;
  Timer? _recordingTicks;

  /// How much the take was measured to hold, as the converter read it.
  double _heardSeconds = 0;

  /// Closes the take and keeps what it heard as the character's voice.
  Future<void> stopRecording() async {
    final id = state.recordingId;
    if (id == null) return;
    _recordingTicks?.cancel();
    _recordingTicks = null;
    _recordingSince = null;
    // The take is one recording, and it is this call that closes it: what
    // the converter makes of it lands while this waits.
    await _appRepository.recordCharacterVoice(recording: false);
    if (isClosed) return;
    final heard = _heard;
    final clip = _heardClip;
    var kept = state.clips;
    if (heard != null && clip != null) {
      try {
        await _appRepository.keepCharacterClip(id, clip);
        kept = {...kept, id};
      } catch (exception) {
        // A card without its clip is still a card: only the play button goes.
        kept = {...kept}..remove(id);
        _errors.report(exception);
      }
    }
    emit(state.copyWith(clearRecordingId: true, clips: kept, heardSeconds: 0));
    if (heard == null) return;
    await _write(
      characters: [
        for (final character in state.characters)
          if (character.id == id)
            character.copyWith(
              vector: heard,
              gender: _heardGender,
              clearGender: _heardGender == null,
              seconds: _heardSeconds,
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
        _onSessionState(event);
      case 'characterVoice':
        _onCharacterVoice(event);
    }
  }

  /// The session has started, come up or come to rest.
  void _onSessionState(Map<String, Object?> event) {
    // The dubbing screens hold the worker in their turn, and a session of
    // theirs is not this screen's to show. An event naming no session is the
    // engine coming to rest, which ends this one as well.
    if (event['session'] case final String session
        when session != PipelineSession.characters.name) {
      return;
    }
    emit(
      state.copyWith(
        status: switch (event['state']) {
          'ready' || 'listening' => PipelineStatus.listening,
          'starting' => PipelineStatus.starting,
          _ => PipelineStatus.idle,
        },
      ),
    );
  }

  /// What was measured from the take a card is recording.
  void _onCharacterVoice(Map<String, Object?> event) {
    if (!state.recording) return;
    final seconds = (event['seconds'] as num?)?.toDouble() ?? 0;
    // The take is one recording, so this is it — unless it holds less speech
    // than a fingerprint can be taken from.
    if (seconds < enoughSeconds) return;
    _heard = [
      for (final value in event['vector'] as List<Object?>? ?? const [])
        if (value is num) value.toDouble(),
    ];
    _heardGender = event['gender'] as String?;
    _heardClip = event['clip'] as String?;
    // How long the take turned out to hold, which is what the card keeps;
    // the seconds on screen meanwhile are the clock's.
    _heardSeconds = seconds;
  }

  /// Throws away the clip of a card that is going. A clip left behind costs
  /// a few kilobytes; failing to remove it must not keep the card.
  Future<void> _dropClip(String id) async {
    try {
      await _appRepository.removeCharacterClip(id);
    } on Object {
      // Nothing to tell the player: the card goes either way.
    }
  }

  /// Measures the voice of [id] from the recordings the player dropped onto
  /// the card, whatever they are encoded as.
  ///
  /// The files are averaged rather than picked between, which is what makes
  /// a card built this way steadier than one built from a single line, and
  /// what came of it — how many files were used, how well they agreed, which
  /// ones held no voice — is kept in [CharactersState.built] for the card to
  /// show. The clip the fingerprint stands closest to becomes the one the
  /// card plays back, so what the player hears is a recording they gave it.
  Future<void> voiceFromFiles(String id, List<String> paths) async {
    if (paths.isEmpty || state.building || state.recording || !canRecord) return;
    if (!state.characters.any((character) => character.id == id)) return;
    _errors.report(null);
    emit(state.copyWith(buildingId: id, clearBuilt: true));
    // A session the player started is theirs to end; one borrowed here to
    // measure files with is put down again when the measuring is over.
    final borrowed = !state.running;
    try {
      if (borrowed) await _startForFiles();
      final built = await _appRepository.buildVoice(paths);
      final clips = await _keptClips(id, built.anchor);
      if (isClosed) return;
      emit(state.copyWith(built: built, builtId: id, clips: clips));
      await _write(characters: _withVoiceBuilt(id, built));
    } catch (exception) {
      _errors.report(exception);
    } finally {
      if (borrowed) await _stopBorrowed();
      if (!isClosed) {
        emit(
          state.copyWith(
            clearBuildingId: true,
            status: borrowed ? PipelineStatus.idle : state.status,
          ),
        );
      }
    }
  }

  /// Loads the converter and nothing else: there is no game to listen to,
  /// and the recordings are already on disk.
  Future<void> _startForFiles() async {
    final settings = _settings.settings;
    await _appRepository.startVoiceFiles(
      settings: settings,
      converterDirectory: await _modelRepository.directoryFor(_selection.voiceConverter!.model),
      converterBackend: settings.backendFor(
        ComputeStage.voiceConversion,
        _downloads.state.availability,
      ),
      runtimeDirectory: _downloads.state.runtimeDirectoryPath,
    );
  }

  /// The clips with [anchor] kept as [id]'s: the recording the fingerprint
  /// stands closest to, so the card plays back one the player gave it.
  ///
  /// A card without its clip is still a card — only the play button goes —
  /// so a clip that cannot be kept is reported and passed over.
  Future<Set<String>> _keptClips(String id, String? anchor) async {
    if (anchor == null) return state.clips;
    try {
      await _appRepository.keepCharacterClip(id, anchor);
      return {...state.clips, id};
    } catch (exception) {
      _errors.report(exception);
      return {...state.clips}..remove(id);
    }
  }

  /// The cast with [id]'s card carrying what the files were measured into.
  List<Character> _withVoiceBuilt(String id, BuiltVoice built) => [
    for (final character in state.characters)
      if (character.id == id)
        character.copyWith(
          vector: built.vector,
          gender: built.gender,
          clearGender: built.gender == null,
          seconds: built.seconds,
        )
      else
        character,
  ];

  /// Puts down a session borrowed only to measure files. The engine is
  /// stopped rather than `stopSession`: nothing reported itself as
  /// listening, so there is no session state to go by.
  Future<void> _stopBorrowed() async {
    try {
      await _appRepository.stop();
    } catch (exception) {
      _errors.report(exception);
    }
  }

  /// Ends whatever the screen has sounding — a recording being played back
  /// or a sample being spoken. The clip's own call returns as though it had
  /// reached the end, so the card puts its button back by itself.
  void stopSounding() {
    if (!state.sounding) return;
    _appRepository.stopWave();
  }

  /// Speaks [text] in the voice the dubbing would read [id] in, and plays
  /// it, so the player can hear a card before a word of the game is dubbed.
  ///
  /// The speech model is loaded for it, which the recording session does
  /// without — the first sample waits for that, the ones after it do not.
  /// Recording is the other way round, so the two do not run together.
  Future<void> preview(String id) async {
    if (state.sounding || state.running || !canPreview) return;
    final character = state.characters.where((value) => value.id == id).firstOrNull;
    if (character == null) return;
    emit(state.copyWith(previewingId: id));
    try {
      final selection = _selection;
      // A card read in another's voice is heard as that other: the sample
      // answers what the dubbing will do, not what the card holds.
      // One hop only, as the worker reads it: a card read by a card that is
      // itself read by a third keeps its own reader.
      final read =
          state.characters.where((value) => value.id == character.voicedBy).firstOrNull ??
          character;
      if (!state.previewReady) {
        await _loadSpeechForPreview();
        if (isClosed) return;
        emit(state.copyWith(previewReady: true));
      }
      await _appRepository.previewVoice(
        // The line is in the language the voice speaks, which is the one
        // being dubbed into — not the one the interface is in.
        text: voiceSample(_settings.settings.targetLanguage, character.name),
        voice: read.voice ?? selection.voice,
        timbre: selection.clonesVoice ? read.vector : const [],
      );
    } catch (exception) {
      _errors.report(exception);
    } finally {
      if (!isClosed) emit(state.copyWith(clearPreviewingId: true));
    }
  }

  /// Loads the speech model and the converter, without the translator: the
  /// first sample waits for that, the ones after it do not.
  Future<void> _loadSpeechForPreview() async {
    final selection = _selection;
    final speech = selection.forTargetLanguage(ModelKind.speech)!.model;
    await _appRepository.startVoicePreview(
      settings: _settings.settings,
      modelDirectories: {
        'speech': path.join(await _modelRepository.directoryFor(speech), speech.primaryFileName),
        if (selection.needsVoiceConverter)
          'converter': await _modelRepository.directoryFor(selection.voiceConverter!.model),
      },
      speaker: selection.voice,
      converterBackend: _settings.settings.backendFor(
        ComputeStage.voiceConversion,
        _downloads.state.availability,
      ),
      runtimeDirectory: _downloads.state.runtimeDirectoryPath,
    );
  }

  /// The cards with a clip beside them. A directory that cannot be read
  /// costs a play button, not the cast: the cards themselves are elsewhere.
  Future<Set<String>> _listClips() async {
    try {
      return await _appRepository.characterClips();
    } on Object {
      return const {};
    }
  }

  /// Plays back what the card was recorded from, so the player can hear
  /// whether they caught the right character.
  Future<void> playClip(String id) async {
    if (state.sounding) return;
    try {
      final clip = await _appRepository.characterClip(id);
      if (clip == null) {
        // The file went missing under us; the button goes with it.
        if (!isClosed) emit(state.copyWith(clips: {...state.clips}..remove(id)));
        return;
      }
      if (!isClosed) emit(state.copyWith(playingId: id));
      await _appRepository.playWave(clip);
    } catch (exception) {
      _errors.report(exception);
    } finally {
      if (!isClosed) emit(state.copyWith(clearPlayingId: true));
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

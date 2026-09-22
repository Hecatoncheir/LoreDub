// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

part of 'cast_bloc.dart';

/// How many cards and packs one import read, numbered so that two imports
/// of the same size are still two things to say.
class CastImport extends Equatable {
  const CastImport({required this.number, required this.characters, required this.packs});

  final int number;
  final int characters;
  final int packs;

  @override
  List<Object?> get props => [number, characters, packs];
}

/// The player's cards and the packs they are collected into, as the
/// characters screen shows them.
class CastState extends Equatable {
  const CastState({
    this.characters = const [],
    this.packs = const [],
    this.loading = true,
    this.lastImport,
  });

  final List<Character> characters;

  /// The groups the cards are collected into. A character may be in several
  /// of them, and every character is in the cast whether a pack holds them
  /// or not.
  final List<CharacterPack> packs;

  /// Set until the file has been read once, so an empty screen does not
  /// claim the player has no characters before anyone looked.
  final bool loading;

  /// What the last import read, which the screen says once. Left as it was
  /// by one that failed -- that is reported.
  final CastImport? lastImport;

  /// The cards [pack] holds, in the order they were dropped into it. An id
  /// no card answers to is passed over rather than drawn as a gap.
  List<Character> membersOf(CharacterPack pack) => [
    for (final id in pack.characterIds)
      for (final character in characters)
        if (character.id == id) character,
  ];

  CastState copyWith({
    List<Character>? characters,
    List<CharacterPack>? packs,
    bool? loading,
    CastImport? lastImport,
  }) => CastState(
    characters: characters ?? this.characters,
    packs: packs ?? this.packs,
    loading: loading ?? this.loading,
    lastImport: lastImport ?? this.lastImport,
  );

  @override
  List<Object?> get props => [characters, packs, loading, lastImport];
}

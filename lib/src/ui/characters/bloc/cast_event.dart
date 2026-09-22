// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

part of 'cast_bloc.dart';

sealed class CastEvent extends Equatable {
  const CastEvent();

  @override
  List<Object?> get props => const [];
}

/// The screen is up: the cards are read, once whoever asks first.
final class CastOpened extends CastEvent {
  const CastOpened();
}

/// Writes one card, the whole cast, or a pack with the cards it holds.
final class CastExported extends CastEvent {
  const CastExported(this.destination, this.characters, {this.pack});

  final String destination;
  final List<Character> characters;
  final CharacterPack? pack;

  @override
  List<Object?> get props => [destination, characters, pack];
}

/// A change to the cards or the packs.
///
/// One kind for all of them, answered one at a time: each is made from the
/// cast the one before it left, and the file is written in the order they
/// were asked for.
sealed class CastEdit extends CastEvent {
  const CastEdit();
}

/// Adds an empty card for the player to name and record.
final class CardAdded extends CastEdit {
  const CardAdded(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

final class CardRenamed extends CastEdit {
  const CardRenamed(this.id, this.name);

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// Reads [id] in [target]'s voice wherever they are recognized, or in their
/// own again when [target] is null. A card cannot be given its own voice,
/// which would say nothing.
final class CardVoicedAs extends CastEdit {
  const CardVoicedAs(this.id, this.target);

  final String id;
  final String? target;

  @override
  List<Object?> get props => [id, target];
}

/// Throws a card away, with the clip it was recorded from, and takes it out
/// of every pack that held it.
final class CardRemoved extends CastEdit {
  const CardRemoved(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Adds an empty pack for the player to name and drop cards into.
final class PackAdded extends CastEdit {
  const PackAdded(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

final class PackRenamed extends CastEdit {
  const PackRenamed(this.id, this.name);

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// Throws the group away and leaves the cards. The player recorded them;
/// only the grouping was ever the pack's.
final class PackRemoved extends CastEdit {
  const PackRemoved(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Puts a card in a pack, where a card dropped on a pack lands.
final class CardPacked extends CastEdit {
  const CardPacked(this.packId, this.characterId);

  final String packId;
  final String characterId;

  @override
  List<Object?> get props => [packId, characterId];
}

final class CardUnpacked extends CastEdit {
  const CardUnpacked(this.packId, this.characterId);

  final String packId;
  final String characterId;

  @override
  List<Object?> get props => [packId, characterId];
}

/// Lays imported cards and packs over the ones they came from.
final class CastImported extends CastEdit {
  const CastImported(this.files);

  final List<String> files;

  @override
  List<Object?> get props => [files];
}

final class _CastChanged extends CastEvent {
  const _CastChanged(this.library);

  final CharacterLibrary library;

  @override
  List<Object?> get props => [library];
}

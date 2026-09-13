// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/character.dart';
import '../../domain/pipeline_state.dart';
import '../theme.dart';
import 'model_visuals.dart';

/// A card on its way from one place to another: which character, and the
/// pack it was picked up from, if it was picked up from one.
///
/// The pack is what tells a drop onto the cast from a drop onto a pack: the
/// first takes the card out of where it came from, the second only adds it.
class CharacterDrag {
  const CharacterDrag({required this.character, this.fromPackId});

  final Character character;
  final String? fromPackId;
}

/// The cards in as many equal columns as fit, in the grid the model tiles
/// use — wider, because a card carries a name to type in as well as its
/// buttons.
class CharacterTileGrid extends StatelessWidget {
  const CharacterTileGrid({super.key, required this.children, this.height = 170});

  static const _minWidth = 248.0;
  static const _gap = 14.0;

  final List<Widget> children;
  final double height;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = math.max(1, ((constraints.maxWidth + _gap) / (_minWidth + _gap)).floor());
      final width = ((constraints.maxWidth - _gap * (columns - 1)) / columns).floorToDouble();
      return Wrap(
        spacing: _gap,
        runSpacing: _gap,
        children: [
          for (final child in children) SizedBox(width: width, height: height, child: child),
        ],
      );
    },
  );
}

/// One character: the name to edit, what was recorded for them, and the
/// buttons that record it, hand it on or throw the card away.
///
/// Drawn in the model tiles' vocabulary — a panel with an orange edge while
/// it is the one being recorded, and its buttons along the foot — and picked
/// up by the pointer, so a card can be dropped into a pack.
class CharacterTile extends StatefulWidget {
  const CharacterTile({
    super.key,
    required this.character,
    required this.recording,
    required this.heardSeconds,
    required this.packNames,
    required this.cast,
    required this.onRename,
    required this.onVoiceAs,
    required this.onRecord,
    required this.onExport,
    required this.onDelete,
    this.fromPackId,
  });

  final Character character;

  /// This card is the one the session is listening for.
  final bool recording;

  /// How much speech the recording has kept, while it is recording.
  final double heardSeconds;

  /// The packs holding this card, named under it so the player can see where
  /// a card already belongs without opening every pack.
  final List<String> packNames;

  /// The other cards, to give this one's lines away to.
  final List<Character> cast;

  final ValueChanged<String> onRename;

  /// Reads this character in another's voice wherever they are recognized,
  /// or in their own again when the id is null.
  final ValueChanged<String?> onVoiceAs;

  /// Null while another card records, or while no session runs.
  final VoidCallback? onRecord;
  final VoidCallback? onExport;
  final VoidCallback onDelete;

  /// Set when the card is drawn inside a pack, so dropping it on the cast
  /// takes it out of that pack.
  final String? fromPackId;

  @override
  State<CharacterTile> createState() => _CharacterTileState();
}

class _CharacterTileState extends State<CharacterTile> {
  late final TextEditingController _name = TextEditingController(text: widget.character.name);

  @override
  void didUpdateWidget(CharacterTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A name changed elsewhere — an import landing on this card — is shown,
    // but what the player is typing is left alone.
    if (widget.character.name != oldWidget.character.name && !_name.selection.isValid) {
      _name.text = widget.character.name;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _rename() {
    final name = _name.text.trim();
    if (name.isEmpty || name == widget.character.name) return;
    widget.onRename(name);
  }

  @override
  Widget build(BuildContext context) {
    final tile = _tile(context);
    return Draggable<CharacterDrag>(
      data: CharacterDrag(character: widget.character, fromPackId: widget.fromPackId),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _DragCard(name: widget.character.name),
      childWhenDragging: Opacity(opacity: 0.4, child: tile),
      child: tile,
    );
  }

  /// The name of the card standing in for this one; a card deleted since
  /// leaves the substitution showing as nobody in particular.
  String _nameOf(String id, AppLocalizations l10n) {
    for (final other in widget.cast) {
      if (other.id == id) return other.name;
    }
    return l10n.sceneVoiceAnonymous;
  }

  Widget _tile(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final character = widget.character;
    final recording = widget.recording;
    return HoverGrow(
      alignment: Alignment.center,
      scale: 1.02,
      builder: (context, hovered) => Material(
        color: LoreDubPalette.panel,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          side: BorderSide(
            color: recording
                ? LoreDubPalette.orange
                : hovered
                ? LoreDubPalette.ink
                : LoreDubPalette.outline,
            width: recording ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: TextField(
                controller: _name,
                style: const TextStyle(
                  fontFamily: LoreDubFonts.display,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  labelText: l10n.charactersNameLabel,
                  isDense: true,
                ),
                onEditingComplete: _rename,
                onTapOutside: (_) => _rename(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recording
                          ? (widget.heardSeconds > 0
                                ? l10n.charactersHeard(widget.heardSeconds.toStringAsFixed(1))
                                : l10n.charactersRecording)
                          : character.vector.isEmpty
                          ? l10n.charactersNoVoice
                          : l10n.charactersVoiceKept(
                              character.seconds.toStringAsFixed(1),
                              switch (character.gender) {
                                'male' => l10n.voiceGenderMale,
                                'female' => l10n.voiceGenderFemale,
                                _ => l10n.charactersGenderUnknown,
                              },
                            ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: LoreDubFonts.mono,
                        fontSize: 11,
                        color: recording ? LoreDubPalette.orange : LoreDubPalette.mutedInk,
                        fontWeight: recording ? FontWeight.w600 : null,
                      ),
                    ),
                    if (widget.character.voicedBy case final id?)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          l10n.sceneVoiceReplaced(_nameOf(id, l10n)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: LoreDubFonts.mono,
                            fontSize: 11,
                            color: LoreDubPalette.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (widget.packNames.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        l10n.charactersInPacks(widget.packNames.join(', ')),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: LoreDubFonts.mono,
                          fontSize: 11,
                          color: LoreDubPalette.mutedInk,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ModelActionButton(
                    onDark: false,
                    action: ModelAction(
                      icon: recording ? Icons.stop_rounded : Icons.mic_rounded,
                      tooltip: recording ? l10n.charactersRecordStop : l10n.charactersRecord,
                      onPressed: widget.onRecord,
                    ),
                  ),
                  // Giving a character away is a choice among the others,
                  // so the button opens the cast rather than toggling.
                  PopupMenuButton<String>(
                    key: ValueKey('voiceAs-${character.id}'),
                    tooltip: l10n.charactersVoicedByHint,
                    enabled: widget.cast.isNotEmpty,
                    // The empty value is their own voice back.
                    onSelected: (id) => widget.onVoiceAs(id.isEmpty ? null : id),
                    itemBuilder: (context) => [
                      PopupMenuItem(value: '', child: Text(l10n.charactersOwnVoice)),
                      for (final other in widget.cast)
                        PopupMenuItem(value: other.id, child: Text(other.name)),
                    ],
                    icon: Icon(
                      Icons.published_with_changes_rounded,
                      size: 19,
                      color: character.voicedBy == null
                          ? LoreDubPalette.ink
                          : LoreDubPalette.orange,
                    ),
                    iconSize: 19,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                  ),
                  ModelActionButton(
                    onDark: false,
                    action: ModelAction(
                      icon: Icons.file_upload_outlined,
                      tooltip: l10n.charactersExportHint,
                      onPressed: widget.onExport,
                    ),
                  ),
                  ModelActionButton(
                    onDark: false,
                    action: ModelAction(
                      icon: Icons.delete_outline_rounded,
                      tooltip: l10n.charactersDelete,
                      onPressed: widget.onDelete,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the pointer carries while a card is being dragged: its name alone,
/// small enough to see where it is going.
class _DragCard extends StatelessWidget {
  const _DragCard({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(-70, -22),
    child: Material(
      color: LoreDubPalette.graphite,
      elevation: 8,
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.drag_indicator_rounded, size: 18, color: LoreDubPalette.orange),
            const SizedBox(width: 8),
            Text(
              name,
              style: const TextStyle(
                fontFamily: LoreDubFonts.display,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: LoreDubPalette.raised,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// One pack: a named area cards are dropped into, exported from and taken
/// out of again.
///
/// The cards inside are drawn small — the whole card, with its name field
/// and buttons, already stands in the cast above; here what matters is who
/// is in the group.
class CharacterPackArea extends StatefulWidget {
  const CharacterPackArea({
    super.key,
    required this.pack,
    required this.members,
    required this.onRename,
    required this.onExport,
    required this.onDelete,
    required this.onDrop,
    required this.onRemoveMember,
  });

  final CharacterPack pack;
  final List<Character> members;
  final ValueChanged<String> onRename;

  /// Null while the pack holds no card that could be written.
  final VoidCallback? onExport;
  final VoidCallback onDelete;
  final ValueChanged<CharacterDrag> onDrop;
  final ValueChanged<Character> onRemoveMember;

  @override
  State<CharacterPackArea> createState() => _CharacterPackAreaState();
}

class _CharacterPackAreaState extends State<CharacterPackArea> {
  late final TextEditingController _name = TextEditingController(text: widget.pack.name);

  @override
  void didUpdateWidget(CharacterPackArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pack.name != oldWidget.pack.name && !_name.selection.isValid) {
      _name.text = widget.pack.name;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _rename() {
    final name = _name.text.trim();
    if (name.isEmpty || name == widget.pack.name) return;
    widget.onRename(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DragTarget<CharacterDrag>(
      // A card already in this pack is not offered a place in it again.
      onWillAcceptWithDetails: (details) => !widget.pack.holds(details.data.character.id),
      onAcceptWithDetails: (details) => widget.onDrop(details.data),
      builder: (context, candidate, _) {
        final inviting = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
          decoration: BoxDecoration(
            color: inviting ? LoreDubPalette.raised : LoreDubPalette.panel,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(
              color: inviting ? LoreDubPalette.orange : LoreDubPalette.outline,
              width: inviting ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _name,
                      style: const TextStyle(
                        fontFamily: LoreDubFonts.display,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.packsNameLabel,
                        isDense: true,
                      ),
                      onEditingComplete: _rename,
                      onTapOutside: (_) => _rename(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.packsCount(widget.members.length),
                    style: const TextStyle(
                      fontFamily: LoreDubFonts.mono,
                      fontSize: 11,
                      color: LoreDubPalette.mutedInk,
                    ),
                  ),
                  ModelActionButton(
                    onDark: false,
                    action: ModelAction(
                      icon: Icons.file_upload_outlined,
                      tooltip: l10n.packsExportHint,
                      onPressed: widget.onExport,
                    ),
                  ),
                  ModelActionButton(
                    onDark: false,
                    action: ModelAction(
                      icon: Icons.delete_outline_rounded,
                      tooltip: l10n.packsDelete,
                      onPressed: widget.onDelete,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (widget.members.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                  child: Text(
                    l10n.packsDropHint,
                    style: const TextStyle(
                      fontSize: 12,
                      color: LoreDubPalette.mutedInk,
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final member in widget.members)
                      _PackMember(
                        character: member,
                        packId: widget.pack.id,
                        onRemove: () => widget.onRemoveMember(member),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A card inside a pack: its name, a handle to drag it out by, and the
/// cross that takes it out without dragging.
class _PackMember extends StatelessWidget {
  const _PackMember({required this.character, required this.packId, required this.onRemove});

  final Character character;
  final String packId;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chip = Material(
      color: LoreDubPalette.raised,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        side: const BorderSide(color: LoreDubPalette.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              character.vector.isEmpty ? Icons.mic_none_rounded : Icons.record_voice_over_outlined,
              size: 16,
              color: character.vector.isEmpty ? LoreDubPalette.mutedInk : LoreDubPalette.success,
            ),
            const SizedBox(width: 8),
            Text(
              character.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            IconButton(
              tooltip: l10n.packsRemoveMember,
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 15),
              style: IconButton.styleFrom(
                minimumSize: const Size(26, 26),
                fixedSize: const Size(26, 26),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
    return Draggable<CharacterDrag>(
      data: CharacterDrag(character: character, fromPackId: packId),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _DragCard(name: character.name),
      childWhenDragging: Opacity(opacity: 0.4, child: chip),
      child: chip,
    );
  }
}

/// One voice of the running scene: who was heard, what they last said, and
/// the character whose voice reads them from now on.
///
/// The replacement is the whole point of the row: a game's own voice, or a
/// card recognized in it, can be handed another character's voice without
/// waiting for the next session.
class SceneVoiceRow extends StatelessWidget {
  const SceneVoiceRow({
    super.key,
    required this.speaker,
    required this.name,
    required this.characters,
    required this.assignedId,
    required this.standingName,
    required this.onAssign,
  });

  final SceneSpeaker speaker;

  /// What to call the voice itself, already resolved to wording.
  final String name;

  /// The cast to choose from; empty until the player has recorded one.
  final List<Character> characters;

  /// The character reading this voice, when this game was given one.
  final String? assignedId;

  /// The card standing in for this voice by its own card rather than by this
  /// game's choice, named so the row can say where the substitution comes
  /// from. Null when there is none, or when this game has its own.
  final String? standingName;

  /// Null when this voice cannot be replaced at all.
  final ValueChanged<String?>? onAssign;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final assigned = characters.where((character) => character.id == assignedId).firstOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                assigned == null ? Icons.graphic_eq_rounded : Icons.published_with_changes_rounded,
                size: 16,
                color: assigned == null ? LoreDubPalette.mutedInk : LoreDubPalette.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: LoreDubFonts.display,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                l10n.sceneVoiceLines(speaker.lines),
                style: const TextStyle(
                  fontFamily: LoreDubFonts.mono,
                  fontSize: 11,
                  color: LoreDubPalette.mutedInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            // Placing the voices needs no words, so a row gathered before
            // the dubbing says how much of the voice was heard instead.
            speaker.line.isNotEmpty
                ? speaker.line
                : l10n.sceneVoiceHeardFor(speaker.seconds.toStringAsFixed(1)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: LoreDubPalette.mutedInk),
          ),
          if (standingName case final name?) ...[
            const SizedBox(height: 4),
            Text(
              l10n.sceneVoiceStanding(name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: LoreDubFonts.mono,
                fontSize: 11,
                color: LoreDubPalette.orange,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (onAssign == null)
            Text(
              l10n.sceneVoiceAsHeard,
              style: const TextStyle(fontSize: 12, color: LoreDubPalette.mutedInk),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: PopupMenuButton<String>(
                key: ValueKey('assign-${speaker.key}'),
                tooltip: l10n.sceneVoiceReadAs,
                // The empty value stands for the voice as it was heard, so
                // the menu can offer taking a replacement back.
                onSelected: (id) => onAssign!(id.isEmpty ? null : id),
                itemBuilder: (context) => [
                  PopupMenuItem(value: '', child: Text(l10n.sceneVoiceAsHeard)),
                  for (final character in characters)
                    PopupMenuItem(value: character.id, child: Text(character.name)),
                ],
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                  decoration: BoxDecoration(
                    color: LoreDubPalette.raised,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    border: Border.all(
                      color: assigned == null ? LoreDubPalette.outline : LoreDubPalette.orange,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        assigned?.name ?? l10n.sceneVoiceAsHeard,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: assigned == null ? null : FontWeight.w600,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

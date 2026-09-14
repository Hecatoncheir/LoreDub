// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/built_voice.dart';
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
  const CharacterTileGrid({super.key, required this.children, this.height = 182});

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
    required this.onRecord,
    required this.onPlay,
    required this.playing,
    required this.onPreview,
    this.onStopSound,
    this.carriesTimbre = true,
    required this.previewing,
    required this.onExport,
    required this.onDelete,
    this.onFilesDropped,
    this.building = false,
    this.built,
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

  /// The other cards, so the line under the name can call the one reading
  /// this character by name. Who reads whom is drawn on the graph; a card
  /// shows it and does not set it.
  final List<Character> cast;

  final ValueChanged<String> onRename;

  /// Null while another card records, or while no session runs.
  final VoidCallback? onRecord;

  /// Plays back what this card was recorded from. Null when the card has no
  /// clip of its own — an imported one carries the fingerprint and no audio.
  final VoidCallback? onPlay;

  /// Whether this card's clip is sounding right now.
  final bool playing;

  /// Speaks a line in the voice the dubbing would read this card in. Null
  /// while the speech model is missing, or while anything else sounds.
  final VoidCallback? onPreview;

  /// Whether this card's sample is being got ready or spoken.
  final bool previewing;

  /// Ends what is sounding, whichever of the two started it.
  final VoidCallback? onStopSound;

  /// Whether the sample will be spoken in the character's own timbre. Without
  /// Original voice the dubbing reads them in a plain synthesized voice, and
  /// a sample that says so is worth more than one that leaves the player
  /// wondering where the voice they recorded went.
  final bool carriesTimbre;
  final VoidCallback? onExport;
  final VoidCallback onDelete;

  /// Takes the recordings dropped onto the card and measures its voice from
  /// all of them at once. Null while nothing could be measured — the
  /// converter is missing, or another card is being recorded.
  final ValueChanged<List<String>>? onFilesDropped;

  /// Whether this card's voice is being measured from dropped files.
  final bool building;

  /// What came of the last such measurement on this card, while the screen
  /// still has it to show.
  final BuiltVoice? built;

  /// Set when the card is drawn inside a pack, so dropping it on the cast
  /// takes it out of that pack.
  final String? fromPackId;

  /// What a card takes when files are dropped on it. Windows decodes them,
  /// so the list is what it can play rather than what this app can read.
  static const soundFiles = {
    '.wav',
    '.ogg',
    '.oga',
    '.opus',
    '.mp3',
    '.m4a',
    '.aac',
    '.flac',
    '.wma',
    '.webm',
    '.mp4',
  };

  /// The paths among [paths] that look like sound. A folder dropped by
  /// mistake, or a screenshot, is left rather than sent to be decoded.
  static List<String> soundAmong(Iterable<String> paths) => [
    for (final path in paths)
      if (soundFiles.contains(_extensionOf(path))) path,
  ];

  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    return dot < 0 ? '' : path.substring(dot).toLowerCase();
  }

  @override
  State<CharacterTile> createState() => _CharacterTileState();
}

class _CharacterTileState extends State<CharacterTile> {
  late final TextEditingController _name = TextEditingController(text: widget.character.name);

  /// Whether files are being held over this card right now.
  bool _over = false;

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
    final dragged = Draggable<CharacterDrag>(
      data: CharacterDrag(character: widget.character, fromPackId: widget.fromPackId),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _DragCard(name: widget.character.name),
      childWhenDragging: Opacity(opacity: 0.4, child: tile),
      child: tile,
    );
    // The whole card takes the files, not a strip of it: what the player
    // aims at is the character, and a card is small enough already.
    return DropTarget(
      onDragEntered: (_) => setState(() => _over = true),
      onDragExited: (_) => setState(() => _over = false),
      onDragDone: (details) {
        setState(() => _over = false);
        final sound = CharacterTile.soundAmong(details.files.map((file) => file.path));
        if (sound.isNotEmpty) widget.onFilesDropped?.call(sound);
      },
      child: dragged,
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

  /// What the card says about the recordings it was just built from: how
  /// many held a voice, how closely they agreed, and what was left out.
  /// One recording agrees with itself, so its number is not shown.
  String _buildingLine(AppLocalizations l10n) {
    final built = widget.built;
    if (widget.building || built == null) return l10n.charactersBuilding;
    final parts = [
      if (!built.together)
        l10n.charactersBuiltApart
      else if (built.used <= 1)
        l10n.charactersBuiltFromOne
      else
        l10n.charactersBuiltFrom(built.used, built.agreement.toStringAsFixed(2)),
      if (built.skipped.isNotEmpty) l10n.charactersBuiltSkipped(built.skipped.length),
    ];
    return parts.join(' · ');
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
            // Files held over the card say so the way a recording does: the
            // whole card is the target, so the whole edge lights up.
            color: recording || _over || widget.building
                ? LoreDubPalette.orange
                : hovered
                ? LoreDubPalette.ink
                : LoreDubPalette.outline,
            width: recording || _over || widget.building ? 2 : 1,
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
                // Every line gives way rather than spilling: a card may
                // carry what was recorded, whose voice reads it and the packs
                // it belongs to at once, and a narrow window wraps them.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
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
                    ),
                    if (widget.building || widget.built != null)
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _buildingLine(l10n),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: LoreDubFonts.mono,
                              fontSize: 11,
                              color: widget.built?.together == false
                                  ? LoreDubPalette.error
                                  : LoreDubPalette.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (widget.character.voicedBy case final id?)
                      Flexible(
                        child: Padding(
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
                      ),
                    if (widget.packNames.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Flexible(
                        child: Text(
                          l10n.charactersInPacks(widget.packNames.join(', ')),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: LoreDubFonts.mono,
                            fontSize: 11,
                            color: LoreDubPalette.mutedInk,
                          ),
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
                  // Hear back what the card was taken from: the surest way
                  // to tell whether the right character was caught.
                  ModelActionButton(
                    key: ValueKey('playClip-${character.id}'),
                    onDark: false,
                    action: ModelAction(
                      icon: widget.playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      tooltip: widget.playing
                          ? l10n.charactersStopSound
                          : (widget.onPlay == null
                                ? l10n.charactersNoClip
                                : l10n.charactersPlayClip),
                      // The same button stops it: a recording may run for
                      // three minutes, and nobody wants to sit through one.
                      onPressed: widget.playing ? widget.onStopSound : widget.onPlay,
                    ),
                  ),
                  // Not the recording but the dubbing: the Silero voice this
                  // card will be read in, with its own timbre over it.
                  ModelActionButton(
                    key: ValueKey('previewVoice-${character.id}'),
                    onDark: false,
                    action: ModelAction(
                      icon: widget.previewing
                          ? Icons.stop_rounded
                          : Icons.record_voice_over_rounded,
                      tooltip: widget.previewing
                          ? l10n.charactersStopSound
                          : (widget.onPreview == null
                                ? l10n.charactersPreviewNeedsModel
                                : widget.carriesTimbre
                                ? l10n.charactersPreviewVoice
                                : l10n.charactersPreviewPlain),
                      onPressed: widget.previewing ? widget.onStopSound : widget.onPreview,
                    ),
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
/// The row says who the voice is and who reads it. Setting that is the
/// graph's, so that one scheme decides who speaks for whom rather than three
/// screens disagreeing about it.
class SceneVoiceRow extends StatelessWidget {
  const SceneVoiceRow({
    super.key,
    required this.speaker,
    required this.name,
    required this.characters,
    required this.assignedId,
    required this.standingName,
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
          // Who reads this voice, whoever decided it — this game's own
          // choice, or the card as the graph wired it. The row shows it and
          // nothing more: the graph is where it is set.
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              key: ValueKey('reads-${speaker.key}'),
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              decoration: BoxDecoration(
                color: LoreDubPalette.raised,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                border: Border.all(
                  color: assigned == null ? LoreDubPalette.outline : LoreDubPalette.orange,
                ),
              ),
              child: Text(
                assigned?.name ?? standingName ?? l10n.sceneVoiceAsHeard,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: assigned == null && standingName == null ? null : FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

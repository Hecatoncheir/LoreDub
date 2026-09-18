// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/built_voice.dart';
import '../../domain/character.dart';
import '../theme.dart';
import '../dashboard/model_visuals.dart';
import '../common/committed_text_field.dart';
import 'character_drag.dart';
import 'character_card_menu.dart';
import 'character_drag_card.dart';

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
    this.dubbing = false,
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
  /// while the speech model is missing, while anything else sounds, or while
  /// something else holds the worker.
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

  /// Whether a dubbing session holds the worker, which is what the sample
  /// waits for. The button says so, rather than sending the player after a
  /// speech model they already have.
  final bool dubbing;
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
  /// Whether files are being held over this card right now.
  bool _over = false;

  @override
  Widget build(BuildContext context) {
    final tile = _tile(context);
    final dragged = Draggable<CharacterDrag>(
      data: CharacterDrag(character: widget.character, fromPackId: widget.fromPackId),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: CharacterDragCard(name: widget.character.name),
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

  /// The card itself: a name to type in, the lines saying what it carries,
  /// and the buttons along its foot.
  Widget _tile(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lit = widget.recording || _over || widget.building;
    return HoverGrow(
      alignment: Alignment.center,
      scale: 1.02,
      builder: (context, hovered) => Material(
        color: LoreDubPalette.panel,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          // Files held over the card say so the way a recording does: the
          // whole card is the target, so the whole edge lights up.
          side: BorderSide(
            color: lit
                ? LoreDubPalette.orange
                : hovered
                ? LoreDubPalette.ink
                : LoreDubPalette.outline,
            width: lit ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: _nameField(l10n),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: _lines(l10n),
              ),
            ),
            SizedBox(height: 44, child: _actions(l10n)),
          ],
        ),
      ),
    );
  }

  Widget _nameField(AppLocalizations l10n) => CommittedTextField(
    value: widget.character.name,
    onCommitted: widget.onRename,
    style: const TextStyle(
      fontFamily: LoreDubFonts.display,
      fontSize: 17,
      fontWeight: FontWeight.w700,
    ),
    decoration: InputDecoration(labelText: l10n.charactersNameLabel, isDense: true),
  );

  /// What the card carries, a line each.
  ///
  /// Every line gives way rather than spilling: a card may say what was
  /// recorded, whose voice reads it and which packs it belongs to at once,
  /// and a narrow window wraps them.
  Widget _lines(AppLocalizations l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _line(
        _voiceLine(l10n),
        color: widget.recording ? LoreDubPalette.orange : LoreDubPalette.mutedInk,
        bold: widget.recording,
        maxLines: 2,
      ),
      if (widget.building || widget.built != null)
        _line(
          _buildingLine(l10n),
          top: 6,
          color: widget.built?.together == false ? LoreDubPalette.error : LoreDubPalette.orange,
          bold: true,
          maxLines: 2,
        ),
      if (widget.character.voicedBy case final id?)
        _line(
          l10n.sceneVoiceReplaced(_nameOf(id, l10n)),
          top: 6,
          color: LoreDubPalette.orange,
          bold: true,
        ),
      // A rigid gap rather than a padding inside the line: the lines give
      // way when the card is short, and the space between them should not.
      if (widget.packNames.isNotEmpty) ...[
        const SizedBox(height: 6),
        _line(l10n.charactersInPacks(widget.packNames.join(', '))),
      ],
    ],
  );

  /// One such line, in the small monospaced type they all share.
  Widget _line(
    String text, {
    double top = 0,
    Color color = LoreDubPalette.mutedInk,
    bool bold = false,
    int maxLines = 1,
  }) => Flexible(
    child: Padding(
      padding: EdgeInsets.only(top: top),
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: LoreDubFonts.mono,
          fontSize: 11,
          color: color,
          fontWeight: bold ? FontWeight.w600 : null,
        ),
      ),
    ),
  );

  /// What the card has of a voice: the seconds ticking by while it records,
  /// or what its recording came to, or that it has none yet.
  String _voiceLine(AppLocalizations l10n) {
    if (widget.recording) {
      return widget.heardSeconds > 0
          ? l10n.charactersHeard(widget.heardSeconds.toStringAsFixed(1))
          : l10n.charactersRecording;
    }
    if (widget.character.vector.isEmpty) return l10n.charactersNoVoice;
    return l10n.charactersVoiceKept(
      widget.character.seconds.toStringAsFixed(1),
      switch (widget.character.gender) {
        'male' => l10n.voiceGenderMale,
        'female' => l10n.voiceGenderFemale,
        _ => l10n.charactersGenderUnknown,
      },
    );
  }

  Widget _actions(AppLocalizations l10n) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _action(
        icon: widget.recording ? Icons.stop_rounded : Icons.mic_rounded,
        tooltip: widget.recording ? l10n.charactersRecordStop : l10n.charactersRecord,
        onPressed: widget.onRecord,
      ),
      // Hear back what the card was taken from: the surest way to tell
      // whether the right character was caught. The same button stops it —
      // a recording may run for three minutes, and nobody wants to sit
      // through one.
      _action(
        key: ValueKey('playClip-${widget.character.id}'),
        icon: widget.playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
        tooltip: widget.playing
            ? l10n.charactersStopSound
            : widget.onPlay == null
            ? l10n.charactersNoClip
            : l10n.charactersPlayClip,
        onPressed: widget.playing ? widget.onStopSound : widget.onPlay,
      ),
      // Not the recording but the dubbing: the Silero voice this card will
      // be read in, with its own timbre over it.
      _action(
        key: ValueKey('previewVoice-${widget.character.id}'),
        icon: widget.previewing ? Icons.stop_rounded : Icons.record_voice_over_rounded,
        tooltip: _previewTooltip(l10n),
        onPressed: widget.previewing ? widget.onStopSound : widget.onPreview,
      ),
      // Saving the card and throwing it away are neither of them about the
      // voice, and one of them cannot be taken back. Five unlabelled icons
      // in a row put delete a slip away from record; behind a menu it is
      // named in words and reached on purpose.
      CharacterCardMenu(
        onExport: widget.onExport,
        onDelete: widget.onDelete,
      ),
    ],
  );

  /// What the sample button says: what it will do, or what it waits for.
  String _previewTooltip(AppLocalizations l10n) {
    if (widget.previewing) return l10n.charactersStopSound;
    if (widget.dubbing) return l10n.charactersPreviewWhileDubbing;
    if (widget.onPreview == null) return l10n.charactersPreviewNeedsModel;
    return widget.carriesTimbre ? l10n.charactersPreviewVoice : l10n.charactersPreviewPlain;
  }

  Widget _action({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Key? key,
  }) => ModelActionButton(
    key: key,
    onDark: false,
    action: ModelAction(icon: icon, tooltip: tooltip, onPressed: onPressed),
  );
}

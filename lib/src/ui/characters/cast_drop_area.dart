// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../theme.dart';
import 'cast_card.dart';
import 'empty_cast.dart';
import 'character_drag.dart';
import '../common/tile_grid.dart';
import '../dashboard/cubits/cast_bloc.dart';
import '../dashboard/cubits/voice_capture_bloc.dart';

/// The cards of the cast, laid out in a grid that a card dragged out of a
/// pack can be dropped back on -- which takes it out of that pack.
class CastDropArea extends StatelessWidget {
  const CastDropArea({
    super.key,
    required this.cast,
    required this.capture,
    required this.dubbing,
  });

  final CastState cast;
  final VoiceCaptureState capture;

  /// A dubbing session holds the worker.
  final bool dubbing;

  @override
  Widget build(BuildContext context) => DragTarget<CharacterDrag>(
    // Only a card that came out of a pack has anywhere to land
    // here; one dragged from the cast is already where it is.
    onWillAcceptWithDetails: (details) => details.data.fromPackId != null,
    onAcceptWithDetails: (details) => context.read<CastBloc>().add(
      CardUnpacked(details.data.fromPackId!, details.data.character.id),
    ),
    builder: (context, candidate, _) => ColoredBox(
      color: candidate.isEmpty ? Colors.transparent : context.colors.accent.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        child: cast.characters.isEmpty
            ? EmptyCast(loading: cast.loading)
            : TileGrid(
                minWidth: TileGrid.characterWidth,
                height: TileGrid.characterHeight,
                children: [
                  for (final character in cast.characters)
                    CastCard(
                      key: ValueKey(character.id),
                      character: character,
                      cast: cast,
                      capture: capture,
                      dubbing: dubbing,
                    ),
                ],
              ),
      ),
    ),
  );
}

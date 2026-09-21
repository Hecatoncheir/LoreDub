// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../common/file_dialogs.dart';
import '../../../l10n/app_localizations.dart';
import '../../domain/character.dart';
import '../common/area_heading.dart';
import '../common/module_label.dart';
import '../dashboard/cubits/session_bloc.dart';
import '../theme.dart';
import 'cast_drop_area.dart';
import '../dashboard/cubits/cast_bloc.dart';
import '../dashboard/cubits/voice_capture_bloc.dart';

/// The cards themselves, with what it takes to add them and hand them on.
///
/// A card dropped here from a pack leaves that pack: the cast holds every
/// character whether a pack names them or not, so this is where a card goes
/// back to being in none.
class CharacterCast extends StatelessWidget {
  const CharacterCast({super.key});

  Future<void> _exportAll(BuildContext context, List<Character> characters) async {
    final cast = context.read<CastBloc>();
    final location = await context.read<FileDialogs>().saveJson('loredub-characters.json');
    if (location == null) return;
    cast.add(CastExported(location, characters));
  }

  /// Whether a dubbing session holds the worker is read on its own: a
  /// sample and a card measured from files each bring up a worker of their
  /// own, which would be taken from under that session, so both wait for it
  /// to end — and a recognized phrase must not redraw every card.
  @override
  Widget build(BuildContext context) => BlocSelector<SessionBloc, SessionState, bool>(
    selector: (pipeline) => pipeline.running,
    builder: (context, dubbing) => BlocBuilder<CastBloc, CastState>(
      builder: (context, state) => BlocBuilder<VoiceCaptureBloc, VoiceCaptureState>(
        builder: (context, capture) {
          final l10n = AppLocalizations.of(context);
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 9, 12, 8),
                  child: AreaHeading(
                    label: ModuleLabel(number: '02', label: l10n.areaCast),
                    actions: [
                      TextButton.icon(
                        onPressed: state.characters.isEmpty
                            ? null
                            : () => _exportAll(context, state.characters),
                        icon: const Icon(Icons.file_upload_outlined, size: 18),
                        label: Text(l10n.charactersExportAll),
                        style: TextButton.styleFrom(foregroundColor: context.colors.mutedInk),
                      ),
                      FilledButton.icon(
                        key: const ValueKey('charactersAdd'),
                        onPressed: () =>
                            context.read<CastBloc>().add(CardAdded(l10n.charactersNewName)),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(l10n.charactersAdd),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                CastDropArea(cast: state, capture: capture, dubbing: dubbing),
              ],
            ),
          );
        },
      ),
    ),
  );
}

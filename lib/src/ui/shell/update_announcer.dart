// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/app_release.dart';
import '../dashboard/cubits/startup_cubit.dart';
import '../dashboard/cubits/update_bloc.dart';

/// Asks for the newest release once the first load has come back, and
/// words the Windows toast about it, once, in the language the interface is
/// in, handing it back to [UpdateBloc] to raise.
///
/// Both are the interface's to arrange: the bloc knows there is news and
/// nothing of how it is said, and the startup and the update check know
/// nothing of each other. The check waits for the load because the proxy it
/// goes through is a setting, and so that the dashboard is up before GitHub
/// is asked anything -- a failed check must not look like a failed start.
class UpdateAnnouncer extends StatelessWidget {
  const UpdateAnnouncer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<StartupCubit, bool>(
        listenWhen: (initializing, now) => initializing && !now,
        listener: (context, _) =>
            context.read<UpdateBloc>().add(const UpdatesChecked(announce: true)),
      ),
      BlocListener<UpdateBloc, UpdateState>(
        listenWhen: (before, after) => after.announce && !before.announce,
        listener: (context, updates) {
          final release = updates.release;
          if (release == null) return;
          final l10n = AppLocalizations.of(context);
          context.read<UpdateBloc>().add(
            UpdateAnnounced(
              title: l10n.updateAvailableTitle,
              body: l10n.updateAvailableBody(release.version),
            ),
          );
        },
      ),
    ],
    child: child,
  );
}

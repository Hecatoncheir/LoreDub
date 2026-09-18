// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../common/confirm_dialog.dart';

/// Asks before a model leaves the disk: hundreds of megabytes are not worth
/// losing to a stray click.
Future<bool> confirmModelRemoval(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
}) {
  final l10n = AppLocalizations.of(context);
  return confirmRemoval(
    context,
    title: title,
    message: message,
    cancelLabel: l10n.modelRemoveCancel,
    confirmLabel: confirmLabel ?? l10n.modelRemoveConfirm,
  );
}

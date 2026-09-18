// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/package_transfer.dart';

void main() {
  final translation = translationModelFor('ru')!;
  final speech = speechModelFor('ru')!;

  test('rests while nothing is on its way', () {
    final transfer = PackageTransfer([
      ModelInstallState(model: translation, installed: true),
      ModelInstallState(model: speech),
    ]);

    expect(transfer.inFlight, isFalse);
    expect(transfer.anyInstalled, isTrue);
    expect(transfer.missing.single.model, speech);
  });

  test('resumes the whole pair, not only the half that was paused', () {
    final transfer = PackageTransfer([
      ModelInstallState(model: translation, progress: 0.3, paused: true),
      ModelInstallState(model: speech),
    ]);

    expect(transfer.inFlight, isTrue);
    expect(transfer.running, isFalse);
    expect([for (final part in transfer.toResume) part.model], [translation, speech]);
    expect([for (final part in transfer.toCancel) part.model], [translation]);
  });

  test('cancels what arrives and what is held alike', () {
    final transfer = PackageTransfer([
      ModelInstallState(model: translation, progress: 0.3),
      ModelInstallState(model: speech, progress: 0.1, paused: true),
    ]);

    expect(transfer.running, isTrue);
    expect([for (final part in transfer.toCancel) part.model], [translation, speech]);
  });
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/domain/model_selection.dart';
import 'package:lore_dub/src/domain/start_requirements.dart';

void main() {
  ModelSelection selection(AppSettings settings, {bool downloaded = true}) => ModelSelection(
    models: [
      for (final model in modelCatalog) ModelInstallState(model: model, installed: downloaded),
    ],
    settings: settings,
  );

  test('asks for nothing when the machine is ready and the game is chosen', () {
    expect(
      stepsBeforeStart(selection(const AppSettings()), gameChosen: true),
      isEmpty,
    );
  });

  test('asks for the packages a fresh install has none of', () {
    expect(
      stepsBeforeStart(selection(const AppSettings(), downloaded: false), gameChosen: true),
      [StartStep.models],
    );
  });

  test('asks for the route while it is taken apart on the graph', () {
    expect(
      stepsBeforeStart(
        selection(const AppSettings(captureRouted: false)),
        gameChosen: true,
      ),
      [StartStep.route],
    );
  });

  test('asks for the game only while the mode listens to one', () {
    expect(
      stepsBeforeStart(selection(const AppSettings()), gameChosen: false),
      [StartStep.game],
    );
    expect(
      stepsBeforeStart(
        selection(const AppSettings(audioCaptureSource: AudioCaptureSource.system)),
        gameChosen: false,
      ),
      isEmpty,
      reason: 'the whole output is captured, whichever window is in front',
    );
  });

  test('keeps the steps in the order they are met', () {
    expect(
      stepsBeforeStart(
        selection(const AppSettings(captureRouted: false), downloaded: false),
        gameChosen: false,
      ),
      [StartStep.models, StartStep.route, StartStep.game],
    );
  });
}

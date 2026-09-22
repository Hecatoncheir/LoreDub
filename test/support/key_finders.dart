// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/domain/hotkey.dart';
import 'package:lore_dub/src/ui/common/key_cap.dart';
import 'package:lore_dub/src/ui/common/key_combination.dart';

/// The keys of [display] -- "Ctrl + Alt + S" -- drawn as keys held together,
/// wherever they stand: a note that names them, or the field that binds
/// them. The words around a combination no longer hold it as text.
Finder keysHeld(String display) => find.byWidgetPredicate(
  (widget) => widget is KeyCombination && widget.keys.join(Hotkey.joiner) == display,
  description: 'the keys $display',
);

/// One key drawn as a key.
Finder keyCap(String label) => find.byWidgetPredicate(
  (widget) => widget is KeyCap && widget.label == label,
  description: 'the key $label',
);

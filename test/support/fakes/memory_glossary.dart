// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:lore_dub/src/data/services/glossary_service.dart';
import 'package:lore_dub/src/domain/glossary.dart';
import 'package:mocktail/mocktail.dart';

/// The glossary's file with no disk behind it: what is written down, what a
/// session would be handed, and what an import would read.
///
/// The canvas reads the glossary before it draws, as the glossary screen
/// does, and a real file answers neither inside a widget test's fake time.
class MemoryGlossary extends Fake implements GlossaryService {
  Glossary stored = Glossary.empty;
  Glossary incoming = Glossary.empty;
  final exported = <(String, Glossary)>[];

  /// What saving fails with, if it is to.
  Error? failure;

  @override
  Future<Glossary> load() async => stored;

  @override
  Future<void> save(Glossary glossary) async {
    if (failure case final failure?) throw failure;
    stored = glossary;
  }

  /// Offers nothing: the packs that come with the application are the
  /// service's own test.
  @override
  Future<Glossary> withBuiltIn(Glossary glossary, Glossary builtIn) async => glossary;

  @override
  Future<void> exportTo(String destination, Glossary glossary) async =>
      exported.add((destination, glossary));

  @override
  Future<Glossary> readFiles(List<String> sources) async => incoming;
}

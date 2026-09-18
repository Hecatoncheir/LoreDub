// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/downloads_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/dashboard_context.dart';

void main() {
  test('compares what is installed by what the sets hold', () {
    final one = InstalledPackages(models: {'base', 'ru'}, runtimes: {'cuda'});
    final same = InstalledPackages(models: {'ru', 'base'}, runtimes: {'cuda'});

    expect(one, same);
    expect(one.hashCode, same.hashCode);
    expect(one, isNot(InstalledPackages(models: {'base'}, runtimes: {'cuda'})));
    expect(one, isNot(InstalledPackages(models: {'base', 'ru'}, runtimes: const {})));
  });

  test('lets a builder through only when the part it names changes', () {
    final condition = whenChanged<(int, String)>((state) => state.$1);

    expect(condition((1, 'a'), (1, 'b')), isFalse);
    expect(condition((1, 'a'), (2, 'a')), isTrue);
  });
}

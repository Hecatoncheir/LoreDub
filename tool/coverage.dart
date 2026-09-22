// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

/// Reads the line coverage `flutter test --coverage` wrote to
/// `coverage/lcov.info`, area by area, and fails on any area of
/// `tool/coverage_baseline.json` that fell below the share it holds there.
///
/// The baseline names the areas the engineering plan (`TODO.md`, stage 7)
/// holds up -- the data layer, where the defects were found and the
/// coverage was lowest, and the domain -- and is only raised: `--update`
/// writes what the areas reach now, and is refused while any of them is
/// below it. The rest of `lib/` is reported beside them and holds nothing
/// back, an interface drawn differently being no reason to fail a build.
void main(List<String> arguments) {
  final update = arguments.contains('--update');
  final lcov = File(_option(arguments, '--lcov') ?? 'coverage/lcov.info').readAsStringSync();
  final baselineFile = File('tool/coverage_baseline.json');
  final baseline = (jsonDecode(baselineFile.readAsStringSync()) as Map<String, Object?>).map(
    (key, value) => MapEntry(key, (value! as num).toDouble()),
  );
  final areas = {...baseline.keys, ...reportedAreas};
  final shares = coverageByArea(lcov, areas);
  final verdicts = [
    for (final area in areas.toList()..sort())
      CoverageVerdict(area, shares[area] ?? const AreaCoverage(0, 0), baseline[area]),
  ];
  for (final verdict in verdicts) {
    stdout.writeln(verdict.describe());
  }
  if (verdicts.any((verdict) => verdict.fell)) {
    stderr.writeln('Coverage fell below tool/coverage_baseline.json.');
    exitCode = 1;
    return;
  }
  if (update) {
    final raised = {
      for (final verdict in verdicts)
        if (verdict.allowed != null) verdict.area: verdict.coverage.percent,
    };
    baselineFile.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(raised)}\n');
    stdout.writeln('Baseline written.');
  } else if (verdicts.any((verdict) => verdict.rose)) {
    stdout.writeln('Coverage went up: run with --update and commit the baseline.');
  }
}

/// Shown whether or not the baseline holds them.
const reportedAreas = ['lib/', 'lib/src/ui/'];

/// The lines of one area that the tests ran, of all it has.
class AreaCoverage {
  const AreaCoverage(this.hit, this.lines);

  final int hit;
  final int lines;

  /// The share run, as a percentage to one decimal: what the baseline holds,
  /// so a line's worth of rounding cannot fail a build.
  double get percent => lines == 0 ? 0 : (hit * 1000 / lines).round() / 10;
}

/// The coverage of every one of [areas] -- path prefixes such as
/// `lib/src/data/` -- in an lcov report. Generated code is passed over: the
/// bindings and the localizations are nobody's to test. So is the bridge
/// that calls the bindings: a line of it runs only by calling the real
/// library, which no test may do, and a share counted there was the tests
/// registering hotkeys and drawing on the screen of whoever ran them.
Map<String, AreaCoverage> coverageByArea(String lcov, Iterable<String> areas) {
  final hit = {for (final area in areas) area: 0};
  final lines = {for (final area in areas) area: 0};
  String? file;
  for (final line in const LineSplitter().convert(lcov)) {
    if (line.startsWith('SF:')) {
      final path = line.substring(3).replaceAll(r'\', '/');
      file = _generated(path) ? null : path;
    } else if (line.startsWith('DA:') && file != null) {
      final count = int.parse(line.substring(3).split(',')[1]);
      for (final area in areas) {
        if (!_within(file, area)) continue;
        lines[area] = lines[area]! + 1;
        if (count > 0) hit[area] = hit[area]! + 1;
      }
    }
  }
  return {for (final area in areas) area: AreaCoverage(hit[area]!, lines[area]!)};
}

bool _generated(String path) =>
    path.endsWith('.g.dart') ||
    path.contains('lib/l10n/') ||
    path.endsWith('lib/src/data/services/native_bridge.dart');

/// Whether [file] -- relative, or absolute as some runners write it -- lies
/// under [area].
bool _within(String file, String area) => file.startsWith(area) || file.contains('/$area');

/// One area against the share it may not fall below.
class CoverageVerdict {
  const CoverageVerdict(this.area, this.coverage, this.allowed);

  final String area;
  final AreaCoverage coverage;

  /// Null for an area only reported.
  final double? allowed;

  bool get fell => allowed != null && coverage.percent < allowed!;
  bool get rose => allowed != null && coverage.percent > allowed!;

  String describe() {
    final mark = fell ? 'FAIL' : (rose ? 'up  ' : 'ok  ');
    final share = '${coverage.percent}% (${coverage.hit} / ${coverage.lines})';
    return '$mark  $area: $share${allowed == null ? '' : ' / $allowed%'}';
  }
}

String? _option(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  return index >= 0 && index + 1 < arguments.length ? arguments[index + 1] : null;
}

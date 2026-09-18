// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

/// Counts what the engineering plan (`TODO.md`, stage 0) wants gone and fails
/// on any count above `tool/ratchet_baseline.json`, which is only lowered.
///
/// Two sources: the issues `dart_code_linter:metrics analyze --reporter=json`
/// wrote to `--metrics`, counted per rule, and the colours and text styles
/// widgets write out by hand rather than read off the theme, counted over
/// `lib/` outside the theme itself. Totals rather than places, so moving a
/// widget into a file of its own leaves the numbers where they were.
///
/// `--update` writes the counts as the new baseline, and is refused while
/// any of them is above it.
void main(List<String> arguments) {
  final metrics = _option(arguments, '--metrics');
  final update = arguments.contains('--update');
  final baselineFile = File('tool/ratchet_baseline.json');
  final counts = {
    if (metrics != null) ...countRuleIssues(File(metrics).readAsStringSync()),
    ...countHandWrittenStyles(_sources(Directory('lib'))),
  };
  final baseline = (jsonDecode(baselineFile.readAsStringSync()) as Map<String, Object?>).map(
    (key, value) => MapEntry(key, value! as int),
  );
  final verdicts = compareToBaseline(counts, baseline);
  for (final verdict in verdicts) {
    stdout.writeln(verdict.describe());
  }
  if (verdicts.any((verdict) => verdict.grew)) {
    stderr.writeln('A count grew past tool/ratchet_baseline.json.');
    exitCode = 1;
    return;
  }
  if (update) {
    final merged = {...baseline, ...counts};
    final sorted = {for (final name in merged.keys.toList()..sort()) name: merged[name]};
    baselineFile.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(sorted)}\n');
    stdout.writeln('Baseline written.');
  } else if (verdicts.any((verdict) => verdict.shrank)) {
    stdout.writeln('Counts went down: run with --update and commit the baseline.');
  }
}

/// What widgets must read off the theme rather than spell out.
const handWrittenStyles = ['LoreDubPalette.', 'Color(0x', 'TextStyle('];

/// Issues per rule in a `dart_code_linter` JSON report.
Map<String, int> countRuleIssues(String report) {
  final counts = <String, int>{};
  final records = (jsonDecode(report) as Map<String, Object?>)['records']! as List<Object?>;
  for (final record in records.cast<Map<String, Object?>>()) {
    final issues = (record['issues'] as List<Object?>?) ?? const [];
    for (final issue in issues.cast<Map<String, Object?>>()) {
      final rule = issue['ruleId']! as String;
      counts[rule] = (counts[rule] ?? 0) + 1;
    }
  }
  return counts;
}

/// Occurrences of every [handWrittenStyles] pattern over [sources], which
/// maps a path to its text. The theme is where they belong, so it is passed
/// over, as is generated code.
Map<String, int> countHandWrittenStyles(Map<String, String> sources) {
  final counts = {for (final pattern in handWrittenStyles) pattern: 0};
  for (final MapEntry(key: file, value: text) in sources.entries) {
    if (_belongsToTheme(file) || file.endsWith('.g.dart')) continue;
    for (final pattern in handWrittenStyles) {
      counts[pattern] = counts[pattern]! + pattern.allMatches(text).length;
    }
  }
  return counts;
}

bool _belongsToTheme(String file) {
  final normalized = file.replaceAll(r'\', '/');
  return normalized.endsWith('lib/src/ui/theme.dart') || normalized.contains('lib/src/ui/theme/');
}

/// One count against the number it may not exceed.
class RatchetVerdict {
  const RatchetVerdict(this.name, this.count, this.allowed);

  final String name;
  final int count;

  /// Null for a count the baseline does not name yet, which is let through:
  /// `--update` is what adds it.
  final int? allowed;

  bool get grew => allowed != null && count > allowed!;
  bool get shrank => allowed != null && count < allowed!;

  String describe() {
    final mark = grew ? 'FAIL' : (shrank ? 'down' : 'ok  ');
    return '$mark  $name: $count${allowed == null ? ' (new)' : ' / $allowed'}';
  }
}

List<RatchetVerdict> compareToBaseline(Map<String, int> counts, Map<String, int> baseline) => [
  for (final MapEntry(key: name, value: count) in counts.entries)
    RatchetVerdict(name, count, baseline[name]),
];

Map<String, String> _sources(Directory root) => {
  for (final file in root.listSync(recursive: true).whereType<File>())
    if (file.path.endsWith('.dart')) file.path: file.readAsStringSync(),
};

String? _option(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  return index >= 0 && index + 1 < arguments.length ? arguments[index + 1] : null;
}

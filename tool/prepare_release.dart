// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:crypto/crypto.dart';

void main(List<String> arguments) {
  try {
    final options = _parseArguments(arguments);
    final tag = options['tag'];
    final outputPath = options['output'];
    if (tag == null || outputPath == null) {
      throw const FormatException(
        'Usage: dart run tool/prepare_release.dart '
        '--tag v<major>.<minor>.<patch> --output <path> [--installer <setup.exe>]',
      );
    }

    final match = RegExp(r'^v(\d+\.\d+\.\d+)$').firstMatch(tag);
    if (match == null) {
      throw FormatException('Release tag "$tag" must have the form v1.2.3.');
    }
    final version = match.group(1)!;
    final pubspecVersion = _readPubspecVersion(File('pubspec.yaml').readAsStringSync());
    if (pubspecVersion != version) {
      throw FormatException(
        'Tag $tag does not match pubspec.yaml version $pubspecVersion.',
      );
    }

    var notes = extractReleaseNotes(
      File('CHANGELOG.md').readAsStringSync(),
      version,
    );
    // The digest of what is published beside the notes, so a player who
    // downloaded the setup somewhere else can tell it is the one released.
    if (options['installer'] case final installer?) {
      final setup = File(installer);
      notes = withInstallerDigest(
        notes,
        setup.uri.pathSegments.last,
        sha256.convert(setup.readAsBytesSync()).toString(),
      );
    }
    final output = File(outputPath);
    output.parent.createSync(recursive: true);
    output.writeAsStringSync('$notes\n');
    stdout.writeln('Prepared release notes for LoreDub $version.');
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

String _readPubspecVersion(String contents) {
  final match = RegExp(r'^version:\s*([^+\s]+)', multiLine: true).firstMatch(contents);
  if (match == null) {
    throw const FormatException('pubspec.yaml does not contain a version.');
  }
  return match.group(1)!;
}

/// [notes] with a closing line naming the setup [file] and its SHA-256
/// [digest], in the notes' own language: the players read them.
String withInstallerDigest(String notes, String file, String digest) =>
    '$notes\n\n---\n\nSHA-256 `$file`: `$digest`';

String extractReleaseNotes(String changelog, String version) {
  final lines = changelog.split(RegExp(r'\r?\n'));
  final heading = RegExp('^## \\[${RegExp.escape(version)}\\](?: - .+)?\$');
  final start = lines.indexWhere(heading.hasMatch);
  if (start < 0) {
    throw FormatException(
      'CHANGELOG.md does not contain a "## [$version] - YYYY-MM-DD" section.',
    );
  }

  var end = lines.length;
  for (var index = start + 1; index < lines.length; index++) {
    if (lines[index].startsWith('## ')) {
      end = index;
      break;
    }
  }
  final body = lines.sublist(start + 1, end).join('\n').trim();
  if (body.isEmpty) {
    throw FormatException('CHANGELOG.md section for $version is empty.');
  }
  return body;
}

Map<String, String> _parseArguments(List<String> arguments) {
  final result = <String, String>{};
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (!argument.startsWith('--') || index + 1 >= arguments.length) {
      throw FormatException('Invalid argument: $argument');
    }
    result[argument.substring(2)] = arguments[++index];
  }
  return result;
}

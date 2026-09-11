// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../domain/app_release.dart';
import '../../domain/download_control.dart';
import '../../domain/failure.dart';
import '../../domain/model_package.dart';
import 'artifact_downloader.dart';

typedef UpdateRootProvider = Future<Directory> Function();
typedef ProcessStarter = Future<Process> Function(String executable, List<String> arguments);

/// Downloads a newer release's setup and hands the application over to it.
///
/// [restartInto] starts the setup itself, silently, and ends this process.
/// The setup closes whatever still holds the application's files, installs
/// for the current user — so no administrator prompt interrupts it — and,
/// asked with `/RELAUNCH`, opens the new version when it is done.
///
/// There is no script in between on purpose: a detached `powershell.exe`
/// started from here never ran a line, which left the application closed
/// and the old version in place.
class UpdateInstaller {
  UpdateInstaller({
    this._client,
    UpdateRootProvider? root,
    String? executable,
    ProcessStarter? start,
    void Function(int code)? exit,
  }) : _root = root ?? _defaultRoot,
       _executable = executable ?? Platform.resolvedExecutable,
       _start = start ?? _startDetached,
       _exit = exit ?? _exitProcess;

  final http.Client? _client;
  final UpdateRootProvider _root;
  final String _executable;
  final ProcessStarter _start;
  final void Function(int code) _exit;

  /// What the setup is told when it replaces this copy. `/RELAUNCH` is ours:
  /// `installer/lore_dub.iss` opens the application again only when it sees it.
  static const setupArguments = [
    '/VERYSILENT',
    '/SUPPRESSMSGBOXES',
    '/NORESTART',
    '/SP-',
    '/CLOSEAPPLICATIONS',
    '/RELAUNCH',
  ];

  static Future<Directory> _defaultRoot() async {
    final support = await getApplicationSupportDirectory();
    return Directory(path.join(support.path, 'updates'));
  }

  static Future<Process> _startDetached(String executable, List<String> arguments) =>
      Process.start(executable, arguments, mode: ProcessStartMode.detached);

  static void _exitProcess(int code) => exit(code);

  /// Whether the setup put this copy in place. Inno Setup leaves its
  /// uninstaller beside the application; a build run from its folder has
  /// none, and a setup run from it would install a second copy elsewhere
  /// instead of updating this one.
  bool get canInstall => File(path.join(path.dirname(_executable), 'unins000.exe')).existsSync();

  /// The path of [installer] when an earlier run already downloaded it whole,
  /// so a restart of the application does not ask for the download again.
  Future<String?> downloaded(ReleaseInstaller installer) async {
    final setup = File(path.join((await _root()).path, installer.name));
    if (!await setup.exists()) return null;
    return await verifyArtifact(setup, _artifact(installer)) ? setup.path : null;
  }

  /// Fetches [installer] — resuming a part an earlier try left, checked
  /// against its size and, when published, its digest — and returns its path.
  Future<String> download(
    ReleaseInstaller installer, {
    required DownloadProgress onProgress,
    String proxyUrl = '',
  }) async {
    final directory = await _root();
    await directory.create(recursive: true);
    // The setups of versions already installed are only dead weight, and so
    // is the script earlier versions handed the update to.
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File) continue;
      final name = path.basename(entry.path);
      final stale =
          name == 'apply_update.ps1' || (path.extension(name) == '.exe' && name != installer.name);
      if (!stale) continue;
      try {
        await entry.delete();
      } on FileSystemException {
        // Best effort: a setup still held open goes next time.
      }
    }
    final client = _client ?? await createDownloadClient(proxyUrl);
    try {
      final outcome = await downloadArtifacts(
        [_artifact(installer)],
        directory: directory,
        client: client,
        onProgress: onProgress,
      );
      if (outcome != DownloadOutcome.completed) {
        throw LoreDubFailure(FailureCode.updateInstallFailed, detail: outcome.name);
      }
      return path.join(directory.path, installer.name);
    } finally {
      if (_client == null) client.close();
    }
  }

  /// Starts [setup] and ends this process. The setup writes what it did to
  /// `update.log` beside it.
  Future<void> restartInto(String setup) async {
    final log = path.join(path.dirname(setup), 'update.log');
    try {
      await _start(setup, [...setupArguments, '/LOG=$log']);
    } on ProcessException catch (error) {
      throw LoreDubFailure(FailureCode.updateInstallFailed, detail: error.message);
    }
    _exit(0);
  }

  static ModelArtifact _artifact(ReleaseInstaller installer) => ModelArtifact(
    fileName: installer.name,
    url: installer.url,
    byteSize: installer.size,
    hash: installer.sha256,
  );
}

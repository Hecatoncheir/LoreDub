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
/// A running application cannot overwrite its own files, so the setup does
/// not run while it is open: [restartInto] leaves a small script behind that
/// waits for this process to end, runs the setup without a window, and
/// starts the new version. The setup installs for the current user, so no
/// administrator prompt interrupts it.
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

  /// Fetches [installer] — resuming a part an earlier try left, checked
  /// against its size and, when published, its digest — and returns its path.
  Future<String> download(
    ReleaseInstaller installer, {
    required DownloadProgress onProgress,
    String proxyUrl = '',
  }) async {
    final directory = await _root();
    await directory.create(recursive: true);
    // The setups of versions already installed are only dead weight.
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File || path.extension(entry.path) != '.exe') continue;
      if (path.basename(entry.path) == installer.name) continue;
      try {
        await entry.delete();
      } on FileSystemException {
        // Best effort: a setup still held open goes next time.
      }
    }
    final client = _client ?? await createDownloadClient(proxyUrl);
    try {
      final outcome = await downloadArtifacts(
        [
          ModelArtifact(
            fileName: installer.name,
            url: installer.url,
            byteSize: installer.size,
            hash: installer.sha256,
          ),
        ],
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

  /// Leaves the application to [setup] and ends this process. The script
  /// the setup runs from writes what happened to `update.log` beside it.
  Future<void> restartInto(String setup) async {
    final script = File(path.join(path.dirname(setup), 'apply_update.ps1'));
    await script.writeAsString(_applyUpdateScript, flush: true);
    try {
      await _start('powershell.exe', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-File',
        script.path,
        '-ProcessId',
        '$pid',
        '-Setup',
        setup,
        '-Executable',
        _executable,
      ]);
    } on ProcessException catch (error) {
      throw LoreDubFailure(FailureCode.updateInstallFailed, detail: error.message);
    }
    _exit(0);
  }
}

/// ASCII only: Windows PowerShell reads a script without a byte order mark
/// in the ANSI code page.
const _applyUpdateScript = r'''
param([int]$ProcessId, [string]$Setup, [string]$Executable)
$log = Join-Path (Split-Path -Parent $Setup) 'update.log'
function Note([string]$line) { "$(Get-Date -Format o) $line" | Out-File -FilePath $log -Append -Encoding utf8 }
Note "waiting for LoreDub ($ProcessId) to close"
Wait-Process -Id $ProcessId -Timeout 60 -ErrorAction SilentlyContinue
Note "running $Setup"
$installer = Start-Process -FilePath $Setup -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', '/CLOSEAPPLICATIONS' -Wait -PassThru
Note "setup finished with exit code $($installer.ExitCode)"
Start-Process -FilePath $Executable
''';

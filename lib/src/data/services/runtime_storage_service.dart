// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../domain/compute_device.dart';
import '../../domain/download_control.dart';
import '../../domain/failure.dart';
import '../../domain/model_proxy.dart';
import '../../domain/runtime_package.dart';
import '../../domain/runtime_paths.dart';
import 'artifact_downloader.dart';
import 'runtime_catalog.dart';

typedef RuntimeRootProvider = Future<Directory> Function();

/// A started process: what it will report, and how to stop it early.
///
/// pip cannot be paused, but it can be killed, and a cancel that left it
/// writing wheels into the target directory would not be a cancel at all.
typedef RunningProcess = ({Future<ProcessResult> result, void Function() kill});
typedef ProcessStarter = RunningProcess Function(String executable, List<String> arguments);

/// Fetches and unpacks the GPU runtimes.
///
/// These live beside the models rather than inside the installation, because
/// they are downloaded after the fact and a player who never turns the GPU on
/// should never pay for them.
class RuntimeStorageService {
  RuntimeStorageService({
    this._client,
    RuntimeRootProvider? rootProvider,
    ProcessStarter? startProcess,
  }) : _rootProvider = rootProvider ?? _defaultRoot,
       _startProcess = startProcess ?? _defaultStartProcess;

  final http.Client? _client;
  final RuntimeRootProvider _rootProvider;
  final ProcessStarter _startProcess;

  static Future<Directory> _defaultRoot() async {
    final support = await getApplicationSupportDirectory();
    return Directory(path.join(support.path, 'runtime'));
  }

  static RunningProcess _defaultStartProcess(String executable, List<String> arguments) {
    final started = Process.start(executable, arguments);
    Process? running;
    return (
      result: started.then((process) async {
        running = process;
        // Collected rather than streamed: only the tail matters, and it is
        // read once the process is done.
        final out = process.stdout.transform(const SystemEncoding().decoder).join();
        final err = process.stderr.transform(const SystemEncoding().decoder).join();
        final code = await process.exitCode;
        return ProcessResult(process.pid, code, await out, await err);
      }),
      kill: () => running?.kill(),
    );
  }

  Future<Directory> rootDirectory() async {
    final root = await _rootProvider();
    await root.create(recursive: true);
    return root;
  }

  Future<Directory> directoryFor(RuntimePackage package) async {
    final root = await rootDirectory();
    return Directory(path.join(root.path, package.id));
  }

  /// A runtime counts as present only when the file that proves the unpack
  /// finished is there. A directory left behind by a cancelled download would
  /// otherwise make the backend look ready.
  Future<bool> isInstalled(RuntimePackage package) async {
    final directory = await directoryFor(package);
    final probe = package.probeFileName;
    if (probe == null) return directory.exists();
    final asFile = File(path.join(directory.path, probe));
    if (await asFile.exists()) return true;
    return Directory(path.join(directory.path, probe)).exists();
  }

  /// Which of the catalogued runtimes are ready, plus the Vulkan build that
  /// ships with the installer and so is never downloaded.
  Future<Set<String>> installedRuntimeIds({String? runtimeDirectory}) async {
    final installed = <String>{};
    for (final package in runtimeCatalog) {
      if (await isInstalled(package)) installed.add(package.id);
    }
    if (await File(
      whisperExecutablePath(
        runtimeDirectory: runtimeDirectory,
        backend: ComputeBackend.vulkan,
      ),
    ).exists()) {
      installed.add('whisper-vulkan');
    }
    return installed;
  }

  Future<DownloadOutcome> install(
    RuntimePackage package, {
    required DownloadProgress onProgress,
    String proxyUrl = '',
    String pythonExecutable = '',
    DownloadControl? control,
  }) async {
    final directory = await directoryFor(package);
    final outcome = switch (package.kind) {
      RuntimeInstallKind.archive => await _installArchive(
        package,
        directory: directory,
        onProgress: onProgress,
        proxyUrl: proxyUrl,
        control: control,
      ),
      RuntimeInstallKind.pip => await _installWithPip(
        package,
        directory: directory,
        onProgress: onProgress,
        proxyUrl: proxyUrl,
        pythonExecutable: pythonExecutable,
        control: control,
      ),
    };
    if (outcome == DownloadOutcome.completed) onProgress(1);
    return outcome;
  }

  Future<DownloadOutcome> _installArchive(
    RuntimePackage package, {
    required Directory directory,
    required DownloadProgress onProgress,
    required String proxyUrl,
    DownloadControl? control,
  }) async {
    final client = _client ?? await createDownloadClient(proxyUrl);
    final DownloadOutcome outcome;
    try {
      // The download is the long half; unpacking gets the last tenth of the
      // bar so the interface does not sit at 100% while it still works.
      outcome = await downloadArtifacts(
        package.artifacts,
        directory: directory,
        client: client,
        onProgress: (value) => onProgress(value * 0.9),
        control: control,
      );
    } finally {
      if (_client == null) client.close();
    }
    // Unpacking a half-downloaded archive would only produce rubbish; the
    // part stays for a pause and is already gone for a cancel.
    if (outcome != DownloadOutcome.completed) return outcome;
    for (final artifact in package.artifacts) {
      final archive = File(path.join(directory.path, artifact.fileName));
      await _unpack(archive, directory);
      await archive.delete();
    }
    await _flatten(directory, package.probeFileName);
    return DownloadOutcome.completed;
  }

  /// Unpacks in a worker so a 450 MB archive does not freeze the interface.
  /// Only the two paths cross into the isolate: a closure over the files
  /// themselves would drag this service along with them.
  static Future<void> _unpack(File archive, Directory destination) {
    final archivePath = archive.path;
    final destinationPath = destination.path;
    return Isolate.run(() => extractFileToDisk(archivePath, destinationPath));
  }

  /// The official whisper.cpp archives keep their binaries in a subdirectory
  /// whose name changes between builds. The pipeline wants one fixed path, so
  /// whatever directory holds the probe file is lifted to the top.
  Future<void> _flatten(Directory directory, String? probeFileName) async {
    if (probeFileName == null) return;
    if (await File(path.join(directory.path, probeFileName)).exists()) return;
    await for (final entry in directory.list(recursive: true, followLinks: false)) {
      if (entry is! File || path.basename(entry.path) != probeFileName) continue;
      final source = entry.parent;
      await for (final sibling in source.list(followLinks: false)) {
        if (sibling is! File) continue;
        await sibling.rename(path.join(directory.path, path.basename(sibling.path)));
      }
      return;
    }
    throw LoreDubFailure(FailureCode.runtimeIncomplete, detail: probeFileName);
  }

  /// CUDA torch is a wheel set only pip can resolve for the interpreter in
  /// use, so it is installed into its own directory and put on the worker's
  /// import path rather than replacing the bundled CPU build.
  /// pip runs to the end or not at all: there is no way to hold it half way
  /// and pick it up later, so only a cancel is offered, and it kills the
  /// process and clears what was written into the target directory.
  Future<DownloadOutcome> _installWithPip(
    RuntimePackage package, {
    required Directory directory,
    required DownloadProgress onProgress,
    required String proxyUrl,
    required String pythonExecutable,
    DownloadControl? control,
  }) async {
    final python = await resolvePythonExecutable(pythonExecutable);
    await directory.create(recursive: true);
    // pip reports its own progress on a terminal it does not have here, so
    // the bar reflects the one step that is happening rather than guessing.
    onProgress(0.05);
    final proxy = parseModelProxyUrl(proxyUrl);
    final running = _startProcess(python, [
      '-m',
      'pip',
      'install',
      '--no-cache-dir',
      '--target',
      directory.path,
      if (proxy != null) ...['--proxy', proxyUrl.trim()],
      ...package.pipArguments,
    ]);
    final watch = _killWhenStopped(running, control);
    final result = await running.result;
    watch?.cancel();
    if (control?.isStopping ?? false) {
      // Whatever pip managed to unpack is not a runtime, and it must not be
      // mistaken for one on the next start.
      if (await directory.exists()) await directory.delete(recursive: true);
      return DownloadOutcome.cancelled;
    }
    if (result.exitCode != 0) {
      throw LoreDubFailure(
        FailureCode.runtimeInstallFailed,
        detail: '${result.exitCode}\n${result.stderr}'.trim(),
      );
    }
    return DownloadOutcome.completed;
  }

  /// Watches for a stop while a process runs, and kills it when one comes.
  static Timer? _killWhenStopped(RunningProcess running, DownloadControl? control) {
    if (control == null) return null;
    return Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!control.isStopping) return;
      timer.cancel();
      running.kill();
    });
  }

  Future<void> remove(RuntimePackage package) async {
    final directory = await directoryFor(package);
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

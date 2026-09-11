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
        python: await resolvePythonExecutable(pythonExecutable),
        control: control,
      ),
      RuntimeInstallKind.wheel => await _installWheel(
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

  /// CUDA torch is one 2.7 GB wheel. Fetched with the same downloader as the
  /// models, it can be paused, picked up again after a dropped or stalled
  /// connection, and verified; pip is then only asked to install the file and
  /// fetch the few small packages it depends on. Left to pip, the download
  /// showed no progress, could not be resumed, and was seen to hang for an
  /// hour on a connection that stopped delivering.
  ///
  /// An interpreter the wheel was not built for gets the old route, where pip
  /// resolves torch from the index itself.
  Future<DownloadOutcome> _installWheel(
    RuntimePackage package, {
    required Directory directory,
    required DownloadProgress onProgress,
    required String proxyUrl,
    required String pythonExecutable,
    DownloadControl? control,
  }) async {
    final python = await resolvePythonExecutable(pythonExecutable);
    if (await _interpreterTag(python) != package.wheelPython) {
      return _installWithPip(
        package,
        directory: directory,
        onProgress: onProgress,
        proxyUrl: proxyUrl,
        python: python,
        control: control,
      );
    }
    final downloads = await _downloadsFor(package);
    final client = _client ?? await createDownloadClient(proxyUrl);
    final DownloadOutcome fetched;
    try {
      fetched = await downloadArtifacts(
        package.artifacts,
        directory: downloads,
        client: client,
        // Installing the wheel gets the last tenth of the bar.
        onProgress: (value) => onProgress(value * 0.9),
        control: control,
      );
    } finally {
      if (_client == null) client.close();
    }
    if (fetched == DownloadOutcome.cancelled) await _deleteIfExists(downloads);
    if (fetched != DownloadOutcome.completed) return fetched;

    final outcome = await _runPip(
      python,
      directory,
      [for (final artifact in package.artifacts) path.join(downloads.path, artifact.fileName)],
      proxyUrl: proxyUrl,
      onStart: () => onProgress(0.9),
      control: control,
    );
    // Gigabytes that are worth nothing once installed, or once cancelled.
    // After a pause or a failed install the wheel stays, so the next attempt
    // does not fetch it again.
    if (outcome == DownloadOutcome.completed || outcome == DownloadOutcome.cancelled) {
      await _deleteIfExists(downloads);
    }
    return outcome;
  }

  /// pip resolving torch from the index on its own. It reports progress on a
  /// terminal it does not have here, and cannot be held half way, so the bar
  /// shows the one step that is happening and only a cancel is offered.
  Future<DownloadOutcome> _installWithPip(
    RuntimePackage package, {
    required Directory directory,
    required DownloadProgress onProgress,
    required String proxyUrl,
    required String python,
    DownloadControl? control,
  }) => _runPip(
    python,
    directory,
    package.pipArguments,
    proxyUrl: proxyUrl,
    onStart: () => onProgress(0.05),
    control: control,
  );

  /// `pip install --target`, leaving nothing behind unless it finished.
  ///
  /// The packages are installed into their own directory and put on the
  /// worker's import path rather than replacing the bundled CPU build. pip
  /// cannot be held half way: a stop kills it and clears what it wrote.
  Future<DownloadOutcome> _runPip(
    String python,
    Directory directory,
    List<String> packages, {
    required String proxyUrl,
    required void Function() onStart,
    DownloadControl? control,
  }) async {
    await directory.create(recursive: true);
    onStart();
    final proxy = parseModelProxyUrl(proxyUrl);
    final running = _startProcess(python, [
      '-m',
      'pip',
      'install',
      '--no-cache-dir',
      '--target',
      directory.path,
      // A connection dropped while fetching a dependency is tried again.
      '--retries',
      '10',
      if (proxy != null) ...['--proxy', proxyUrl.trim()],
      ...packages,
    ]);
    final watch = _killWhenStopped(running, control);
    final result = await running.result;
    watch?.cancel();
    if (control?.requestedStop case final stop?) {
      // Whatever pip managed to unpack is not a runtime, and it must not be
      // mistaken for one on the next start.
      await _deleteIfExists(directory);
      return stop;
    }
    if (result.exitCode != 0) {
      // pip can fail after it has moved part of the wheels into place, and a
      // torch directory would pass the probe. Only a finished install stays.
      await _deleteIfExists(directory);
      throw LoreDubFailure(
        FailureCode.runtimeInstallFailed,
        detail: '${result.exitCode}\n${_tail('${result.stderr}')}'.trim(),
      );
    }
    return DownloadOutcome.completed;
  }

  /// The wheel tag of an interpreter, `cp311` for Python 3.11, or null when
  /// it could not be asked.
  Future<String?> _interpreterTag(String python) async {
    final result = await _startProcess(python, [
      '-c',
      "import sys; sys.stdout.write('cp%d%d' % sys.version_info[:2])",
    ]).result;
    return result.exitCode == 0 ? '${result.stdout}'.trim() : null;
  }

  /// Where a wheel waits between its download and its install: beside the
  /// runtimes, so the probe never mistakes it for one.
  Future<Directory> _downloadsFor(RuntimePackage package) async =>
      Directory(path.join((await rootDirectory()).path, '.downloads', package.id));

  static Future<void> _deleteIfExists(Directory directory) async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  /// The last lines pip printed. It writes its whole resolution before the
  /// error, and the reason is always at the end.
  static String _tail(String output, {int lines = 6}) {
    final kept = output.split(RegExp(r'\r?\n')).where((line) => line.trim().isNotEmpty).toList();
    return kept.sublist(kept.length > lines ? kept.length - lines : 0).join('\n');
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
    await _deleteIfExists(await directoryFor(package));
    // A wheel left from a paused download goes with it.
    await _deleteIfExists(await _downloadsFor(package));
  }
}

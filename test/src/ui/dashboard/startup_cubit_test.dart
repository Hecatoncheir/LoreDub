// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/repositories/install_repository.dart';
import 'package:lore_dub/src/data/repositories/model_repository.dart';
import 'package:lore_dub/src/data/repositories/runtime_repository.dart';
import 'package:lore_dub/src/data/repositories/settings_repository.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/data/services/model_storage_service.dart';
import 'package:lore_dub/src/data/services/native_engine_service.dart';
import 'package:lore_dub/src/data/services/runtime_storage_service.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:lore_dub/src/domain/failure.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/failure_cubit.dart';
import 'package:lore_dub/src/ui/dashboard/cubits/startup_cubit.dart';
import 'package:lore_dub/src/data/repositories/system_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Machine machine;
  late _Disk disk;
  late InstallRepository installed;
  late FailureCubit failures;
  late StartupCubit startup;

  setUp(() {
    final settings = SettingsRepository(SettingsService())..seed(const AppSettings());
    machine = _Machine();
    disk = _Disk();
    installed = InstallRepository(disk, _Runtimes());
    failures = FailureCubit();
    startup = StartupCubit(settings, installed, machine, failures);
  });

  tearDown(() async {
    await startup.close();
    await failures.close();
  });

  test('a start waits for what is installed and what the machine can run', () async {
    expect(startup.state, isTrue, reason: 'initializing');

    await startup.start();

    expect(startup.state, isFalse);
    expect(installed.parts.models.single.installed, isTrue);
    expect(installed.parts.availability.cudaDriver, isTrue, reason: 'the probe was read');
    expect(installed.parts.availability.installedRuntimes, {'torch-cuda'});
    expect(failures.state, isNull);
  });

  test('a first load that fails is said, and does not hold the screen', () async {
    disk.fails = true;

    await startup.start();

    expect(startup.state, isFalse, reason: 'the buttons are not left waiting');
    expect(
      failures.state,
      isA<LoreDubFailure>().having(
        (failure) => failure.code,
        'code',
        FailureCode.initializationFailed,
      ),
    );
  });
}

class _Machine extends SystemRepository {
  _Machine() : super(NativeEngineService());

  @override
  Future<ComputeAvailability> probeGraphics() async => const ComputeAvailability(cudaDriver: true);
}

class _Disk extends ModelRepository {
  _Disk() : super(ModelStorageService());

  bool fails = false;

  @override
  Future<List<ModelInstallState>> loadStates() async {
    if (fails) throw StateError('disk unreadable');
    return [ModelInstallState(model: modelCatalog.first, installed: true)];
  }

  @override
  Future<String> rootDirectory() async => 'C:/models';
}

class _Runtimes extends RuntimeRepository {
  _Runtimes() : super(RuntimeStorageService());

  @override
  Future<Set<String>> installedIds() async => {'torch-cuda'};

  @override
  Future<String> rootDirectory() async => 'C:/runtime';
}

// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:lore_dub/src/data/repositories/install_repository.dart';
import 'package:lore_dub/src/data/repositories/settings_repository.dart';
import 'package:lore_dub/src/data/services/model_catalog.dart';
import 'package:lore_dub/src/data/services/settings_service.dart';
import 'package:lore_dub/src/domain/app_settings.dart';
import 'package:lore_dub/src/domain/compute_device.dart';
import 'package:lore_dub/src/domain/failure.dart';
import 'package:lore_dub/src/domain/model_package.dart';
import 'package:lore_dub/src/ui/shell/bloc/failure_cubit.dart';
import 'package:lore_dub/src/ui/shell/bloc/startup_cubit.dart';

import '../../../../support/fakes/fake_model_repository.dart';
import '../../../../support/fakes/fake_runtime_repository.dart';
import '../../../../support/fakes/fake_system_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSystemRepository machine;
  late FakeModelRepository disk;
  late InstallRepository installed;
  late FailureCubit failures;
  late StartupCubit startup;

  setUp(() {
    final settings = SettingsRepository(SettingsService())..seed(const AppSettings());
    machine = FakeSystemRepository()..availability = const ComputeAvailability(cudaDriver: true);
    disk = FakeModelRepository(
      states: [ModelInstallState(model: modelCatalog.first, installed: true)],
    );
    installed = InstallRepository(disk, FakeRuntimeRepository(installed: {'torch-cuda'}));
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
    disk.loadFails = true;

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

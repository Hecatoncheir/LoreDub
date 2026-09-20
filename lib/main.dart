// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'src/app.dart';
import 'src/ui/dashboard/cubits/state_journal.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // What every bloc and cubit did, in order, for reading a run against.
  Bloc.observer = StateJournal();
  runApp(const LoreDubBootstrap());
}

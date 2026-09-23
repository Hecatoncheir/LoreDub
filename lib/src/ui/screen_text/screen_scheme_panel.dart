// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../graph/bloc/pipeline_graph_bloc.dart';
import '../graph/bloc/screen_scheme_bloc.dart';
import '../graph/pipeline_panel.dart';

/// The scheme half of Экран: Эфир's canvas, toolbar and node panel, over
/// the Screen page's own scheme.
///
/// Everything in the canvas reads the scheme it draws as the
/// [PipelineGraphBloc] nearest to it, so this one is handed down as that --
/// the same nodes on the same machine, drawn from the screen's stages.
class ScreenSchemePanel extends StatelessWidget {
  const ScreenSchemePanel({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<PipelineGraphBloc>.value(
    value: context.read<ScreenSchemeBloc>(),
    child: const PipelinePanel(),
  );
}

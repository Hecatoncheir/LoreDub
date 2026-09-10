// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

import 'failure.dart';

Uri? parseModelProxyUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final normalized = trimmed.contains('://') ? trimmed : 'http://$trimmed';
  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      !const {'http', 'socks5'}.contains(uri.scheme.toLowerCase()) ||
      uri.host.isEmpty ||
      uri.hasQuery ||
      uri.fragment.isNotEmpty ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw const LoreDubFailure(FailureCode.proxyFormat);
  }
  try {
    if (uri.port < 1 || uri.port > 65535) {
      throw const LoreDubFailure(FailureCode.proxyPort);
    }
  } on FormatException {
    // Uri.port itself throws when the authority holds something that is not
    // a number at all.
    throw const LoreDubFailure(FailureCode.proxyPort);
  }
  return uri;
}

String modelProxyDirective(Uri proxy) {
  final host = proxy.host.contains(':') ? '[${proxy.host}]' : proxy.host;
  return 'PROXY $host:${proxy.port}';
}

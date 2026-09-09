// Copyright (c) 2026 LoreDub contributors.
// SPDX-License-Identifier: MIT

Uri? parseModelProxyUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final normalized = trimmed.contains('://') ? trimmed : 'http://$trimmed';
  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      uri.scheme.toLowerCase() != 'http' ||
      uri.host.isEmpty ||
      uri.hasQuery ||
      uri.fragment.isNotEmpty ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw const FormatException(
      'Укажите HTTP proxy в формате http://host:port',
    );
  }
  try {
    if (uri.port < 1 || uri.port > 65535) {
      throw const FormatException('Порт proxy должен быть от 1 до 65535');
    }
  } on FormatException {
    throw const FormatException('Укажите корректный порт proxy');
  }
  return uri;
}

String modelProxyDirective(Uri proxy) {
  final host = proxy.host.contains(':') ? '[${proxy.host}]' : proxy.host;
  return 'PROXY $host:${proxy.port}';
}

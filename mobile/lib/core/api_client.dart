import 'package:flutter/foundation.dart';

import '../services/api.dart';

String _defaultApiUrl() {
  if (kIsWeb) {
    final page = Uri.base;
    final scheme = page.scheme == 'https' ? 'https' : 'http';
    return '$scheme://${page.host}:5000';
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:5000';
  }
  return 'http://localhost:5000';
}

const configuredApiUrl = String.fromEnvironment('API_URL');

final api = Api(
  baseUrl: configuredApiUrl.isNotEmpty ? configuredApiUrl : _defaultApiUrl(),
);

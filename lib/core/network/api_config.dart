import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  static String get baseUrl => validate(
    const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: kDebugMode ? 'http://10.0.2.2:3000/v1' : '',
    ),
    debugBuild: kDebugMode,
  );
  static String validate(String value, {required bool debugBuild}) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path != '/v1') {
      throw const FormatException(
        'Configure API_BASE_URL with an HTTPS API ending in /v1.',
      );
    }
    final local = ['10.0.2.2', '127.0.0.1', 'localhost'].contains(uri.host);
    if (uri.scheme != 'https' &&
        !(debugBuild && local && uri.scheme == 'http')) {
      throw const FormatException('Remote and production APIs require HTTPS.');
    }
    return uri.toString();
  }
}

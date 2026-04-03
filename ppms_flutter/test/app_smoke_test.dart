import 'package:flutter_test/flutter_test.dart';
import 'package:ppms_flutter/core/config/app_config.dart';
import 'package:ppms_flutter/core/network/api_client.dart';

void main() {
  test('default app config points to local PPMS backend', () {
    expect(AppConfig.defaultBaseUrl, isNotEmpty);
    expect(
      ApiClient(baseUrl: AppConfig.defaultBaseUrl).baseUrl,
      startsWith('http'),
    );
  });
}

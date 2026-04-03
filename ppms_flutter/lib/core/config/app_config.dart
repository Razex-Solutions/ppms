class AppConfig {
  static const defaultBaseUrl = String.fromEnvironment(
    'PPMS_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8012',
  );
}

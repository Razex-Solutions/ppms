class AppEnvironment {
  const AppEnvironment._();

  static const appName = 'PPMS Tenant';
  static const apiBaseUrl = String.fromEnvironment(
    'PPMS_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8012',
  );
  static const enableE2E = bool.fromEnvironment(
    'PPMS_E2E_MODE',
    defaultValue: false,
  );
}

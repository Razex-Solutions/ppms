enum AppRole {
  masterAdmin('MasterAdmin'),
  headOffice('HeadOffice'),
  stationAdmin('StationAdmin'),
  manager('Manager'),
  accountant('Accountant'),
  operator('Operator');

  const AppRole(this.backendName);

  final String backendName;

  static AppRole fromBackend(String value) {
    return AppRole.values.firstWhere(
      (role) => role.backendName.toLowerCase() == value.toLowerCase(),
      orElse: () => AppRole.operator,
    );
  }
}

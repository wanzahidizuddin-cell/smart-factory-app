enum AppRole {
  systemAdmin('Admin'),
  shiftManager('QA Lead'),
  qualityInspector('QA'),
  floorWorker('Warehouse');

  const AppRole(this.databaseValue);

  final String databaseValue;

  static AppRole fromDatabase(String value) {
    return AppRole.values.firstWhere(
      (role) => role.databaseValue == value,
      orElse: () =>
          throw FormatException('Unsupported application role: $value'),
    );
  }
}

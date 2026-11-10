enum HardwareDeviceStatus { online, offline, warning }

class HardwareDevice {
  const HardwareDevice({
    required this.deviceId,
    required this.name,
    required this.type,
    required this.batteryLevel,
    required this.firmwareVersion,
    required this.status,
    required this.lastPing,
  });

  final String deviceId;
  final String name;
  final String type;
  final int batteryLevel;
  final String firmwareVersion;
  final HardwareDeviceStatus status;
  final DateTime lastPing;

  HardwareDevice copyWith({
    int? batteryLevel,
    HardwareDeviceStatus? status,
    DateTime? lastPing,
  }) =>
      HardwareDevice(
        deviceId: deviceId,
        name: name,
        type: type,
        batteryLevel: batteryLevel ?? this.batteryLevel,
        firmwareVersion: firmwareVersion,
        status: status ?? this.status,
        lastPing: lastPing ?? this.lastPing,
      );
}

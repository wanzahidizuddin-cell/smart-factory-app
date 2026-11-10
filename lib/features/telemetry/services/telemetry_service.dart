import 'dart:async';
import 'dart:math';

import 'package:smart_factory_qc/features/telemetry/models/hardware_device.dart';

class TelemetryService {
  TelemetryService({Random? random})
      : _random = random ?? Random(),
        _devices = [
          HardwareDevice(
            deviceId: 'SCN-01',
            name: 'Receiving scanner',
            type: 'Barcode scanner',
            batteryLevel: 82,
            firmwareVersion: '2.4.1',
            status: HardwareDeviceStatus.online,
            lastPing: DateTime.now(),
          ),
          HardwareDevice(
            deviceId: 'SNS-04',
            name: 'Press temperature sensor',
            type: 'Temperature sensor',
            batteryLevel: 54,
            firmwareVersion: '1.8.0',
            status: HardwareDeviceStatus.online,
            lastPing: DateTime.now(),
          ),
          HardwareDevice(
            deviceId: 'SCN-08',
            name: 'Line 2 scanner',
            type: 'Barcode scanner',
            batteryLevel: 12,
            firmwareVersion: '2.3.8',
            status: HardwareDeviceStatus.warning,
            lastPing: DateTime.now(),
          ),
          HardwareDevice(
            deviceId: 'SNS-11',
            name: 'Cold room sensor',
            type: 'Humidity sensor',
            batteryLevel: 67,
            firmwareVersion: '1.7.5',
            status: HardwareDeviceStatus.online,
            lastPing: DateTime.now(),
          ),
        ];

  final Random _random;
  final List<HardwareDevice> _devices;

  Stream<List<HardwareDevice>> watchDevices() async* {
    yield List.unmodifiable(_devices);
    yield* Stream.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  List<HardwareDevice> _tick() {
    final now = DateTime.now();
    for (var index = 0; index < _devices.length; index++) {
      final device = _devices[index];
      final losesConnection = index == 3 && _random.nextInt(8) == 0;
      final nextBattery = max(0, device.batteryLevel - _random.nextInt(3));
      final nextStatus = losesConnection
          ? HardwareDeviceStatus.offline
          : nextBattery < 15
              ? HardwareDeviceStatus.warning
              : HardwareDeviceStatus.online;
      _devices[index] = device.copyWith(
        batteryLevel: nextBattery,
        status: nextStatus,
        lastPing: losesConnection ? device.lastPing : now,
      );
    }
    return List.unmodifiable(_devices);
  }
}

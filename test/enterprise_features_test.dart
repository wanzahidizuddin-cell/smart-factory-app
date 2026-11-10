import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_factory_qc/core/widgets/role_gate.dart';
import 'package:smart_factory_qc/domain/models/app_role.dart';
import 'package:smart_factory_qc/features/shared/providers/app_state.dart';
import 'package:smart_factory_qc/features/telemetry/models/hardware_device.dart';
import 'package:smart_factory_qc/features/telemetry/services/telemetry_service.dart';

void main() {
  test('application roles map to the existing Supabase profile roles', () {
    expect(AppRole.fromDatabase('Admin'), AppRole.systemAdmin);
    expect(AppRole.fromDatabase('QA Lead'), AppRole.shiftManager);
    expect(AppRole.fromDatabase('QA'), AppRole.qualityInspector);
    expect(AppRole.fromDatabase('Warehouse'), AppRole.floorWorker);
    expect(() => AppRole.fromDatabase('unknown'), throwsFormatException);
  });

  testWidgets('RoleGate hides restricted content from floor workers',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRoleProvider.overrideWithValue(
            const AsyncData(AppRole.floorWorker),
          ),
        ],
        child: const MaterialApp(
          home: RoleGate(
            allowedRoles: [AppRole.systemAdmin],
            fallback: Text('Not authorized'),
            child: Text('Restricted'),
          ),
        ),
      ),
    );

    expect(find.text('Restricted'), findsNothing);
    expect(find.text('Not authorized'), findsOneWidget);
  });

  test('telemetry emits four devices and marks low battery as warning',
      () async {
    final devices = await TelemetryService().watchDevices().first;

    expect(devices, hasLength(4));
    final lowBatteryDevice = devices.firstWhere(
      (device) => device.batteryLevel < 15,
    );
    expect(lowBatteryDevice.status, HardwareDeviceStatus.warning);
  });
}

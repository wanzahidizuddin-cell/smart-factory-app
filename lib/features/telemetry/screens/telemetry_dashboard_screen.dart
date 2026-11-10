import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_factory_qc/core/theme/app_colors.dart';
import 'package:smart_factory_qc/features/telemetry/models/hardware_device.dart';
import 'package:smart_factory_qc/features/telemetry/services/telemetry_service.dart';

final telemetryServiceProvider = Provider<TelemetryService>(
  (ref) => TelemetryService(),
);

final hardwareDevicesProvider = StreamProvider<List<HardwareDevice>>((ref) {
  return ref.watch(telemetryServiceProvider).watchDevices();
});

class TelemetryDashboardScreen extends ConsumerWidget {
  const TelemetryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(hardwareDevicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Hardware telemetry')),
      body: devices.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('Unable to load device telemetry: $error'),
        ),
        data: (items) => LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 900
                ? 3
                : constraints.maxWidth > 580
                    ? 2
                    : 1;
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: columns == 1 ? 2.2 : 1.65,
              ),
              itemBuilder: (context, index) => _DeviceCard(items[index]),
            );
          },
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard(this.device);

  final HardwareDevice device;

  @override
  Widget build(BuildContext context) {
    final isOffline = device.status == HardwareDeviceStatus.offline;
    final isLowBattery = device.batteryLevel < 15;
    final warning = isOffline || isLowBattery;
    final color = isOffline
        ? AppColors.failed
        : warning
            ? AppColors.quarantined
            : AppColors.passed;
    final status = isOffline
        ? 'Offline'
        : warning
            ? 'Low battery'
            : 'Online';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    device.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Icon(
                  warning ? Icons.warning_amber_rounded : Icons.sensors_rounded,
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${device.type} · ${device.deviceId}'),
            const Spacer(),
            Text('Battery ${device.batteryLevel}%'),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: device.batteryLevel / 100,
              color: color,
              backgroundColor: AppColors.slate200,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(status, style: TextStyle(color: color)),
                const Spacer(),
                Text('FW ${device.firmwareVersion}'),
              ],
            ),
            Text(
              'Last ping ${TimeOfDay.fromDateTime(device.lastPing).format(context)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

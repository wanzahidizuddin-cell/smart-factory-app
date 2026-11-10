import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_factory_qc/data/repositories/dashboard_repository.dart';
import 'package:smart_factory_qc/data/repositories/qc_repository.dart';
import 'package:smart_factory_qc/domain/models/activity_entry.dart';
import 'package:smart_factory_qc/domain/models/inspection_record.dart';
import 'package:smart_factory_qc/features/home/home_screen.dart';
import 'package:smart_factory_qc/features/shared/providers/app_state.dart';

void main() {
  test('dashboard fetches update last sync after successful results', () async {
    final container = ProviderContainer(
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(_FakeDashboardRepository(
          stats: const DashboardStats(
            pendingDeliveries: 3,
            quarantinedDeliveries: 2,
            lowStockItems: 1,
          ),
          activity: const [],
        )),
      ],
    );
    addTearDown(container.dispose);

    await Future.wait([
      container.read(dashboardStatsProvider.future),
      container.read(recentActivityProvider.future),
    ]);

    expect(container.read(lastSyncProvider), isNotNull);
  });

  test('failed dashboard fetch does not update last sync', () async {
    final container = ProviderContainer(
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(
          _FakeDashboardRepository(error: StateError('offline')),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(dashboardStatsProvider.future),
      throwsStateError,
    );
    expect(container.read(lastSyncProvider), isNull);
  });

  testWidgets('home renders live counts and a formatted last-sync time',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardRepositoryProvider.overrideWithValue(
            _FakeDashboardRepository(
              stats: const DashboardStats(
                pendingDeliveries: 3,
                quarantinedDeliveries: 2,
                lowStockItems: 1,
              ),
              activity: const [],
            ),
          ),
          qcRepositoryProvider.overrideWithValue(_FakeQcRepository()),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('03'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    expect(find.textContaining('Last synced '), findsOneWidget);
  });
}

class _FakeQcRepository implements QcRepository {
  @override
  Future<List<InspectionRecord>> fetchInspections() async => const [];
}

class _FakeDashboardRepository extends DashboardRepository {
  _FakeDashboardRepository({
    this.stats = const DashboardStats(
      pendingDeliveries: 0,
      quarantinedDeliveries: 0,
      lowStockItems: 0,
    ),
    this.activity = const [],
    this.error,
  }) : super();

  final DashboardStats stats;
  final List<ActivityEntry> activity;
  final Object? error;

  @override
  Future<DashboardStats> fetchDashboardStats() async {
    if (error case final error?) throw error;
    return stats;
  }

  @override
  Future<List<ActivityEntry>> fetchRecentActivity() async {
    if (error case final error?) throw error;
    return activity;
  }
}

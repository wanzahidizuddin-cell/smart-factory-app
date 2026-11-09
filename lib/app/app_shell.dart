import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_factory_qc/core/widgets/responsive_content.dart';
import 'package:smart_factory_qc/features/deliveries/deliveries_screen.dart';
import 'package:smart_factory_qc/features/home/home_screen.dart';
import 'package:smart_factory_qc/features/inventory/inventory_screen.dart';
import 'package:smart_factory_qc/features/profile/profile_screen.dart';
import 'package:smart_factory_qc/features/shared/providers/app_state.dart';
import 'package:smart_factory_qc/features/shared/widgets/app_bottom_nav_bar.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(activeTabProvider);
    return Scaffold(
      body: ResponsiveContent(
        child: IndexedStack(
          index: selectedTab.index,
          children: [
            const HomeScreen(),
            const DeliveriesScreen(),
            const InventoryScreen(),
            ProfileScreen(onSignOut: onSignOut),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ResponsiveContent(
            child: AppBottomNavBar(
              selectedIndex: selectedTab.index,
              onTap: (index) => ref
                  .read(activeTabProvider.notifier)
                  .select(AppTab.values[index]),
            ),
          ),
        ],
      ),
    );
  }
}

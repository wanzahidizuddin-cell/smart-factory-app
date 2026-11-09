// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_factory_qc/main.dart';
import 'package:smart_factory_qc/features/shared/providers/app_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('shows the Smart Factory login page',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              const AuthState(AuthChangeEvent.initialSession, null),
            ),
          ),
        ],
        child: const SmartFactoryApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Smart Factory'), findsOneWidget);
    expect(find.text('QUALITY & INVENTORY'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}

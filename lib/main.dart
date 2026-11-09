import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_factory_qc/app/app_shell.dart';
import 'package:smart_factory_qc/core/theme/app_theme.dart';
import 'package:smart_factory_qc/features/auth/screens/login_page.dart';
import 'package:smart_factory_qc/features/shared/providers/app_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://tujxmnnlnhjrdvntbxpa.supabase.co',
    publishableKey: 'sb_publishable_SCMwaN9EKS9QhLGuoNRISA_-ARA6lvj',
  );
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ProviderScope(child: SmartFactoryApp()));
}

class SmartFactoryApp extends ConsumerWidget {
  const SmartFactoryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Smart Factory Quality & Inventory',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _AuthGate(),
      routes: {
        '/home': (context) => const _AuthenticatedAppShell(),
      },
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to check your sign-in status.'),
              TextButton(
                onPressed: () => ref.invalidate(authStateProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (state) => state.session == null
          ? LoginPage(
              onSignedIn: () {
                Navigator.of(context).pushReplacementNamed('/home');
              },
            )
          : const _AuthenticatedAppShell(),
    );
  }
}

class _AuthenticatedAppShell extends ConsumerWidget {
  const _AuthenticatedAppShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      onSignOut: () async {
        try {
          await ref.read(authRepositoryProvider).signOut();
          if (context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/',
              (route) => false,
            );
          }
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Unable to sign out. Please try again.'),
                ),
              );
          }
        }
      },
    );
  }
}

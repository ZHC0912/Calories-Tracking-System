import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/auth/login_screen.dart';
import 'screens/shell/root_shell.dart';
import 'state/auth_provider.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: CaloriesApp()));
}

class CaloriesApp extends StatelessWidget {
  const CaloriesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calories',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _AuthGate(),
    );
  }
}

/// Routes to the home screen when a valid token is loaded, otherwise to login.
/// Shows a brief splash while the persisted token is read at startup.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    if (auth.initializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return auth.isAuthenticated ? const RootShell() : const LoginScreen();
  }
}

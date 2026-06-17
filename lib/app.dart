import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/login_screen.dart';
import 'features/dispatcher/dispatcher_dashboard.dart';
import 'features/driver/driver_screen.dart';
import 'features/hospital/hospital_screen.dart';
import 'services/auth_service.dart';
import 'services/supabase_service.dart';
import 'widgets/app_logo.dart';

class EramsApp extends StatelessWidget {
  const EramsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ERAMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}

// ---------------------------------------------------------------
// Router — re-evaluates on every Supabase auth state change
// ---------------------------------------------------------------

final _router = GoRouter(
  initialLocation: '/login',
  refreshListenable: _AuthChangeNotifier(),
  redirect: (context, state) {
    final session = supabaseClient.auth.currentSession;
    final onLogin = state.matchedLocation == '/login';
    if (session == null && !onLogin) return '/login';
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path: '/dispatcher',
      builder: (_, __) => const DispatcherDashboard(),
    ),
    GoRoute(
      path: '/driver',
      builder: (_, __) => const DriverScreen(),
    ),
    GoRoute(
      path: '/hospital',
      builder: (_, __) => const HospitalScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (_, __) =>
          const _RolePlaceholderScreen(role: 'Administrator', icon: Icons.admin_panel_settings_outlined),
    ),
  ],
);

/// Notifies GoRouter whenever the Supabase auth state changes so that
/// the redirect guard re-evaluates on login and logout.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    supabaseClient.auth.onAuthStateChange.listen((_) => notifyListeners());
  }
}

// ---------------------------------------------------------------
// Placeholder screens — replaced phase by phase (Phase 2–6)
// ---------------------------------------------------------------

class _RolePlaceholderScreen extends ConsumerWidget {
  final String role;
  final IconData icon;
  const _RolePlaceholderScreen({required this.role, required this.icon});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const AppLogoHorizontal(),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: AppColors.primary.withValues(alpha: 0.2)),
            const SizedBox(height: 20),
            Text(role, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'This module is being built — check back soon.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign out'),
              onPressed: () async {
                await AuthService().signOut();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}

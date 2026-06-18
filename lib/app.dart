import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/admin/admin_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/dispatcher/dispatcher_dashboard.dart';
import 'features/driver/driver_screen.dart';
import 'features/hospital/hospital_screen.dart';
import 'services/supabase_service.dart';

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
      builder: (_, __) => const AdminScreen(),
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


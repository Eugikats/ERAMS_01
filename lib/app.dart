import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'features/admin/admin_screen.dart';
import 'features/auth/force_password_change_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/patient_register_screen.dart';
import 'features/dispatcher/dispatcher_dashboard.dart';
import 'features/driver/driver_screen.dart';
import 'features/hospital/hospital_screen.dart';
import 'features/patient/ambulance_picker_screen.dart';
import 'features/patient/new_request_form.dart';
import 'features/patient/patient_home_screen.dart';
import 'features/patient/trip_rating_screen.dart';
import 'features/patient/trip_tracking_screen.dart';
import 'services/supabase_service.dart';
import 'state/auth_provider.dart';

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

final _authChangeNotifier = _AuthChangeNotifier();

final _router = GoRouter(
  initialLocation: '/login',
  refreshListenable: _authChangeNotifier,
  redirect: (context, state) {
    final session = supabaseClient.auth.currentSession;
    final loc = state.matchedLocation;
    final isPublic = loc == '/login' || loc == '/patient/register';
    if (session == null && !isPublic) return '/login';

    final onForceChange = state.matchedLocation == '/force-password-change';

    // A Supabase recovery-email link landed here — force a password change
    // the same way an admin-issued temp password does, before going anywhere
    // else. `lastEvent` resets to something else as soon as the password is
    // actually updated, so this doesn't stick around afterward.
    final isPasswordRecovery =
        _authChangeNotifier.lastEvent == AuthChangeEvent.passwordRecovery;
    final mustChangePassword = session != null &&
        (supabaseClient.auth.currentUser?.userMetadata?['must_change_password'] ==
                true ||
            isPasswordRecovery);
    if (mustChangePassword && !onForceChange) return '/force-password-change';

    // Keep each account inside its own portal — without this, a driver,
    // dispatcher, hospital, or admin session could navigate straight to a
    // patient (or another role's) URL and hit confusing RLS failures
    // instead of a clean redirect, since screens don't self-check role.
    if (session != null && !isPublic && !onForceChange) {
      final role = ProviderScope.containerOf(context)
          .read(currentProfileProvider)
          .valueOrNull
          ?.role;
      if (role != null && !loc.startsWith(role.routePath)) {
        return role.routePath;
      }
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path: '/force-password-change',
      builder: (_, state) => ForcePasswordChangeScreen(
        redirectPath: state.extra as String?,
      ),
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
    GoRoute(
      path: '/patient',
      builder: (_, __) => const PatientHomeScreen(),
    ),
    GoRoute(
      path: '/patient/register',
      builder: (_, __) => const PatientRegisterScreen(),
    ),
    GoRoute(
      path: '/patient/request',
      builder: (_, __) => const NewRequestFormScreen(),
    ),
    GoRoute(
      path: '/patient/pick',
      builder: (_, state) {
        final data =
            (state.extra as Map<String, dynamic>?) ?? const {};
        return AmbulancePickerScreen(formData: data);
      },
    ),
    GoRoute(
      path: '/patient/tracking/:incidentId',
      builder: (_, state) => TripTrackingScreen(
        incidentId: state.pathParameters['incidentId']!,
      ),
    ),
    GoRoute(
      path: '/patient/rating',
      builder: (_, state) {
        final extra = (state.extra as Map<String, dynamic>?) ?? {};
        return TripRatingScreen(
          tripId: extra['tripId'] as String? ?? '',
          ambulancePlate: extra['ambulancePlate'] as String? ?? '',
          driverName: extra['driverName'] as String? ?? '',
        );
      },
    ),
  ],
);

/// Notifies GoRouter whenever the Supabase auth state changes so that
/// the redirect guard re-evaluates on login and logout. Also tracks the
/// most recent event type so the redirect guard can detect a password
/// recovery link landing (see `isPasswordRecovery` above).
class _AuthChangeNotifier extends ChangeNotifier {
  AuthChangeEvent? lastEvent;

  _AuthChangeNotifier() {
    supabaseClient.auth.onAuthStateChange.listen((data) {
      lastEvent = data.event;
      notifyListeners();
    });
  }
}


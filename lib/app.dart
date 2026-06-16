import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// TODO(phase-1): replace placeholder routes with real feature screens
// TODO(phase-1): add role-based redirect logic reading profiles.role from Supabase session

class EramsApp extends StatelessWidget {
  const EramsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ERAMS',
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const _PlaceholderScreen(),
    ),
  ],
);

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('ERAMS — Phase 0 scaffold. Supabase connected.'),
      ),
    );
  }
}

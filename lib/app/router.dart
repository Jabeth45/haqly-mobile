import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:haqly_mobile/app/scaffold_with_nav_bar.dart';
import 'package:haqly_mobile/domain/models/auth_state.dart';
import 'package:haqly_mobile/features/check/presentation/check_screen.dart';
import 'package:haqly_mobile/features/expense/presentation/add_screen.dart';
import 'package:haqly_mobile/features/history/presentation/history_screen.dart';
import 'package:haqly_mobile/features/home/presentation/home_screen.dart';
import 'package:haqly_mobile/features/ledger/presentation/ledger_screen.dart';
import 'package:haqly_mobile/features/onboarding/presentation/welcome_screen.dart';
import 'package:haqly_mobile/features/settings/presentation/settings_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Builds the app's declarative [GoRouter] configuration.
/// Uses [StatefulShellRoute.indexedStack] to maintain widget state across the 5 bottom tabs.
/// Implements auth redirect guards per docs/ARCHITECTURE.md Section 7 and FR-A6.
GoRouter createAppRouter({
  String initialLocation = '/home',
  List<NavigatorObserver>? observers,
  AuthState Function()? authStateProvider,
  Listenable? refreshListenable,
}) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: initialLocation,
    observers: observers,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      if (authStateProvider == null) {
        return null;
      }

      final auth = authStateProvider();

      // 1. While initial session is loading, never flash auth screens (FR-A6)
      if (auth.isLoading) {
        return null;
      }

      final isAtWelcome = state.matchedLocation == '/welcome';

      // 2. Active session (guest sentinel or authenticated account)
      if (auth.hasSession) {
        if (isAtWelcome) {
          return '/home';
        }
        return null;
      }

      // 3. Unauthenticated fresh install: route to welcome
      if (!isAtWelcome) {
        return '/welcome';
      }

      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          // Tab 0: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // Tab 1: Add (Expense/Income)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/add',
                builder: (context, state) => const AddScreen(),
              ),
            ],
          ),
          // Tab 2: Value Check
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/check',
                builder: (context, state) => const CheckScreen(),
              ),
            ],
          ),
          // Tab 3: Ledger
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ledger',
                builder: (context, state) => const LedgerScreen(),
              ),
            ],
          ),
          // Tab 4: History
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
        ],
      ),
      // Top-level modal/sub-routes outside bottom bar
      GoRoute(
        path: '/welcome',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}

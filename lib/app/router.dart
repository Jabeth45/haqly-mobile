import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:haqly_mobile/app/scaffold_with_nav_bar.dart';
import 'package:haqly_mobile/features/check/presentation/check_screen.dart';
import 'package:haqly_mobile/features/expense/presentation/add_screen.dart';
import 'package:haqly_mobile/features/history/presentation/history_screen.dart';
import 'package:haqly_mobile/features/home/presentation/home_screen.dart';
import 'package:haqly_mobile/features/ledger/presentation/ledger_screen.dart';
import 'package:haqly_mobile/features/settings/presentation/settings_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Builds the app's declarative [GoRouter] configuration.
/// Uses [StatefulShellRoute.indexedStack] to maintain widget state across the 5 bottom tabs.
/// Follows docs/ARCHITECTURE.md Section 1 and docs/DESIGN.md Section 3 (ADR-007).
GoRouter createAppRouter({
  String initialLocation = '/home',
  List<NavigatorObserver>? observers,
}) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: initialLocation,
    observers: observers,
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
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}

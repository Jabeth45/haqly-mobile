import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:haqly_mobile/core/l10n/generated/app_localizations.dart';

/// App scaffold displaying a persistent Material 3 bottom navigation bar
/// wrapping a [StatefulNavigationShell] to preserve tab state.
/// Follows docs/DESIGN.md Section 3 (ADR-007) and docs/ARCHITECTURE.md.
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n?.tabHome ?? 'Home',
          ),
          NavigationDestination(
            icon: const Icon(Icons.add_circle_outline),
            selectedIcon: const Icon(Icons.add_circle),
            label: l10n?.tabAdd ?? 'Add',
          ),
          NavigationDestination(
            icon: const Icon(Icons.fact_check_outlined),
            selectedIcon: const Icon(Icons.fact_check),
            label: l10n?.tabCheck ?? 'Check',
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet),
            label: l10n?.tabLedger ?? 'Ledger',
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: l10n?.tabHistory ?? 'History',
          ),
        ],
      ),
    );
  }
}

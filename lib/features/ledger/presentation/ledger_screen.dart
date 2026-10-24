import 'package:flutter/material.dart';
import 'package:haqly_mobile/core/theme/tokens.dart';

/// Placeholder screen for Ledger tab.
class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('Ledger')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet, size: 48, color: tokens.accent),
            const SizedBox(height: 12),
            Text(
              'Ledger Screen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:haqly_mobile/core/theme/tokens.dart';

/// Placeholder screen for Value Check tab.
class CheckScreen extends StatelessWidget {
  const CheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('Value Check')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fact_check, size: 48, color: tokens.accent),
            const SizedBox(height: 12),
            Text('Check Screen', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

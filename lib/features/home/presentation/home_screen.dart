import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:haqly_mobile/core/theme/tokens.dart';

/// Placeholder screen for Home tab.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const CircleAvatar(
              radius: 16,
              child: Icon(Icons.person, size: 18),
            ),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home, size: 48, color: tokens.accent),
            const SizedBox(height: 12),
            Text('Home Screen', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:haqly_mobile/core/theme/tokens.dart';

/// Placeholder screen for Add (Expense/Income) tab.
class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final TextEditingController _testInputController = TextEditingController();

  @override
  void dispose() {
    _testInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('Add Transaction')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle, size: 48, color: tokens.accent),
            const SizedBox(height: 12),
            Text('Add Screen', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              key: const Key('add_screen_test_input'),
              controller: _testInputController,
              decoration: const InputDecoration(
                hintText: 'Type to test state preservation',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

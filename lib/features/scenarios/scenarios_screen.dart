import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class ScenariosScreen extends StatelessWidget {
  const ScenariosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scenarios'),
        actions: [
          IconButton(
            tooltip: 'New scenario',
            icon: const Icon(Icons.add),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Event history (30 days)',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Card(
              color: AppColors.surface,
              child: ListTile(
                leading: Icon(Icons.history, color: Colors.grey),
                title: Text('No events recorded yet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

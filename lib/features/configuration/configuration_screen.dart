import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/module.dart';
import 'module_status_dot.dart';

class ConfigurationScreen extends ConsumerWidget {
  const ConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(moduleRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration'),
        actions: [
          IconButton(
            tooltip: 'Add by IP address',
            icon: const Icon(Icons.add),
            onPressed: () => _showAddByIp(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Device List', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final module in modules)
            Dismissible(
              key: Key(module.id),
              onDismissed: (d) {},
              child: Card(
                color: AppColors.surface,
                child: ListTile(
                  leading: ModuleStatusDot(
                    online: module.status == ModuleStatus.online,
                  ),
                  title: Text(module.name),
                  subtitle: Text('${module.type.name} · ${module.ip}'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                ),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.search),
            label: const Text('Discover modules'),
            onPressed: () {
              // Wire to the self-discovery broadcast listener (Stage 4).
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Discovery not yet wired to transport')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddByIp(BuildContext context) {
    final controller = TextEditingController(text: '192.168.1.');
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add module by IP address'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'IP'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

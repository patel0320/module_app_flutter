import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import 'home_providers.dart';
import 'home_quick_action_card.dart';
import 'temperature_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineCount = ref.watch(homeOfflineAlertProvider);
    final scenarios = ref.watch(homeQuickActionsProvider);
    final temperatureModules = ref.watch(homeTemperatureProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (offlineCount > 0)
            OfflineAlertBanner(count: offlineCount)
          else
            const SizedBox(height: 8),
          const SizedBox(height: 16),
          Text('Quick access', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final scenario in scenarios)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: HomeQuickActionCard(scenario: scenario),
            ),
          const SizedBox(height: 16),
          Text('Temperature', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final entry in temperatureModules)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TemperatureCard(module: entry.$1, temperature: entry.$2),
            ),
        ],
      ),
    );
  }
}

class OfflineAlertBanner extends StatelessWidget {
  final int count;
  const OfflineAlertBanner({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.offline,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed('/system-status'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  count == 1
                      ? 'A module is offline'
                      : '$count modules are offline',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

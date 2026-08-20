// lib/screens/system_status_screen.dart
//
// "System Status" page reached by tapping the offline/temperature alert
// banners on Home (brief section I, point 2: "a log of error messages").
import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class SystemStatusScreen extends StatelessWidget {
  const SystemStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = mockStatusLog()..sort((a, b) => b.time.compareTo(a.time));
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(title: const Text('System Status')),
      body: entries.isEmpty
          ? const EmptyState(icon: Icons.verified_outlined, message: 'No issues reported.')
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.outerPadding),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.betweenCards),
              itemBuilder: (context, index) => _StatusTile(entry: entries[index], onSurface: onSurface),
            ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.entry, required this.onSurface});

  final StatusLogEntry entry;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    final Color accent = entry.isAlert ? AppColors.offlineAlert : AppColors.online;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              entry.isAlert ? Icons.error_outline : Icons.check_circle_outline,
              color: accent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.moduleName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(entry.message, style: TextStyle(color: onSurface.withOpacity(0.7))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatLogTimestamp(entry.time),
              style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

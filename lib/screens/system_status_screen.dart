// lib/screens/system_status_screen.dart
//
// "Notification History" page reached by tapping the offline/temperature alert
// banners on Home (brief section I, point 2: "a log of error messages"). Rows
// come from the app-wide status log, which records real OFFLINE / RESTORED /
// FIRMWARE events as they happen (see StatusLogStore + NotificationMonitor).
import 'package:flutter/material.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

import '../models/models.dart';
import '../services/status_log_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class SystemStatusScreen extends StatefulWidget {
  const SystemStatusScreen({super.key});

  @override
  State<SystemStatusScreen> createState() => _SystemStatusScreenState();
}

class _SystemStatusScreenState extends State<SystemStatusScreen> {
  final StatusLogStore _store = StatusLogStore.shared;

  @override
  void initState() {
    super.initState();
    _store.init();
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.systemStatusTitle)),
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final entries = _store.entries;
          if (entries.isEmpty) {
            return EmptyState(
                icon: Icons.verified_outlined,
                message: l10n.systemStatusNoIssues);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.outerPadding),
            itemCount: entries.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.betweenCards),
            itemBuilder: (context, index) =>
                _StatusTile(entry: entries[index], onSurface: onSurface),
          );
        },
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
    final Color accent =
        entry.isAlert ? AppColors.offlineAlert : AppColors.online;
    final l10n = AppLocalizations.of(context);
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
                  Text(entry.deviceName,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${entry.type.label(l10n)} \u00b7 ${entry.message}',
                      style:
                          TextStyle(color: onSurface.withValues(alpha: 0.7))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatLogTimestamp(entry.time, l10n),
              style: TextStyle(
                  fontSize: 12, color: onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

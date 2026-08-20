// lib/screens/event_history_screen.dart
//
// Brief section 2.4 "Event Log (History)": a detailed, date-grouped log of
// every ON/OFF action, retained (in the real product) for 30 days.
import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class EventHistoryScreen extends StatelessWidget {
  const EventHistoryScreen({super.key});

  String _dateHeader(DateTime time) {
    final now = DateTime.now();
    final int diff = DateTime(now.year, now.month, now.day).difference(DateTime(time.year, time.month, time.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    final List<EventLogEntry> entries = mockEventLog()..sort((a, b) => b.time.compareTo(a.time));
    final Color onSurface = Theme.of(context).colorScheme.onSurface;

    // Pre-compute a flat row list (date header markers + entries) once, so
    // headers only ever appear when the date actually changes.
    final List<Object> rows = [];
    String? currentHeader;
    for (final entry in entries) {
      final header = _dateHeader(entry.time);
      if (header != currentHeader) {
        rows.add(header);
        currentHeader = header;
      }
      rows.add(entry);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Event History')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: onSurface.withOpacity(0.05),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.outerPadding, vertical: 10),
            child: Text(
              'Showing the last 30 days of ON/OFF activity',
              style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.6)),
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? const EmptyState(icon: Icons.history, message: 'No events recorded yet.')
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.outerPadding),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      if (row is String) {
                        return Padding(
                          padding: EdgeInsets.only(top: index == 0 ? 0 : 12, bottom: 8),
                          child: Text(
                            row,
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: onSurface.withOpacity(0.5)),
                          ),
                        );
                      }
                      final entry = row as EventLogEntry;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.betweenCards),
                        child: Card(
                          child: ListTile(
                            leading: const Icon(Icons.bolt_outlined),
                            title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(entry.subtitle),
                            trailing: Text(
                              formatLogTimestamp(entry.time),
                              style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.5)),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

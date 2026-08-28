// lib/screens/event_history_screen.dart
//
// Brief section 2.4 "Event Log (History)": a detailed, date-grouped log of
// every ON/OFF action, retained (in the real product) for 30 days.
import 'package:flutter/material.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

import '../models/models.dart';
import '../services/event_log_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class EventHistoryScreen extends StatefulWidget {
  const EventHistoryScreen({super.key});

  @override
  State<EventHistoryScreen> createState() => _EventHistoryScreenState();
}

class _EventHistoryScreenState extends State<EventHistoryScreen> {
  final EventLogStore _store = EventLogStore.shared;

  @override
  void initState() {
    super.initState();
    _store.init();
  }

  String _dateHeader(DateTime time) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final int diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(time.year, time.month, time.day))
        .inDays;
    if (diff == 0) return l10n.eventHistoryToday;
    if (diff == 1) return l10n.eventHistoryYesterday;
    return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year}';
  }

  String _timeHHmmss(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }

  // Pre-computes a flat row list (date header markers + entries) so headers
  // only ever appear when the date actually changes.
  List<Object> _buildRows(List<EventLogEntry> entries) {
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
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final Color onSurface = Theme.of(context).colorScheme.onSurface;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.eventHistoryTitle)),
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final entries = _store.entries;
          final rows = _buildRows(entries);

          return Column(
            children: [
              Container(
                width: double.infinity,
                color: onSurface.withOpacity(0.05),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.outerPadding, vertical: 10),
                child: Text(
                  l10n.eventHistoryShowing,
                  style: TextStyle(
                      fontSize: 12, color: onSurface.withOpacity(0.6)),
                ),
              ),
              Expanded(
                child: rows.isEmpty
                    ? EmptyState(
                        icon: Icons.history, message: l10n.eventHistoryEmpty)
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.outerPadding),
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          if (row is String) {
                            return Padding(
                              padding: EdgeInsets.only(
                                  top: index == 0 ? 0 : 12, bottom: 8),
                              child: Text(
                                row,
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: onSurface.withOpacity(0.5)),
                              ),
                            );
                          }
                          final entry = row as EventLogEntry;
                          return Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppSpacing.betweenCards),
                            child: Card(
                              child: ListTile(
                                leading: const Icon(Icons.bolt_outlined),
                                title: Text(entry.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(entry.subtitle),
                                trailing: Text(
                                  _timeHHmmss(entry.time),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: onSurface.withOpacity(0.5)),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

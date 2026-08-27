// lib/screens/automations_screen.dart
//
// Brief section 2.4 "Smart Automations (Based on IF... THEN... rules)":
// list of automatic rules triggered by time of day or another device's
// state, with an enable/disable switch for each.
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../services/event_log_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'automation_editor_screen.dart';

class AutomationsScreen extends StatefulWidget {
  const AutomationsScreen({super.key});

  @override
  State<AutomationsScreen> createState() => _AutomationsScreenState();
}

class _AutomationsScreenState extends State<AutomationsScreen> {
  final List<Automation> _automations = mockAutomations();

  Future<void> _create() async {
    final Automation? created = await Navigator.of(context).push<Automation>(
      MaterialPageRoute(builder: (_) => const AutomationEditorScreen()),
    );
    if (created != null) setState(() => _automations.add(created));
  }

  Future<void> _edit(Automation automation) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => AutomationEditorScreen(automation: automation)),
    );
    setState(() {});
  }

  Future<void> _delete(Automation automation) async {
    final confirmed = await showConfirmDialog(
      context,
      title: AppLocalizations.of(context).automationsDeleteDialog,
      message:
          AppLocalizations.of(context).automationsDeleteMsg(automation.name),
      confirmLabel: AppLocalizations.of(context).delete,
    );
    if (confirmed) setState(() => _automations.remove(automation));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.automationsTitle)),
      body: _automations.isEmpty
          ? EmptyState(
              icon: Icons.rule_outlined, message: l10n.automationsEmpty)
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.outerPadding),
              itemCount: _automations.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.betweenCards),
              itemBuilder: (context, index) {
                final automation = _automations[index];
                return _AutomationCard(
                  automation: automation,
                  onTap: () => _edit(automation),
                  onDelete: () => _delete(automation),
                  onEnabledChanged: (v) {
                    setState(() => automation.enabled = v);
                    if (v) {
                      EventLogStore.shared
                          .recordAutomation(automationName: automation.name);
                    }
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: Text(l10n.automationsNew, style: AppTheme.fabLabelStyle),
      ),
    );
  }
}

class _AutomationCard extends StatelessWidget {
  const _AutomationCard({
    required this.automation,
    required this.onTap,
    required this.onDelete,
    required this.onEnabledChanged,
  });

  final Automation automation;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<bool> onEnabledChanged;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final l10n = AppLocalizations.of(context);
    final bool isTime = automation.triggerType == AutomationTriggerType.time;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconAvatar(
                  icon: isTime ? Icons.schedule : Icons.sensors,
                  filled: automation.enabled),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(automation.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(automation.triggerSummary,
                        style: TextStyle(
                            fontSize: 13, color: onSurface.withOpacity(0.6))),
                    const SizedBox(height: 2),
                    Text(l10n.homeActionsCount(automation.actions.length),
                        style: TextStyle(
                            fontSize: 12, color: onSurface.withOpacity(0.45))),
                  ],
                ),
              ),
              Switch(value: automation.enabled, onChanged: onEnabledChanged),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// lib/screens/automation_editor_screen.dart
//
// Brief section 2.4 "Smart Automations": build an IF...THEN... rule -
// trigger by time of day or by another device's state - with one or more
// resulting actions.
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/action_picker.dart';
import '../widgets/common_widgets.dart';

class AutomationEditorScreen extends StatefulWidget {
  const AutomationEditorScreen({super.key, this.automation});

  /// Null when creating a brand new automation.
  final Automation? automation;

  @override
  State<AutomationEditorScreen> createState() => _AutomationEditorScreenState();
}

class _AutomationEditorScreenState extends State<AutomationEditorScreen> {
  late final bool _isNew = widget.automation == null;
  late final TextEditingController _nameController = TextEditingController(text: widget.automation?.name ?? '');
  late AutomationTriggerType _triggerType = widget.automation?.triggerType ?? AutomationTriggerType.time;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  bool _deviceTurnsOn = true;
  late String _deviceChannelName = _channelNames.isNotEmpty ? _channelNames.first : '';
  late final List<ScenarioAction> _actions = List.of(widget.automation?.actions ?? const []);

  final List<DeviceModule> _modules = mockModules();

  List<String> get _channelNames => [
        for (final m in mockModules())
          for (final c in m.channels) c.name,
      ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _addAction() async {
    final action = await showAddActionSheet(context, _modules);
    if (action != null) setState(() => _actions.add(action));
  }

  String get _triggerSummary {
    final l10n = AppLocalizations.of(context);
    if (_triggerType == AutomationTriggerType.time) {
      final hh = _time.hour.toString().padLeft(2, '0');
      final mm = _time.minute.toString().padLeft(2, '0');
      return l10n.automationEveryDayAt('$hh:$mm');
    }
    return l10n.automationWhenTurns(
        _deviceChannelName, _deviceTurnsOn ? l10n.on : l10n.off);
  }

  void _save() {
    final String name = _nameController.text.trim().isEmpty ? AppLocalizations.of(context).automationUntitled : _nameController.text.trim();
    if (widget.automation != null) {
      final a = widget.automation!;
      a.name = name;
      a.triggerType = _triggerType;
      a.triggerSummary = _triggerSummary;
      a.actions
        ..clear()
        ..addAll(_actions);
      Navigator.of(context).pop(a);
    } else {
      final a = Automation(
        id: 'automation-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        triggerType: _triggerType,
        triggerSummary: _triggerSummary,
        actions: _actions,
      );
      Navigator.of(context).pop(a);
    }
  }

  @override
  Widget build(BuildContext context) {
    final channelNames = _channelNames;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? l10n.automationNewTitle : l10n.automationEditTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.outerPadding),
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: l10n.automationNameLabel, prefixIcon: const Icon(Icons.label_outline)),
          ),
          const SizedBox(height: 20),
          SectionHeader(l10n.automationSectionIf),
          SegmentedButton<AutomationTriggerType>(
            segments: [
              ButtonSegment(value: AutomationTriggerType.time, label: Text(l10n.automationTriggerTime), icon: const Icon(Icons.schedule)),
              ButtonSegment(value: AutomationTriggerType.deviceState, label: Text(l10n.automationTriggerDevice), icon: const Icon(Icons.sensors)),
            ],
            selected: {_triggerType},
            onSelectionChanged: (s) => setState(() => _triggerType = s.first),
          ),
          const SizedBox(height: 16),
          if (_triggerType == AutomationTriggerType.time)
            Card(
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(l10n.automationTriggerTimeLabel),
                subtitle: Text(_time.format(context)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickTime,
              ),
            )
          else ...[
            DropdownButtonFormField<String>(
              value: channelNames.contains(_deviceChannelName) ? _deviceChannelName : null,
              decoration: InputDecoration(labelText: l10n.automationWhenOutputLabel, prefixIcon: const Icon(Icons.sensors)),
              items: [for (final c in channelNames) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _deviceChannelName = v ?? _deviceChannelName),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(l10n.automationTurnsOn)),
                ButtonSegment(value: false, label: Text(l10n.automationTurnsOff)),
              ],
              selected: {_deviceTurnsOn},
              onSelectionChanged: (s) => setState(() => _deviceTurnsOn = s.first),
            ),
          ],
          const SizedBox(height: 24),
          SectionHeader(
            l10n.automationSectionThen,
            trailing: TextButton.icon(onPressed: _addAction, icon: const Icon(Icons.add), label: Text(l10n.add)),
          ),
          if (_actions.isEmpty)
            EmptyState(icon: Icons.flash_on_outlined, message: l10n.automationActionsEmpty)
          else
            for (int i = 0; i < _actions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.betweenCards),
                child: Card(
                  child: ListTile(
                    leading: IconAvatar(icon: _actions[i].icon),
                    title: Text(_actions[i].channelName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(l10n.scenarioActionModuleSummary(_actions[i].moduleName, _actions[i].summary)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() => _actions.removeAt(i)),
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: Text(l10n.automationSave)),
        ],
      ),
    );
  }
}

// lib/screens/scenario_editor_screen.dart
//
// Brief section 2.4 "Automations and Scenarios": create or edit a
// tap-to-run scenario (multiple ON/OFF or brightness actions) or a
// dedicated "Manual dimming Slider" scenario controlling a single dimmer
// output.
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/action_picker.dart';
import '../widgets/common_widgets.dart';

class ScenarioEditorScreen extends StatefulWidget {
  const ScenarioEditorScreen({super.key, this.scenario});

  /// Null when creating a brand new scenario.
  final Scenario? scenario;

  @override
  State<ScenarioEditorScreen> createState() => _ScenarioEditorScreenState();
}

class _ScenarioEditorScreenState extends State<ScenarioEditorScreen> {
  late final bool _isNew = widget.scenario == null;
  late final TextEditingController _nameController =
      TextEditingController(text: widget.scenario?.name ?? '');
  late IconData _icon = widget.scenario?.icon ?? Icons.auto_awesome_outlined;
  late String _roomName = widget.scenario?.roomName ?? 'No room';
  late bool _showInHome = widget.scenario?.showInHome ?? false;
  late ScenarioType _type = widget.scenario?.type ?? ScenarioType.tapToRun;
  late final List<ScenarioAction> _actions =
      List.of(widget.scenario?.actions ?? const []);
  late String _sliderTargetName = widget.scenario?.sliderTargetName ?? '';
  late int _sliderValue = widget.scenario?.sliderValue ?? 50;

  final List<DeviceModule> _modules = mockModules();
  final List<Room> _rooms = mockRooms();

  List<String> get _dimmerTargets => [
        for (final m in _modules.where((m) =>
            m.type == ModuleType.dimmerDc || m.type == ModuleType.dimmerAc))
          for (final c in m.channels) '${c.name} - ${m.name}',
      ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final IconData? picked = await showModalBottomSheet<IconData>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final icon in kChannelIconChoices)
                InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => Navigator.pop(context, icon),
                  child: CircleAvatar(radius: 26, child: Icon(icon)),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _icon = picked);
  }

  Future<void> _addAction() async {
    final action = await showAddActionSheet(context, _modules);
    if (action != null) setState(() => _actions.add(action));
  }

  Future<void> _editAction(int index) async {
    final action =
        await showAddActionSheet(context, _modules, initial: _actions[index]);
    if (action != null) setState(() => _actions[index] = action);
  }

  void _save() {
    final String name = _nameController.text.trim().isEmpty
        ? AppLocalizations.of(context).scenarioUntitled
        : _nameController.text.trim();
    if (widget.scenario != null) {
      final s = widget.scenario!;
      s.name = name;
      s.icon = _icon;
      s.roomName = _roomName;
      s.showInHome = _showInHome;
      s.type = _type;
      s.actions
        ..clear()
        ..addAll(_actions);
      s.sliderTargetName = _sliderTargetName;
      s.sliderValue = _sliderValue;
      Navigator.of(context).pop(s);
    } else {
      final s = Scenario(
        id: 'scenario-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        icon: _icon,
        type: _type,
        roomName: _roomName,
        showInHome: _showInHome,
        actions: _actions,
        sliderTargetName: _sliderTargetName,
        sliderValue: _sliderValue,
      );
      Navigator.of(context).pop(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final l10n = AppLocalizations.of(context);
    final roomOptions = ['No room', ..._rooms.map((r) => r.name)];
    final dimmerTargets = _dimmerTargets;

    return Scaffold(
      appBar: AppBar(
          title: Text(_isNew ? l10n.scenarioNewTitle : l10n.scenarioEditTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.outerPadding),
        children: [
          Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(48),
              onTap: _pickIcon,
              child: Stack(
                children: [
                  IconAvatar(icon: _icon, size: 84, filled: true),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          Theme.of(context).scaffoldBackgroundColor,
                      child: Icon(Icons.edit, size: 14, color: onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
                labelText: l10n.scenarioNameLabel,
                prefixIcon: const Icon(Icons.label_outline)),
          ),
          const SizedBox(height: 20),
          SectionHeader(l10n.scenarioTypeSection),
          SegmentedButton<ScenarioType>(
            segments: [
              ButtonSegment(
                  value: ScenarioType.tapToRun,
                  label: Text(l10n.scenarioTypeTapToRun),
                  icon: const Icon(Icons.touch_app_outlined)),
              ButtonSegment(
                  value: ScenarioType.manualSlider,
                  label: Text(l10n.scenarioTypeManualSlider),
                  icon: const Icon(Icons.tune)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value:
                roomOptions.contains(_roomName) ? _roomName : roomOptions.first,
            decoration: InputDecoration(
                labelText: l10n.scenarioRoomLabel,
                prefixIcon: const Icon(Icons.meeting_room_outlined)),
            items: [
              for (final room in roomOptions)
                DropdownMenuItem(value: room, child: Text(room))
            ],
            onChanged: (value) =>
                setState(() => _roomName = value ?? _roomName),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.showOnHome),
            subtitle: Text(l10n.scenarioPinHint),
            value: _showInHome,
            onChanged: (v) => setState(() => _showInHome = v),
          ),
          const SizedBox(height: 12),
          if (_type == ScenarioType.tapToRun) ...[
            SectionHeader(
              l10n.scenarioActionsSection,
              trailing: TextButton.icon(
                  onPressed: _addAction,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.add)),
            ),
            if (_actions.isEmpty)
              EmptyState(
                  icon: Icons.flash_on_outlined,
                  message: l10n.scenarioActionsEmpty)
            else
              for (int i = 0; i < _actions.length; i++)
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: AppSpacing.betweenCards),
                  child: Card(
                    child: ListTile(
                      leading: IconAvatar(icon: _actions[i].icon),
                      title: Text(_actions[i].channelName,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(l10n.scenarioActionModuleSummary(
                          _actions[i].moduleName, _actions[i].summary)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: l10n.scenarioEditActionTooltip,
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editAction(i),
                          ),
                          IconButton(
                            tooltip: l10n.scenarioDeleteActionTooltip,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                setState(() => _actions.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ] else ...[
            SectionHeader(l10n.scenarioSliderTargetSection),
            DropdownButtonFormField<String>(
              value: dimmerTargets.contains(_sliderTargetName)
                  ? _sliderTargetName
                  : null,
              decoration: InputDecoration(
                  labelText: l10n.scenarioDimmerOutputLabel,
                  prefixIcon: const Icon(Icons.lightbulb_outline)),
              items: [
                for (final t in dimmerTargets)
                  DropdownMenuItem(value: t, child: Text(t))
              ],
              onChanged: (value) => setState(
                  () => _sliderTargetName = value ?? _sliderTargetName),
            ),
            const SizedBox(height: 16),
            Text(l10n.scenarioDefaultBrightness(_sliderValue),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Slider(
              value: _sliderValue.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              label: '$_sliderValue%',
              onChanged: (v) => setState(() => _sliderValue = v.round()),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: Text(l10n.scenarioSave)),
        ],
      ),
    );
  }
}

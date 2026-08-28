// lib/screens/input_editor_screen.dart
//
// Brief section 2.2 "Physical Switch Input Control": configure how a
// physical switch wired to a module behaves - momentary, toggle, or
// associated to a specific output / scenario.
import 'package:flutter/material.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class InputEditorScreen extends StatefulWidget {
  const InputEditorScreen(
      {super.key, required this.input, required this.module});

  final PhysicalInput input;
  final DeviceModule module;

  @override
  State<InputEditorScreen> createState() => _InputEditorScreenState();
}

class _InputEditorScreenState extends State<InputEditorScreen> {
  late InputMode _mode = widget.input.mode;
  late final List<String> _targets = [
    for (final c in widget.module.channels) c.name,
    for (final s in mockScenarios()) '${s.name} (scenario)',
  ];
  late String _boundTo = _targets.contains(widget.input.boundTo)
      ? widget.input.boundTo
      : (_targets.isNotEmpty ? _targets.first : 'Not assigned');

  void _save() {
    widget.input.mode = _mode;
    widget.input.boundTo = _boundTo;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.input.label)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.outerPadding),
        children: [
          Text(
            l10n.inputEditorOnModule(widget.module.name),
            style: TextStyle(color: onSurface.withOpacity(0.55)),
          ),
          const SizedBox(height: 20),
          SectionHeader(l10n.inputEditorBehavior),
          Card(
            child: Column(
              children: [
                for (int i = 0; i < InputMode.values.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  RadioListTile<InputMode>(
                    value: InputMode.values[i],
                    groupValue: _mode,
                    title: Text(InputMode.values[i].label,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(InputMode.values[i].description),
                    onChanged: (value) =>
                        setState(() => _mode = value ?? _mode),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          SectionHeader(l10n.inputEditorBoundTarget),
          DropdownButtonFormField<String>(
            value: _targets.contains(_boundTo) ? _boundTo : null,
            decoration: InputDecoration(
                labelText: l10n.inputEditorOutputScenarioLabel,
                prefixIcon: const Icon(Icons.link)),
            items: [
              for (final target in _targets)
                DropdownMenuItem(value: target, child: Text(target)),
            ],
            onChanged: (value) => setState(() => _boundTo = value ?? _boundTo),
          ),
          const SizedBox(height: 32),
          FilledButton(onPressed: _save, child: Text(l10n.save)),
        ],
      ),
    );
  }
}

// lib/screens/relay_control_screen.dart
//
// Brief section 2.3 "Standard Relay Modules": ON/OFF control for every
// output, plus (brief section 2.2) naming/icon customization and physical
// switch input configuration.
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'channel_editor_screen.dart';
import 'input_editor_screen.dart';

class RelayControlScreen extends StatefulWidget {
  const RelayControlScreen({super.key, required this.module});

  final DeviceModule module;

  @override
  State<RelayControlScreen> createState() => _RelayControlScreenState();
}

class _RelayControlScreenState extends State<RelayControlScreen> {
  Future<void> _editChannel(ChannelOutput channel) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChannelEditorScreen(channel: channel, moduleName: widget.module.name)),
    );
    setState(() {});
  }

  Future<void> _editInput(PhysicalInput input) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InputEditorScreen(input: input, module: widget.module)),
    );
    setState(() {});
  }

  Future<void> _renameModule() async {
    final String? newName = await showTextInputDialog(context, title: 'Rename module', initialValue: widget.module.name);
    if (newName != null) setState(() => widget.module.name = newName);
  }

  @override
  Widget build(BuildContext context) {
    final module = widget.module;
    return Scaffold(
      appBar: AppBar(
        title: Text(module.name),
        actions: [IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _renameModule)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.outerPadding),
        children: [
          ModuleStatusHeader(module: module),
          const SizedBox(height: 24),
          SectionHeader('Outputs (${module.channels.length})'),
          for (int i = 0; i < module.channels.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.betweenCards),
              child: _OutputRow(
                channel: module.channels[i],
                index: i,
                onToggle: () => setState(() => module.channels[i].isOn = !module.channels[i].isOn),
                onEdit: () => _editChannel(module.channels[i]),
              ),
            ),
          if (module.inputs.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHeader('Physical Inputs'),
            for (final input in module.inputs)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.betweenCards),
                child: _InputRow(input: input, onTap: () => _editInput(input)),
              ),
          ],
        ],
      ),
    );
  }
}

class _OutputRow extends StatelessWidget {
  const _OutputRow({required this.channel, required this.index, required this.onToggle, required this.onEdit});

  final ChannelOutput channel;
  final int index;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            IconAvatar(icon: channel.icon, filled: channel.isOn),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(channel.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text('Output ${index + 1}', style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.5))),
                ],
              ),
            ),
            SizedBox(
              width: 88,
              height: 48,
              child: channel.isOn
                  ? FilledButton(onPressed: onToggle, child: const Text('ON'))
                  : OutlinedButton(onPressed: onToggle, child: const Text('OFF')),
            ),
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
          ],
        ),
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({required this.input, required this.onTap});

  final PhysicalInput input;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.toggle_on_outlined, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(input.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${input.mode.label} · bound to ${input.boundTo}',
                      style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.55)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

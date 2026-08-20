// lib/screens/add_module_screen.dart
//
// Brief section 2.1 "Simplified Addition": modules broadcast a self
// discovery message that the app can pick up, and are otherwise identified
// / added manually by IP address. Both flows are simulated here - selecting
// or submitting a module simply returns it to the Configuration screen via
// `Navigator.pop`.
import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class AddModuleScreen extends StatefulWidget {
  const AddModuleScreen({super.key});

  @override
  State<AddModuleScreen> createState() => _AddModuleScreenState();
}

class _AddModuleScreenState extends State<AddModuleScreen> {
  bool _scanning = true;
  late List<DeviceModule> _discovered;

  final _nameController = TextEditingController();
  final _ipController = TextEditingController();
  ModuleType _manualType = ModuleType.relay;

  @override
  void initState() {
    super.initState();
    _discovered = [];
    // Simulate listening for the module's self-discovery broadcast message.
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _discovered = mockDiscoveredModules();
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  List<ChannelOutput> _defaultChannelsFor(ModuleType type) {
    switch (type) {
      case ModuleType.relay:
        return List.generate(8, (i) => ChannelOutput(id: 'new-r$i', name: 'Output ${i + 1}', icon: Icons.power));
      case ModuleType.blind:
        return List.generate(2, (i) => ChannelOutput(id: 'new-b$i', name: 'Blind ${i + 1}', icon: Icons.blinds));
      case ModuleType.dimmerDc:
      case ModuleType.dimmerAc:
        return List.generate(4, (i) => ChannelOutput(id: 'new-d$i', name: 'Channel ${i + 1}', icon: Icons.tune));
      case ModuleType.temperature:
        return [];
    }
  }

  void _addDiscovered(DeviceModule module) {
    Navigator.of(context).pop(module);
  }

  void _addManual() {
    if (_ipController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the module IP address.')),
      );
      return;
    }
    final module = DeviceModule(
      id: 'manual-${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim().isEmpty ? _manualType.label : _nameController.text.trim(),
      type: _manualType,
      ipAddress: _ipController.text.trim(),
      status: ConnectionStatus.online,
      roomName: 'Unassigned',
      internalTempC: 25,
      channels: _defaultChannelsFor(_manualType),
    );
    Navigator.of(context).pop(module);
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(title: const Text('Add Module')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.outerPadding),
        children: [
          const SectionHeader('Discovered on network'),
          if (_scanning)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.6)),
                    SizedBox(height: 12),
                    Text('Listening for self-discovery broadcast...'),
                  ],
                ),
              ),
            )
          else if (_discovered.isEmpty)
            const EmptyState(icon: Icons.wifi_find_outlined, message: 'No new modules found on the network.')
          else
            for (final module in _discovered)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.betweenCards),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        IconAvatar(icon: module.type.icon),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(module.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text('${module.type.label} · ${module.ipAddress}',
                                  style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.55))),
                            ],
                          ),
                        ),
                        FilledButton(onPressed: () => _addDiscovered(module), child: const Text('Add')),
                      ],
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 24),
          const SectionHeader('Add manually by IP address'),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Module name (optional)', prefixIcon: Icon(Icons.edit_outlined)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ipController,
            decoration: const InputDecoration(labelText: 'IP address', hintText: '192.168.1.120', prefixIcon: Icon(Icons.lan_outlined)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ModuleType>(
            value: _manualType,
            decoration: const InputDecoration(labelText: 'Module type', prefixIcon: Icon(Icons.category_outlined)),
            items: [
              for (final type in ModuleType.values) DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: (value) => setState(() => _manualType = value ?? _manualType),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: _addManual, icon: const Icon(Icons.add), label: const Text('Add module')),
        ],
      ),
    );
  }
}

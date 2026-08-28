// lib/screens/add_module_screen.dart
//
// Brief section 2.1 "Simplified Addition": modules broadcast a self
// discovery message that the app can pick up (see ModuleDiscovery, which
// implements the UDP Discovery Protocol in doc/PROTOCOLS.md §2), and are
// otherwise identified / added manually by IP address. Selecting or
// submitting a module simply returns it to the Configuration screen via
// `Navigator.pop`.
import 'package:flutter/material.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

import '../core/discovery/module_discovery.dart';
import '../models/models.dart';
import '../services/settings_store.dart';
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

  final ModuleDiscovery _discovery = ModuleDiscovery();

  final _nameController = TextEditingController();
  final _ipController = TextEditingController();
  final _tcpPortController = TextEditingController(text: '5005');
  late final TextEditingController _tempThresholdController;
  ModuleType _manualType = ModuleType.relay;

  @override
  void initState() {
    super.initState();
    _discovered = [];
    _tempThresholdController = TextEditingController(
        text: SettingsStore.shared.defaultTemperatureThreshold
            .toInt()
            .toString());
    _scan();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _tcpPortController.dispose();
    _tempThresholdController.dispose();
    super.dispose();
  }

  List<ChannelOutput> _defaultChannelsFor(
      ModuleType type, AppLocalizations l10n) {
    switch (type) {
      case ModuleType.relay:
        return List.generate(
            8,
            (i) => ChannelOutput(
                id: 'new-r$i',
                name: l10n.addModuleOutput(i + 1),
                icon: Icons.power));
      case ModuleType.blind:
        return List.generate(
            2,
            (i) => ChannelOutput(
                id: 'new-b$i',
                name: l10n.addModuleBlind(i + 1),
                icon: Icons.blinds));
      case ModuleType.dimmerDc:
      case ModuleType.dimmerAc:
        return List.generate(
            4,
            (i) => ChannelOutput(
                id: 'new-d$i',
                name: l10n.addModuleChannel(i + 1),
                icon: Icons.tune));
      case ModuleType.temperature:
        return [];
    }
  }

  /// Sends the UDP discovery broadcast and awaits PDU identity responses.
  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _discovered = [];
    });
    List<DeviceModule> found;
    try {
      final results = await _discovery.discover();
      found = [for (final d in results) _toDeviceModule(d)];
    } catch (_) {
      found = const [];
    }
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _discovered = found;
    });
  }

  void _refreshDiscovery() {
    _scan();
  }

  /// Parses the temperature threshold field, falling back to the app-wide
  /// default configured on Settings -> Notifications.
  double _temperatureThreshold() {
    final parsed = double.tryParse(_tempThresholdController.text.trim());
    if (parsed == null || parsed <= 0) {
      return SettingsStore.shared.defaultTemperatureThreshold;
    }
    return parsed.clamp(0, 100);
  }

  /// Builds a configurable [DeviceModule] from a discovery reply. The UDP
  /// identity response does not advertise a module type or channel count, so
  /// discovered units are presented as standard relay PDUs (they can be
  /// renamed and re-typed after registering).
  DeviceModule _toDeviceModule(DiscoveredModule discovered) {
    return DeviceModule(
      id: 'discovered-${discovered.serial.isNotEmpty ? discovered.serial : discovered.guid}',
      name: discovered.name.isNotEmpty
          ? discovered.name
          : AppLocalizations.of(context).addModuleUnnamedRelay,
      type: ModuleType.relay,
      ipAddress: discovered.ip,
      tcpPort: discovered.tcpPort,
      status: ConnectionStatus.online,
      roomName: AppLocalizations.of(context).unassigned,
      internalTempC: 25,
      tempMaxC: SettingsStore.shared.defaultTemperatureThreshold,
      channels:
          _defaultChannelsFor(ModuleType.relay, AppLocalizations.of(context)),
    );
  }

  void _addDiscovered(DeviceModule module) {
    Navigator.of(context).pop(module);
  }

  void _addManual() {
    if (_ipController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).addModuleEnterIp)),
      );
      return;
    }
    final module = DeviceModule(
      id: 'manual-${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim().isEmpty
          ? _manualType.label
          : _nameController.text.trim(),
      type: _manualType,
      ipAddress: _ipController.text.trim(),
      tcpPort: int.tryParse(_tcpPortController.text.trim()) ?? 5005,
      status: ConnectionStatus.online,
      roomName: AppLocalizations.of(context).unassigned,
      internalTempC: 25,
      tempMaxC: _temperatureThreshold(),
      channels: _defaultChannelsFor(_manualType, AppLocalizations.of(context)),
    );
    Navigator.of(context).pop(module);
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.addModuleTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.outerPadding),
        children: [
          SectionHeader(
            l10n.addModuleDiscovered,
            trailing: IconButton(
              tooltip: l10n.addModuleRefreshTooltip,
              onPressed: _scanning ? null : _refreshDiscovery,
              icon: Icon(
                _scanning ? Icons.sync : Icons.refresh,
              ),
            ),
          ),
          if (_scanning)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.6)),
                    const SizedBox(height: 12),
                    Text(l10n.addModuleListening),
                  ],
                ),
              ),
            )
          else if (_discovered.isEmpty)
            EmptyState(
                icon: Icons.wifi_find_outlined,
                message: l10n.addModuleNoneFound)
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
                              Text(module.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(
                                  l10n.configModuleSummary(
                                      module.type.label, module.ipAddress),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          onSurface.withValues(alpha: 0.55))),
                            ],
                          ),
                        ),
                        FilledButton(
                            onPressed: () => _addDiscovered(module),
                            child: Text(l10n.addModuleButton)),
                      ],
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 24),
          SectionHeader(l10n.addModuleManualSection),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
                labelText: l10n.addModuleNameOptional,
                prefixIcon: const Icon(Icons.edit_outlined)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ipController,
            decoration: InputDecoration(
                labelText: l10n.ipAddress,
                hintText: '192.168.1.120',
                prefixIcon: const Icon(Icons.lan_outlined)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tcpPortController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: l10n.tcpPort,
                hintText: '5005',
                prefixIcon: const Icon(Icons.router_outlined)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ModuleType>(
            initialValue: _manualType,
            decoration: InputDecoration(
                labelText: l10n.addModuleType,
                prefixIcon: const Icon(Icons.category_outlined)),
            items: [
              for (final type in ModuleType.values)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: (value) =>
                setState(() => _manualType = value ?? _manualType),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tempThresholdController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: l10n.tempThresholdLabel,
                helperText: l10n.addModuleTempThresholdDefault(
                    SettingsStore.shared.defaultTemperatureThreshold.toInt()),
                prefixIcon: const Icon(Icons.thermostat_outlined)),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
              onPressed: _addManual,
              icon: const Icon(Icons.add),
              label: Text(l10n.addModuleAddAction)),
        ],
      ),
    );
  }
}

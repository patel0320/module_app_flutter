// lib/screens/dimmer_dc_screen.dart
//
// Brief section 2.3 "Lighting Dimming Modules (DC)": intensity (PWM)
// control for the 4 outputs of 12-24V DC lighting.
import 'package:flutter/material.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

import '../models/models.dart';
import '../services/event_log_store.dart';
import '../services/module_status/module_status_service.dart';
import '../services/module_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'channel_editor_screen.dart';
import 'input_editor_screen.dart';

class DimmerDcScreen extends StatefulWidget {
  const DimmerDcScreen({super.key, required this.module});

  final DeviceModule module;

  @override
  State<DimmerDcScreen> createState() => _DimmerDcScreenState();
}

class _DimmerDcScreenState extends State<DimmerDcScreen> {
  Future<void> _editChannel(ChannelOutput channel, int index) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => ChannelEditorScreen(
              channel: channel, module: widget.module, index: index)),
    );
    if (saved == true) {
      // Persist the renamed output so the user-defined name survives restarts.
      await ModuleStore.shared.update(widget.module.id, (_) {});
    }
    setState(() {});
  }

  Future<void> _editInput(PhysicalInput input, int index) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => InputEditorScreen(
              input: input, module: widget.module, index: index)),
    );
    setState(() {});
  }

  Future<void> _holdInput(DeviceModule module, int index, bool held) =>
      ModuleStatusService.shared.setVirtualInputState(module.id, index, held);

  Future<void> _editModuleInfo() async {
    final saved = await showEditModuleInfoDialog(context, widget.module);
    if (saved) setState(() {});
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await ModuleStatusService.shared
        .refreshOne(ModuleStore.shared.byId(widget.module.id) ?? widget.module)
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final module = widget.module;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(module.name),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.refreshTooltip,
              onPressed: _refresh),
          IconButton(
              icon: const Icon(Icons.edit_outlined), onPressed: _editModuleInfo)
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.outerPadding),
        children: [
          ModuleStatusHeader(module: module),
          const SizedBox(height: 8),
          Text(
            l10n.dimmerDcSubtitle,
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 16),
          SectionHeader(l10n.dimmingChannelsHeader(module.channels.length)),
          for (int i = 0; i < module.channels.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.betweenCards),
              child: DimmerChannelCard(
                channel: module.channels[i],
                onChanged: (value) =>
                    setState(() => module.channels[i].brightness = value),
                onChangeEnd: (value) => EventLogStore.shared.recordBrightness(
                  moduleName: module.name,
                  outputName: module.channels[i].name,
                  pct: value,
                ),
                onEdit: () => _editChannel(module.channels[i], i),
              ),
            ),
          if (module.inputs.any((i) => i.enabled)) ...[
            const SizedBox(height: 24),
            SectionHeader(l10n.moduleInputs(module.inputs.length)),
            for (int i = 0; i < module.inputs.length; i++)
              if (module.inputs[i].enabled)
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: AppSpacing.betweenCards),
                  child: InputFieldCard(
                    input: module.inputs[i],
                    onHoldChanged: (held) => _holdInput(module, i, held),
                    onReleased: _refresh,
                    onEdit: () => _editInput(module.inputs[i], i),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

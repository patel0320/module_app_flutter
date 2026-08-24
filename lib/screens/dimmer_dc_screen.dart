// lib/screens/dimmer_dc_screen.dart
//
// Brief section 2.3 "Lighting Dimming Modules (DC)": intensity (PWM)
// control for the 4 outputs of 12-24V DC lighting.
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/event_log_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'channel_editor_screen.dart';

class DimmerDcScreen extends StatefulWidget {
  const DimmerDcScreen({super.key, required this.module});

  final DeviceModule module;

  @override
  State<DimmerDcScreen> createState() => _DimmerDcScreenState();
}

class _DimmerDcScreenState extends State<DimmerDcScreen> {
  Future<void> _editChannel(ChannelOutput channel) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChannelEditorScreen(channel: channel, moduleName: widget.module.name)),
    );
    setState(() {});
  }

  Future<void> _editModuleInfo() async {
    final saved = await showEditModuleInfoDialog(context, widget.module);
    if (saved) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final module = widget.module;
    return Scaffold(
      appBar: AppBar(
        title: Text(module.name),
        actions: [IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _editModuleInfo)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.outerPadding),
        children: [
          ModuleStatusHeader(module: module),
          const SizedBox(height: 8),
          Text(
            '12-24V DC dimming outputs (PWM)',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55)),
          ),
          const SizedBox(height: 16),
          SectionHeader('Dimming Channels (${module.channels.length})'),
          for (final channel in module.channels)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.betweenCards),
              child: DimmerChannelCard(
                channel: channel,
                onChanged: (value) => setState(() => channel.brightness = value),
                onChangeEnd: (value) => EventLogStore.shared.recordBrightness(
                  moduleName: module.name,
                  outputName: channel.name,
                  pct: value,
                ),
                onEdit: () => _editChannel(channel),
              ),
            ),
        ],
      ),
    );
  }
}

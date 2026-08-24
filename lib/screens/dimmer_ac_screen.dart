// lib/screens/dimmer_ac_screen.dart
//
// Brief section 2.3 "Lighting Dimming Modules (AC)": intensity control for
// the 4 outputs of 220V AC lighting.
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/event_log_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'channel_editor_screen.dart';

class DimmerAcScreen extends StatefulWidget {
  const DimmerAcScreen({super.key, required this.module});

  final DeviceModule module;

  @override
  State<DimmerAcScreen> createState() => _DimmerAcScreenState();
}

class _DimmerAcScreenState extends State<DimmerAcScreen> {
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
            '220V AC dimming outputs',
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

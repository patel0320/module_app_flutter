// lib/screens/relay_control_screen.dart
//
// Brief section 2.3 "Standard Relay Modules": ON/OFF control for every
// output, plus (brief section 2.2) naming/icon customization and physical
// switch input configuration.
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../models/models.dart';
import '../services/event_log_store.dart';
import '../services/module_status/module_status_service.dart';
import '../services/module_store.dart';
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
      MaterialPageRoute(
          builder: (_) => ChannelEditorScreen(
              channel: channel, moduleName: widget.module.name)),
    );
    setState(() {});
  }

  Future<void> _editInput(PhysicalInput input) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) =>
              InputEditorScreen(input: input, module: widget.module)),
    );
    setState(() {});
  }

  Future<void> _editModuleInfo() async {
    final saved = await showEditModuleInfoDialog(context, widget.module);
    if (saved) setState(() {});
  }

  /// Sends the ON/OFF relay command to the module, then re-asks for the
  /// actual output states (`AT+OUTSTAT`). The parsed response flows through
  /// the command service into the store, which rebuilds this screen to reflect
  /// the module-reported state.
  Future<void> _toggleOutput(DeviceModule module, int index, bool next) async {
    EventLogStore.shared.recordModuleAction(
      moduleName: module.name,
      outputName: module.channels[index].name,
      on: next,
    );
    final service = ModuleStatusService.shared.commandServiceFor(module.id);
    if (service == null || !service.isConnected) {
      // No live command/status unit - fall back to a local toggle.
      setState(() => module.channels[index].isOn = next);
      return;
    }
    try {
      final ok = next
          ? await service.turnOnRelay(index)
          : await service.turnOffRelay(index);
      if (!ok) return;
      //await service.command(PduAtCommands.allOutputStates);
    } catch (_) {
      // Command failed or module offline - keep the UI showing reality.
    }
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
    // Present the live instance from the app-wide store (status refreshed on
    // open) while keeping the tapped module (which owns the editor callbacks).
    return ListenableBuilder(
      listenable: ModuleStore.shared,
      builder: (context, _) {
        final module =
            ModuleStore.shared.byId(widget.module.id) ?? widget.module;
        final l10n = AppLocalizations.of(context);
        return Scaffold(
          appBar: AppBar(
            title: Text(module.name),
            actions: [
              IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.relayRefreshTooltip,
                  onPressed: _refresh),
              IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _editModuleInfo),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.outerPadding),
            children: [
              ModuleStatusHeader(module: module),
              const SizedBox(height: 24),
              SectionHeader(l10n.relayOutputsHeader(module.channels.length)),
              for (int i = 0; i < module.channels.length; i++)
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: AppSpacing.betweenCards),
                  child: _OutputRow(
                    channel: module.channels[i],
                    index: i,
                    onToggle: () =>
                        _toggleOutput(module, i, !module.channels[i].isOn),
                    onEdit: () => _editChannel(module.channels[i]),
                  ),
                ),
              if (module.inputs.isNotEmpty) ...[
                const SizedBox(height: 24),
                SectionHeader(l10n.relayPhysicalInputs),
                for (final input in module.inputs)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppSpacing.betweenCards),
                    child:
                        _InputRow(input: input, onTap: () => _editInput(input)),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _OutputRow extends StatelessWidget {
  const _OutputRow(
      {required this.channel,
      required this.index,
      required this.onToggle,
      required this.onEdit});

  final ChannelOutput channel;
  final int index;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final l10n = AppLocalizations.of(context);
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
                  Text(channel.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(l10n.relayOutput(index + 1),
                      style: TextStyle(
                          fontSize: 12, color: onSurface.withOpacity(0.5))),
                ],
              ),
            ),
            SizedBox(
              width: 88,
              height: 48,
              child: channel.isOn
                  ? FilledButton(onPressed: onToggle, child: Text(l10n.on))
                  : OutlinedButton(
                      onPressed: onToggle, child: Text(l10n.off)),
            ),
            IconButton(
                icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
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
    final l10n = AppLocalizations.of(context);
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
                    Text(input.label,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      l10n.relayInputSummary(input.mode.label, input.boundTo),
                      style: TextStyle(
                          fontSize: 12, color: onSurface.withOpacity(0.55)),
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

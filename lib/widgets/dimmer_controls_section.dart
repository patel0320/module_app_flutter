// lib/widgets/dimmer_controls_section.dart
//
// Live dimming controls shared by the AC and DC dimmer screens: a master "all
// outputs" brightness slider, one controllable card per channel and the PWM
// drive-frequency selector. Every control is mapped to the Control API
// (doc/Soleux_Control_API_Command_Specification_v0.3.md):
//
//   - master slider end      -> set_multiple_dimmer_levels
//   - per-channel slider end -> set_dimmer_level
//   - off shortcut           -> set_output_state(state: false)
//   - on shortcut            -> set_output_state(state: true)
//   - icon tap               -> toggle_dimmer then get_device_state to re-sync
//   - initial / refresh sync -> get_device_state (reads set_pwm/actual_pwm)
//   - frequency selector     -> get/set_dimmer_frequency
//
// The section reads the live module from [ModuleStore] so the state reflected
// by [ModuleStatusService] after each successful command rebuilds it without
// manual bookkeeping. On legacy-AT sessions the Control-API-only commands
// return false and the section falls back to a local optimistic toggle, exactly
// like the relay screen.
import 'package:flutter/material.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

import '../models/models.dart';
import '../services/event_log_store.dart';
import '../services/module_status/module_status_service.dart';
import '../services/module_store.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

class DimmerControlsSection extends StatefulWidget {
  const DimmerControlsSection({
    super.key,
    required this.module,
    required this.onEditChannel,
  });

  final DeviceModule module;

  /// Opens the channel editor for the zero-based [index].
  final ValueChanged<int> onEditChannel;

  @override
  State<DimmerControlsSection> createState() => _DimmerControlsSectionState();
}

class _DimmerControlsSectionState extends State<DimmerControlsSection> {
  /// Master slider governing value; null lets it track the highest enabled
  /// channel brightness until the user drags it.
  int? _master;

  /// Last `get_dimmer_frequency` result (null when unsupported/unreachable).
  DimmerFrequencyInfo? _frequency;

  /// The live instance from the app-wide store (the tapped module owns the
  /// editor callbacks, but live state lives in the store).
  DeviceModule? get _live =>
      ModuleStore.shared.byId(widget.module.id) ?? widget.module;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  Future<void> _sync() async {
    // Hydrate the per-channel levels from get_device_state then read the
    // frequency; unsupported/unreachable commands are no-ops.
    await ModuleStatusService.shared.syncDimmerLevels(widget.module.id);
    final frequency =
        await ModuleStatusService.shared.getDimmerFrequency(widget.module.id);
    if (!mounted) return;
    setState(() => _frequency = frequency);
  }

  Future<void> _setChannelLevel(
      DeviceModule module, int index, int value) async {
    final channel = module.channels[index];
    EventLogStore.shared.recordBrightness(
      moduleName: module.name,
      outputName: channel.name,
      pct: value,
    );
    await ModuleStatusService.shared.setDimmerLevel(module.id, index, value);
    if (mounted) setState(() => channel.isOn = value > 0);
  }

  Future<void> _turnChannelOn(DeviceModule module, int index) async {
    final channel = module.channels[index];
    EventLogStore.shared.recordModuleAction(
      moduleName: module.name,
      outputName: channel.name,
      on: true,
    );
    // set_output_state(state: true) turns the dimmer fully on; when the level
    // is 0 that would look like "nothing happens", so turn on at full brightness
    // instead.
    if (channel.brightness > 0) {
      await ModuleStatusService.shared.dimmerOn(module.id, index);
    } else {
      await ModuleStatusService.shared.setDimmerLevel(module.id, index, 100);
    }
    if (!mounted) return;
    setState(() {
      channel.isOn = true;
      if (channel.brightness <= 0) channel.brightness = 100;
    });
  }

  Future<void> _turnChannelOff(DeviceModule module, int index) async {
    final channel = module.channels[index];
    EventLogStore.shared.recordModuleAction(
      moduleName: module.name,
      outputName: channel.name,
      on: false,
    );
    // set_output_state(state: false) turns the dimmer off; we flip the state.
    await ModuleStatusService.shared.dimmerOff(module.id, index);
    if (mounted) setState(() => channel.isOn = false);
  }

  Future<void> _toggleChannel(DeviceModule module, int index) async {
    final service = ModuleStatusService.shared;
    try {
      final ok = await service.toggleDimmer(module.id, index);
      if (!ok) {
        // No Control API support / offline - local optimistic toggle.
        setState(
            () => module.channels[index].isOn = !module.channels[index].isOn);
        return;
      }
      // Re-read the settled single channel so the percentage reflects reality.
      final snapshot = await service.getDimmerState(module.id, index);
      if (!mounted) return;
      if (snapshot != null) {
        setState(() {
          final channel = module.channels[index];
          channel.isOn = snapshot.state;
          channel.brightness = snapshot.requestedLevel.round().clamp(0, 100);
        });
      }
    } catch (e, st) {
      debugPrint('DimmerControlsSection: toggle_dimmer failed: $e\n$st');
    }
  }

  Future<void> _setMasterLevel(DeviceModule module, int value) async {
    final targets = [
      for (var i = 0; i < module.channels.length; i++)
        if (module.channels[i].enabled) {'channel': i, 'level': value},
    ];
    if (targets.isEmpty) return;
    await ModuleStatusService.shared
        .setMultipleDimmerLevels(module.id, targets);
    if (mounted) setState(() => _master = null);
  }

  Future<void> _setFrequency(int frequencyHz) async {
    await ModuleStatusService.shared
        .setDimmerFrequency(widget.module.id, frequencyHz);
    final frequency =
        await ModuleStatusService.shared.getDimmerFrequency(widget.module.id);
    if (mounted) setState(() => _frequency = frequency);
  }

  int _defaultMaster(DeviceModule module) {
    var max = 0;
    for (final channel in module.channels) {
      if (channel.enabled && channel.brightness > max) {
        max = channel.brightness;
      }
    }
    return max;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ModuleStore.shared,
      builder: (context, _) {
        final module = _live;
        if (module == null) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(l10n.dimmingChannelsHeader(module.channels.length)),
            for (int i = 0; i < module.channels.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.betweenCards),
                child: DimmerChannelCard(
                  channel: module.channels[i],
                  onChanged: (value) =>
                      setState(() => module.channels[i].brightness = value),
                  onChangeEnd: (value) => _setChannelLevel(module, i, value),
                  onToggle: () => _toggleChannel(module, i),
                  onTurnOn: () => _turnChannelOn(module, i),
                  onTurnOff: () => _turnChannelOff(module, i),
                  onEdit: () => widget.onEditChannel(i),
                ),
              ),
            if (_frequency != null) ...[
              const SizedBox(height: AppSpacing.betweenCards),
              _FrequencyCard(
                frequency: _frequency!,
                onChanged: _setFrequency,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Coarse "all outputs to X%" slider backed by `set_multiple_dimmer_levels`.
class _MasterBrightnessCard extends StatelessWidget {
  const _MasterBrightnessCard({
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
        child: Row(
          children: [
            const Icon(Icons.layers_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.dimmerAllOutputs,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: l10n.cwTurnOff,
              icon: const Icon(Icons.brightness_low),
              onPressed: () => onChangeEnd(0),
            ),
            Expanded(
              child: Slider(
                value: value.toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                label: '$value%',
                onChanged: (v) => onChanged(v.round()),
                onChangeEnd: (v) => onChangeEnd(v.round()),
              ),
            ),
            IconButton(
              tooltip: l10n.cwTurnOn,
              icon: const Icon(Icons.brightness_high),
              onPressed: () => onChangeEnd(100),
            ),
          ],
        ),
      ),
    );
  }
}

/// PWM drive-frequency selector backed by `get/set_dimmer_frequency`.
class _FrequencyCard extends StatelessWidget {
  const _FrequencyCard({required this.frequency, required this.onChanged});

  final DimmerFrequencyInfo frequency;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final allowed = frequency.allowedHz;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.timeline_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.dimmerFrequencyHeader,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (allowed.isNotEmpty)
              DropdownButton<int>(
                value: allowed.contains(frequency.frequencyHz)
                    ? frequency.frequencyHz
                    : allowed.first,
                items: [
                  for (final hz in allowed)
                    DropdownMenuItem(value: hz, child: Text('$hz Hz')),
                ],
                onChanged: (hz) {
                  if (hz != null && hz != frequency.frequencyHz) {
                    onChanged(hz);
                  }
                },
              )
            else
              Text('${frequency.frequencyHz} Hz',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

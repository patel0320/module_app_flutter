// lib/screens/manual_dimming_slider_screen.dart
//
// Brief section 2.4 "Dedicated Manual Control": a special scenario type
// that controls a single dimmer output and can be opened directly from
// Home for quick intensity adjustment.
import 'package:flutter/material.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

class ManualDimmingSliderScreen extends StatefulWidget {
  const ManualDimmingSliderScreen({super.key, required this.scenario});

  final Scenario scenario;

  @override
  State<ManualDimmingSliderScreen> createState() =>
      _ManualDimmingSliderScreenState();
}

class _ManualDimmingSliderScreenState extends State<ManualDimmingSliderScreen> {
  late int _value = widget.scenario.sliderValue;

  void _update(int value) {
    setState(() {
      _value = value.clamp(0, 100);
      widget.scenario.sliderValue = _value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.scenario.name)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.outerPadding),
        child: Column(
          children: [
            const Spacer(),
            Icon(
              Icons.lightbulb,
              size: 96,
              color: _value == 0 ? onSurface.withValues(alpha: 0.2) : onSurface,
            ),
            const SizedBox(height: 16),
            Text('$_value%',
                style:
                    const TextStyle(fontSize: 64, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              widget.scenario.sliderTargetName.isEmpty
                  ? l10n.manualDimDefaultLabel
                  : widget.scenario.sliderTargetName,
              style: TextStyle(color: onSurface.withValues(alpha: 0.55)),
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.brightness_low),
                Expanded(
                  child: Slider(
                    value: _value.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: '$_value%',
                    onChanged: (v) => _update(v.round()),
                  ),
                ),
                const Icon(Icons.brightness_high),
              ],
            ),
            Row(
              children: [
                Expanded(
                    child: OutlinedButton(
                        onPressed: () => _update(0), child: Text(l10n.off))),
                const SizedBox(width: 12),
                Expanded(
                    child: FilledButton(
                        onPressed: () => _update(100), child: Text(l10n.on))),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

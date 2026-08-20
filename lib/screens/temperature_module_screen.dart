// lib/screens/temperature_module_screen.dart
//
// Brief section 2.3 "Temperature Module": displays the current temperature
// and lets the user configure high/low alert thresholds. Per the brief's
// explicit note, advanced thermostat functionality is not exposed in this
// phase (Level 1) - shown here as a disabled row for transparency.
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class TemperatureModuleScreen extends StatefulWidget {
  const TemperatureModuleScreen({super.key, required this.module});

  final DeviceModule module;

  @override
  State<TemperatureModuleScreen> createState() => _TemperatureModuleScreenState();
}

class _TemperatureModuleScreenState extends State<TemperatureModuleScreen> {
  bool _alertsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final module = widget.module;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final bool alert = module.isOverTemperature;
    final String statusLabel = !alert
        ? 'Normal'
        : (module.internalTempC > module.tempMaxC ? 'Above maximum threshold' : 'Below minimum threshold');

    return Scaffold(
      appBar: AppBar(title: Text(module.name)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.outerPadding),
        children: [
          ModuleStatusHeader(module: module),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Text(
                  '${module.internalTempC.toStringAsFixed(1)}°C',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    color: alert ? AppColors.offlineAlert : onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusLabel,
                  style: TextStyle(fontWeight: FontWeight.w600, color: alert ? AppColors.offlineAlert : AppColors.online),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Alert Thresholds'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _ThresholdSlider(
                    label: 'Minimum',
                    value: module.tempMinC,
                    onChanged: (v) => setState(() => module.tempMinC = v),
                  ),
                  _ThresholdSlider(
                    label: 'Maximum',
                    value: module.tempMaxC,
                    onChanged: (v) => setState(() => module.tempMaxC = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Available Functions'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('High / Low Threshold Alerts'),
                  subtitle: const Text('Notify when temperature exits the range above'),
                  value: _alertsEnabled,
                  onChanged: (v) => setState(() => _alertsEnabled = v),
                ),
                const Divider(height: 1),
                const ListTile(
                  title: Text('Temperature Display'),
                  subtitle: Text('Live reading from the module sensor'),
                  trailing: Icon(Icons.check_circle_outline),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Advanced Thermostat Control'),
                  subtitle: const Text('Managed by the module\'s internal server - not available in this phase'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: onSurface.withOpacity(0.25)),
                    ),
                    child: const Text('Coming soon', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  enabled: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThresholdSlider extends StatelessWidget {
  const _ThresholdSlider({required this.label, required this.value, required this.onChanged});

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('${value.toStringAsFixed(0)}°C'),
          ],
        ),
        Slider(
          value: value.clamp(0, 100),
          min: 0,
          max: 100,
          divisions: 100,
          label: '${value.toStringAsFixed(0)}°C',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

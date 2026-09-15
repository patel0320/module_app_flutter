// lib/widgets/module_keep_alive_settings.dart
//
// Settings card for the Android continuous-monitoring foreground service (see
// ModuleKeepAlive + ModuleKeepAliveService.kt):
//
//   - a switch to start / stop the keep-alive service (Android only; the card
//     is hidden on every other platform, which iOS handles separately), and
//   - the opt-in battery-optimization exemption entry. This is strictly
//     opt-in: it only opens the system
//     ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS dialog when the user taps
//     "Request exemption"; the app never asks automatically.
import 'package:flutter/material.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

import '../services/module_status/module_keep_alive.dart';

class ModuleKeepAliveSettings extends StatefulWidget {
  const ModuleKeepAliveSettings({super.key});

  @override
  State<ModuleKeepAliveSettings> createState() =>
      _ModuleKeepAliveSettingsState();
}

class _ModuleKeepAliveSettingsState extends State<ModuleKeepAliveSettings> {
  /// Latest battery-optimization exemption state; null while loading.
  bool? _batteryExempt;

  @override
  void initState() {
    super.initState();
    _refreshBatteryState();
  }

  Future<void> _refreshBatteryState() async {
    final exempt =
        await ModuleKeepAlive.shared.isIgnoringBatteryOptimizations();
    if (!mounted) return;
    setState(() => _batteryExempt = exempt);
  }

  Future<void> _toggleKeepAlive(bool on) async {
    if (on) {
      await ModuleKeepAlive.shared.start();
    } else {
      await ModuleKeepAlive.shared.stop();
    }
  }

  Future<void> _requestExemption() async {
    await ModuleKeepAlive.shared.requestBatteryOptimizationExemption();
    // The system dialog has no result callback; re-read the exemption state
    // shortly after the dialog is dismissed.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _refreshBatteryState();
    });
  }

  @override
  Widget build(BuildContext context) {
    // iOS is handled separately (BGAppRefreshTask / APNs); this whole card is
    // Android-only opt-in surface.
    if (!ModuleKeepAlive.supported) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return ValueListenableBuilder<bool>(
      valueListenable: ModuleKeepAlive.shared.running,
      builder: (context, running, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.settingsMonitoring,
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.sensors_outlined),
                  title: Text(l10n.settingsKeepAlive),
                  subtitle: Text(
                    '${l10n.settingsKeepAliveBody}\n'
                    '${running ? l10n.settingsKeepAliveRunning : l10n.settingsKeepAliveStopped}',
                  ),
                  value: running,
                  onChanged: _toggleKeepAlive,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.battery_std_outlined),
                  title: Text(l10n.settingsBatteryOptimization),
                  subtitle: Text(
                    '${l10n.settingsBatteryOptimizationBody}\n'
                    '${_batteryExempt == true ? l10n.settingsBatteryExempt : l10n.settingsBatteryNotExempt}',
                  ),
                  trailing: _batteryExempt == true
                      ? const Icon(Icons.check_circle_outline,
                          color: Colors.green)
                      : TextButton(
                          onPressed: _requestExemption,
                          child: Text(l10n.settingsBatteryRequestExemption),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

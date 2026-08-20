// lib/screens/notifications_settings_screen.dart
//
// Brief section 3.2 "Push Notifications": toggles for the real-time alerts
// the app sends even when it is closed.
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  bool _moduleStatus = true;
  bool _outputLeftOn = true;
  bool _temperature = true;
  bool _automationTriggered = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.outerPadding),
        children: [
          const SectionHeader('Push notifications'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Module offline / back online'),
                  subtitle: const Text('Alert when a module disconnects or reconnects'),
                  value: _moduleStatus,
                  onChanged: (v) => setState(() => _moduleStatus = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Output left ON too long'),
                  subtitle: const Text('Alert when an output stays on for an extended period'),
                  value: _outputLeftOn,
                  onChanged: (v) => setState(() => _outputLeftOn = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Temperature threshold exceeded'),
                  subtitle: const Text("Alert when a module's internal temperature is out of range"),
                  value: _temperature,
                  onChanged: (v) => setState(() => _temperature = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Automation triggered'),
                  subtitle: const Text('Notify when a smart automation runs'),
                  value: _automationTriggered,
                  onChanged: (v) => setState(() => _automationTriggered = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

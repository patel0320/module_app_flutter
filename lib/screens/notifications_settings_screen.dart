// lib/screens/notifications_settings_screen.dart
//
// Brief section 3.2 "Push Notifications": toggles for the real-time alerts
// the app sends even when it is closed.
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.outerPadding),
        children: [
          SectionHeader(l10n.notificationsPushSection),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(l10n.notificationsModuleOffline),
                  subtitle: Text(l10n.notificationsModuleOfflineDesc),
                  value: _moduleStatus,
                  onChanged: (v) => setState(() => _moduleStatus = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(l10n.notificationsOutputLongOn),
                  subtitle: Text(l10n.notificationsOutputLongOnDesc),
                  value: _outputLeftOn,
                  onChanged: (v) => setState(() => _outputLeftOn = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(l10n.notificationsTempExceeded),
                  subtitle: Text(l10n.notificationsTempExceededDesc),
                  value: _temperature,
                  onChanged: (v) => setState(() => _temperature = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(l10n.notificationsAutomation),
                  subtitle: Text(l10n.notificationsAutomationDesc),
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

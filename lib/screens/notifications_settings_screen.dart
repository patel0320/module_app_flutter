// lib/screens/notifications_settings_screen.dart
//
// Brief section 3.2 "Push Notifications": toggles for the real-time alerts
// the app sends even when it is closed. State lives in SettingsStore so the
// toggles survive app restarts.
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../services/settings_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = SettingsStore.shared;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsTitle)),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(AppSpacing.outerPadding),
          children: [
            SectionHeader(l10n.notificationsPushSection),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(l10n.notificationsModuleOffline),
                    subtitle: Text(l10n.notificationsModuleOfflineDesc),
                    value: store.moduleStatus,
                    onChanged: (v) => store.setModuleStatus(v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: Text(l10n.notificationsOutputLongOn),
                    subtitle: Text(l10n.notificationsOutputLongOnDesc),
                    value: store.outputLeftOn,
                    onChanged: (v) => store.setOutputLeftOn(v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: Text(l10n.notificationsTempExceeded),
                    subtitle: Text(l10n.notificationsTempExceededDesc),
                    value: store.temperature,
                    onChanged: (v) => store.setTemperature(v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: Text(l10n.notificationsAutomation),
                    subtitle: Text(l10n.notificationsAutomationDesc),
                    value: store.automationTriggered,
                    onChanged: (v) => store.setAutomationTriggered(v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

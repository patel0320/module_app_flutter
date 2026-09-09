// lib/screens/notifications_settings_screen.dart
//
// Brief section 3.2 "Push Notifications": toggles for the real-time alerts
// the app sends even when it is closed. State lives in SettingsStore so the
// toggles survive app restarts.
import 'package:flutter/material.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

import '../services/settings_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = SettingsStore.shared;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsTitle)),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
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
                      title: Text(l10n.notificationsFirmware),
                      subtitle: Text(l10n.notificationsFirmwareDesc),
                      value: store.firmwareUpdate,
                      onChanged: (v) => store.setFirmwareUpdate(v),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: Text(l10n.notificationsOutputLongOn),
                      subtitle: Text(l10n.notificationsOutputLongOnDesc),
                      value: store.outputLeftOn,
                      onChanged: (v) => store.setOutputLeftOn(v),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: Text(l10n.notificationsOutputOnThreshold),
                      subtitle: Text(l10n.notificationsOutputOnThresholdDesc),
                      trailing: Text(
                        l10n.notificationsHours(store.outputOnThresholdHours),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onTap: () => _editOutputOnThreshold(context, store),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: Text(l10n.notificationsTempExceeded),
                      subtitle: Text(l10n.notificationsTempExceededDesc),
                      value: store.temperature,
                      onChanged: (v) => store.setTemperature(v),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: Text(l10n.notificationsTempThreshold),
                      subtitle: Text(l10n.notificationsTempThresholdDesc),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              if (store.defaultTemperatureThreshold > 0) {
                                store.setDefaultTemperatureThreshold(
                                    store.defaultTemperatureThreshold - 1);
                              }
                            },
                          ),
                          SizedBox(
                            width: 48,
                            child: Text(
                              '${store.defaultTemperatureThreshold.toInt()}\u00b0C',
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () {
                              if (store.defaultTemperatureThreshold < 100) {
                                store.setDefaultTemperatureThreshold(
                                    store.defaultTemperatureThreshold + 1);
                              }
                            },
                          ),
                        ],
                      ),
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
      ),
    );
  }

  Future<void> _editOutputOnThreshold(
      BuildContext context, SettingsStore store) async {
    final l10n = AppLocalizations.of(context);
    final controller =
        TextEditingController(text: store.outputOnThresholdHours.toString());
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.notificationsOutputOnThreshold),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.notificationsOutputOnThreshold,
            suffixText: 'h',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed == null) return;
              Navigator.of(ctx).pop(parsed.clamp(1, 168));
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (value != null) {
      await store.setOutputOnThresholdHours(value);
    }
  }
}

// lib/screens/settings_screen.dart
//
// Brief section III "Settings Section": account, notifications, language
// and appearance, plus a reminder that the architecture is multi-location
// ready even though v1 manages a single location (brief section 4.2).
import 'package:flutter/material.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

import '../services/event_log_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'appearance_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _clearEventHistory(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.settingsClearEventHistory,
      message: l10n.settingsClearHistoryMsg,
      confirmLabel: l10n.settingsClear,
    );
    if (confirmed) {
      await EventLogStore.shared.clear();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsHistoryCleared)),
        );
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.settingsSignOutDialog,
      message: l10n.settingsSignOutMsg,
      confirmLabel: l10n.settingsSignOutDialog,
    );
    if (confirmed && context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.outerPadding),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: CircleAvatar(
                radius: 26,
                backgroundColor: onSurface,
                child: Text('AP',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.surface,
                        fontWeight: FontWeight.w800)),
              ),
              title: const Text('Alex Popescu',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              subtitle: const Text('alex.popescu@example.com'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pushNamed('/settings/account'),
            ),
          ),
          const SizedBox(height: 24),
          SectionHeader(l10n.settingsPreferences),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text(l10n.settingsNotifications),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context)
                      .pushNamed('/settings/notifications'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: Text(l10n.settingsLanguage),
                  subtitle: Text(l10n.settingsLanguageEn),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.of(context).pushNamed('/settings/language'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.history_outlined),
                  title: Text(l10n.settingsClearEventHistory),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _clearEventHistory(context),
                ),
                const Divider(height: 1),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeModeNotifier,
                  builder: (context, mode, _) => ListTile(
                    leading: const Icon(Icons.contrast_outlined),
                    title: Text(l10n.settingsAppearance),
                    subtitle: Text(appearanceLabel(mode, l10n)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.of(context).pushNamed('/settings/appearance'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SectionHeader(l10n.settingsLocation),
          Card(
            child: ListTile(
              leading: const Icon(Icons.other_houses_outlined),
              title: Text(l10n.settingsHome),
              subtitle: Text(l10n.settingsSingleLocation),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.offlineAlert,
                side:
                    const BorderSide(color: AppColors.offlineAlert, width: 1.4),
              ),
              onPressed: () => _signOut(context),
              icon: const Icon(Icons.logout),
              label: Text(l10n.settingsSignOut),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(l10n.appVersion,
                style: TextStyle(
                    fontSize: 12, color: onSurface.withValues(alpha: 0.4))),
          ),
        ],
      ),
    );
  }
}

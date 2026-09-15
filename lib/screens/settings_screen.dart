// lib/screens/settings_screen.dart
//
// Brief section III "Settings Section": account, notifications, language
// and appearance, plus a reminder that the architecture is multi-location
// ready even though v1 manages a single location (brief section 4.2). The
// "Command protocol" section picks the Control API transport the app uses to
// talk to modules: the persistent TCP session on port 5008 or the stateless
// HTTP/HTTPS POST /api/v1/command endpoint
// (doc/Soleux_Control_API_Command_Specification_v0.2.md §"Transport mapping").
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

import '../services/event_log_store.dart';
import '../services/session_store.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/module_keep_alive_settings.dart';
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
      SessionStore.shared.setSignedIn(false);
      Navigator.of(context)
          .restorablePushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.outerPadding),
          children: [
            // skip login in current publish
            // Card(
            //   child: ListTile(
            //     contentPadding: const EdgeInsets.all(12),
            //     leading: CircleAvatar(
            //       radius: 26,
            //       backgroundColor: onSurface,
            //       child: Text('AP',
            //           style: TextStyle(
            //               color: Theme.of(context).colorScheme.surface,
            //               fontWeight: FontWeight.w800)),
            //     ),
            //     title: const Text('Alex Popescu',
            //         style:
            //             TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            //     subtitle: const Text('alex.popescu@example.com'),
            //     trailing: const Icon(Icons.chevron_right),
            //     onTap: () => Navigator.of(context)
            //         .restorablePushNamed('/settings/account'),
            //   ),
            // ),
            // const SizedBox(height: 24),
            SectionHeader(l10n.settingsPreferences),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: Text(l10n.settingsNotifications),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context)
                        .restorablePushNamed('/settings/notifications'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.language_outlined),
                    title: Text(l10n.settingsLanguage),
                    subtitle: Text(l10n.settingsLanguageEn),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context)
                        .restorablePushNamed('/settings/language'),
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
                      onTap: () => Navigator.of(context)
                          .restorablePushNamed('/settings/appearance'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const ModuleKeepAliveSettings(),
            const SizedBox(height: 24),
            SectionHeader(l10n.settingsLocation),
            ListenableBuilder(
              listenable: SettingsStore.shared,
              builder: (context, _) => Card(
                child: ListTile(
                  leading: const Icon(Icons.other_houses_outlined),
                  title: Text(l10n.settingsHome),
                  subtitle: Text(
                    SettingsStore.shared.locationName.isNotEmpty
                        ? SettingsStore.shared.locationName
                        : l10n.settingsSingleLocation,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SectionHeader(l10n.settingsCommandProtocol),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.settingsCommandProtocolHint,
                style: TextStyle(
                  color: onSurface.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ),
            ListenableBuilder(
              listenable: SettingsStore.shared,
              builder: (context, _) => Card(
                child: RadioGroup<CommandTransportMode>(
                  groupValue: SettingsStore.shared.commandTransport,
                  onChanged: (v) {
                    if (v != null) SettingsStore.shared.setCommandTransport(v);
                  },
                  child: Column(
                    children: [
                      RadioListTile<CommandTransportMode>(
                        value: CommandTransportMode.tcp,
                        title: Text(l10n.settingsCommandProtocolTcp),
                        subtitle: Text(l10n.settingsCommandProtocolTcpHint),
                        secondary: const Icon(Icons.dns_outlined),
                      ),
                      const Divider(height: 1),
                      RadioListTile<CommandTransportMode>(
                        value: CommandTransportMode.http,
                        title: Text(l10n.settingsCommandProtocolHttp),
                        subtitle: Text(l10n.settingsCommandProtocolHttpHint),
                        secondary: const Icon(Icons.http_outlined),
                      ),
                      const Divider(height: 1),
                      RadioListTile<CommandTransportMode>(
                        value: CommandTransportMode.https,
                        title: Text(l10n.settingsCommandProtocolHttps),
                        subtitle: Text(l10n.settingsCommandProtocolHttpsHint),
                        secondary: const Icon(Icons.https_outlined),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // skip login in current publish
            // const SizedBox(height: 24),
            // SizedBox(
            //   width: double.infinity,
            //   height: 48,
            //   child: OutlinedButton.icon(
            //     style: OutlinedButton.styleFrom(
            //       foregroundColor: AppColors.offlineAlert,
            //       side: const BorderSide(
            //           color: AppColors.offlineAlert, width: 1.4),
            //     ),
            //     onPressed: () => _signOut(context),
            //     icon: const Icon(Icons.logout),
            //     label: Text(l10n.settingsSignOut),
            //   ),
            // ),
            const SizedBox(height: 12),
            Center(
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final String version =
                      snapshot.data?.version ?? (snapshot.hasError ? '?' : '');
                  return Text(l10n.appVersion(version),
                      style: TextStyle(
                          fontSize: 12,
                          color: onSurface.withValues(alpha: 0.4)));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// lib/screens/settings_screen.dart
//
// Brief section III "Settings Section": account, notifications, language
// and appearance, plus a reminder that the architecture is multi-location
// ready even though v1 manages a single location (brief section 4.2).
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Sign out',
      message: 'You will need to sign in again to access your modules and scenarios.',
      confirmLabel: 'Sign out',
    );
    if (confirmed && context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.outerPadding),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: CircleAvatar(
                radius: 26,
                backgroundColor: onSurface,
                child: Text('AP', style: TextStyle(color: Theme.of(context).colorScheme.surface, fontWeight: FontWeight.w800)),
              ),
              title: const Text('Alex Popescu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              subtitle: const Text('alex.popescu@example.com'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pushNamed('/settings/account'),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Preferences'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed('/settings/notifications'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: const Text('Language'),
                  subtitle: const Text('English'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed('/settings/language'),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.contrast_outlined),
                      const SizedBox(width: 16),
                      const Expanded(child: Text('Appearance')),
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: themeModeNotifier,
                        builder: (context, mode, _) => SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
                            ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
                            ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_suggest_outlined), label: Text('Auto')),
                          ],
                          selected: {mode},
                          showSelectedIcon: false,
                          onSelectionChanged: (s) => themeModeNotifier.value = s.first,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Location'),
          const Card(
            child: ListTile(
              leading: Icon(Icons.other_houses_outlined),
              title: Text('Home'),
              subtitle: Text('Single location in this version - multi-location support is planned'),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.offlineAlert,
                side: const BorderSide(color: AppColors.offlineAlert, width: 1.4),
              ),
              onPressed: () => _signOut(context),
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('App version 1.0.0', style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.4))),
          ),
        ],
      ),
    );
  }
}

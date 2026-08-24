// lib/screens/appearance_settings_screen.dart
//
// Brief section "Settings": the Appearance setting opens its own screen (like
// Language) so the compact Light / Dark / System theme picker fits without
// overflowing the row on narrow screens.
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../services/settings_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  void _select(ThemeMode mode) {
    SettingsStore.shared.setThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAppearance)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.outerPadding),
        children: [
          SectionHeader(l10n.settingsTheme),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (context, mode, _) => Card(
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    groupValue: mode,
                    title: Text(l10n.settingsLight),
                    secondary: const Icon(Icons.light_mode_outlined),
                    onChanged: (v) => _select(v!),
                  ),
                  const Divider(height: 1),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    groupValue: mode,
                    title: Text(l10n.settingsDark),
                    secondary: const Icon(Icons.dark_mode_outlined),
                    onChanged: (v) => _select(v!),
                  ),
                  const Divider(height: 1),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    groupValue: mode,
                    title: Text(l10n.settingsAuto),
                    secondary: const Icon(Icons.settings_suggest_outlined),
                    onChanged: (v) => _select(v!),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Localized label shown next to an appearance (theme) mode.
String appearanceLabel(ThemeMode mode, AppLocalizations l10n) {
  switch (mode) {
    case ThemeMode.light:
      return l10n.settingsLight;
    case ThemeMode.dark:
      return l10n.settingsDark;
    case ThemeMode.system:
      return l10n.settingsAuto;
  }
}

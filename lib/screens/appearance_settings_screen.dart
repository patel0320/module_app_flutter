// lib/screens/appearance_settings_screen.dart
//
// Brief section "Settings": the Appearance setting opens its own screen (like
// Language) so the compact Light / Dark / System theme picker fits without
// overflowing the row on narrow screens.
import 'package:flutter/material.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

import '../services/settings_store.dart';
import '../theme/app_theme.dart';
import '../theme/theme_palettes.dart';
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
              child: RadioGroup<ThemeMode>(
                groupValue: mode,
                onChanged: (v) => _select(v!),
                child: Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.light,
                      title: Text(l10n.settingsLight),
                      secondary: const Icon(Icons.light_mode_outlined),
                    ),
                    const Divider(height: 1),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.dark,
                      title: Text(l10n.settingsDark),
                      secondary: const Icon(Icons.dark_mode_outlined),
                    ),
                    const Divider(height: 1),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.system,
                      title: Text(l10n.settingsAuto),
                      secondary: const Icon(Icons.settings_suggest_outlined),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SectionHeader(l10n.homeSectionTheme),
          const SizedBox(height: 4),
          Text(
            l10n.homeChoosePalette,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<HomeThemeId>(
            valueListenable: homeThemeIdNotifier,
            builder: (context, selected, _) => Card(
              child: Column(
                children: [
                  for (final palette in HomeThemePalettes.all)
                    _ThemeTile(
                      palette: palette,
                      selected: palette.id == selected,
                      isLast: palette == HomeThemePalettes.all.last,
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

/// One selectable row in the palette picker, with a live gradient swatch.
/// Tapping a palette applies and persists the user's choice immediately.
class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.palette,
    required this.selected,
    required this.isLast,
  });

  final HomePalette palette;
  final bool selected;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final List<Color> swatch = palette.backgroundGradient.colors;
    return Column(
      children: [
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tileColor: selected ? cs.primary.withValues(alpha: 0.12) : null,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [swatch.first, swatch.last],
              ),
              border: Border.all(color: palette.panelBorder),
            ),
            child: Icon(palette.icon, color: palette.primary, size: 22),
          ),
          title: Text(
            palette.name,
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          trailing: selected
              ? Icon(Icons.check_circle, color: cs.primary)
              : Icon(Icons.circle_outlined,
                  color: cs.onSurface.withValues(alpha: 0.6)),
          onTap: () => SettingsStore.shared.setHomeTheme(palette.id),
        ),
        if (!isLast) const Divider(height: 1),
      ],
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
